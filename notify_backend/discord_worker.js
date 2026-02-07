require('dotenv').config();
const admin = require('firebase-admin');
const express = require('express');

const discordBotToken = process.env.DISCORD_BOT_TOKEN || '';
const discordChannelId = process.env.DISCORD_CHANNEL_ID || '';
const pollIntervalSeconds = Number(process.env.DISCORD_POLL_INTERVAL_SECONDS || '1');
const messageLimit = Number(process.env.DISCORD_MESSAGE_LIMIT || '10');
const alarmKeyword = String(process.env.DISCORD_ALARM_KEYWORD || 'KOLUMNA');
const alarmCooldownMinutes = Number(process.env.DISCORD_ALARM_COOLDOWN_MINUTES || '4');
const stateDocPath = process.env.DISCORD_STATE_DOC || 'config/discord_monitor';
const port = Number(process.env.PORT || '10000');

const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT || '';
const serviceAccountB64 = process.env.FIREBASE_SERVICE_ACCOUNT_B64 || '';

if (!discordBotToken) {
  throw new Error('Missing DISCORD_BOT_TOKEN');
}
if (!discordChannelId) {
  throw new Error('Missing DISCORD_CHANNEL_ID');
}
if (!serviceAccountJson && !serviceAccountB64) {
  throw new Error('Missing FIREBASE_SERVICE_ACCOUNT or FIREBASE_SERVICE_ACCOUNT_B64');
}

let credentials = null;
if (serviceAccountJson) {
  credentials = JSON.parse(serviceAccountJson);
} else if (serviceAccountB64) {
  const decoded = Buffer.from(serviceAccountB64, 'base64').toString('utf8');
  credentials = JSON.parse(decoded);
}

admin.initializeApp({
  credential: admin.credential.cert(credentials),
});

const db = admin.firestore();
const stateRef = db.doc(stateDocPath);

let lastMessageId = null;
let lastAlarmAt = null;
let inFlight = false;
let nextAllowedAt = 0;

async function loadState() {
  const snap = await stateRef.get();
  if (!snap.exists) {
    return;
  }
  const data = snap.data() || {};
  if (data.lastMessageId) {
    lastMessageId = String(data.lastMessageId);
  }
  if (data.lastAlarmAt && typeof data.lastAlarmAt.toDate === 'function') {
    lastAlarmAt = data.lastAlarmAt.toDate();
  }
}

async function saveState() {
  const payload = {
    lastMessageId: lastMessageId || null,
    lastAlarmAt: lastAlarmAt ? admin.firestore.Timestamp.fromDate(lastAlarmAt) : null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  await stateRef.set(payload, { merge: true });
}

async function fetchMessages() {
  const url = `https://discord.com/api/v10/channels/${discordChannelId}/messages?limit=${messageLimit}`;
  const response = await fetch(url, {
    headers: {
      Authorization: `Bot ${discordBotToken}`,
      'Content-Type': 'application/json',
    },
  });

  if (response.status === 429) {
    const retryAfter = Number(response.headers.get('retry-after') || '5');
    nextAllowedAt = Date.now() + retryAfter * 1000;
    console.warn('Discord rate limit, retry after seconds:', retryAfter);
    return [];
  }

  if (!response.ok) {
    console.warn('Discord API error status:', response.status);
    return [];
  }

  const data = await response.json();
  if (!Array.isArray(data)) {
    return [];
  }

  return data;
}

function resolveTitleAndBody(message) {
  const content = (message.content || '').toString();
  let title = 'Nowa wiadomosc Discord';
  let body = content || '(wiadomosc z zalacznikiem)';

  const embeds = Array.isArray(message.embeds) ? message.embeds : [];
  if (embeds.length > 0) {
    const firstEmbed = embeds[0] || {};
    const embedTitle = firstEmbed.title ? String(firstEmbed.title) : '';
    const embedDesc = firstEmbed.description ? String(firstEmbed.description) : '';
    if (embedTitle) {
      title = embedTitle;
      body = embedDesc || content;
    }
  }

  return { title, body, content };
}

function shouldTriggerAlarm(title, body, content) {
  const fullText = `${title} ${body} ${content}`.toUpperCase();
  const alarmDetected = fullText.includes(alarmKeyword.toUpperCase());
  if (!alarmDetected) {
    return false;
  }
  if (!lastAlarmAt) {
    return true;
  }
  const diffMs = Date.now() - lastAlarmAt.getTime();
  return diffMs >= alarmCooldownMinutes * 60 * 1000;
}

async function sendNotification(message) {
  const author = message.author || {};
  const authorName = author.username || 'Discord';
  const { title, body, content } = resolveTitleAndBody(message);

  const isAlarm = shouldTriggerAlarm(title, body, content);
  if (isAlarm) {
    lastAlarmAt = new Date();
    await saveState();
    console.log('ALARM detected by keyword');
  }

  const usersSnapshot = await db.collection('strazacy').get();
  const tokens = usersSnapshot.docs
    .map((doc) => doc.data().fcmToken)
    .filter((token) => token && String(token).length > 0);

  if (tokens.length === 0) {
    console.warn('No FCM tokens');
    return;
  }

  await db.collection('powiadomienia').add({
    tokens,
    title: isAlarm ? 'ALARM - Kolumna' : `Discord: ${title}`,
    body: body || content,
    data: {
      type: isAlarm ? 'ALARM' : 'discord',
      messageId: String(message.id || ''),
      author: String(authorName),
      channelId: String(discordChannelId),
      kategoria: isAlarm ? 'Discord - Kolumna' : 'Discord',
      fullContent: String(content || ''),
      fullTitle: String(title || ''),
      fullBody: String(body || ''),
    },
    utworzonoO: admin.firestore.FieldValue.serverTimestamp(),
    wyslane: false,
  });

  console.log(`Queued notification for ${tokens.length} tokens`);
}

async function checkDiscord() {
  if (inFlight) {
    return;
  }
  if (Date.now() < nextAllowedAt) {
    return;
  }

  inFlight = true;
  try {
    const messages = await fetchMessages();
    if (messages.length === 0) {
      return;
    }

    const newest = messages[0];
    const newestId = String(newest.id || '');
    if (!newestId) {
      return;
    }

    if (!lastMessageId) {
      lastMessageId = newestId;
      await saveState();
      console.log('Initial sync, saved last message id');
      return;
    }

    if (newestId === lastMessageId) {
      return;
    }

    const freshMessages = [];
    for (const message of messages) {
      const id = String(message.id || '');
      if (id === lastMessageId) {
        break;
      }
      freshMessages.push(message);
    }

    if (freshMessages.length === 0) {
      lastMessageId = newestId;
      await saveState();
      return;
    }

    for (const message of freshMessages.reverse()) {
      await sendNotification(message);
    }

    lastMessageId = newestId;
    await saveState();
  } catch (err) {
    console.error('Discord check error', err);
  } finally {
    inFlight = false;
  }
}

async function start() {
  await loadState();
  await checkDiscord();
  const intervalMs = Math.max(1000, pollIntervalSeconds * 1000);
  setInterval(checkDiscord, intervalMs);
  console.log(`Discord worker started, interval ${intervalMs}ms`);
}

// HTTP healthcheck endpoint dla Render Web Service
const app = express();
app.get('/', (req, res) => {
  res.json({ 
    status: 'running', 
    lastMessageId: lastMessageId || null,
    lastAlarmAt: lastAlarmAt ? lastAlarmAt.toISOString() : null,
    uptime: process.uptime()
  });
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.listen(port, () => {
  console.log(`HTTP server listening on port ${port}`);
});

start().catch((err) => {
  console.error('Startup error', err);
  process.exit(1);
});
