require('dotenv').config();
const admin = require('firebase-admin');
const express = require('express');
const cheerio = require('cheerio');

const discordBotToken = process.env.DISCORD_BOT_TOKEN || '';
const discordChannelId = process.env.DISCORD_CHANNEL_ID || '';
const pollIntervalSeconds = Number(process.env.DISCORD_POLL_INTERVAL_SECONDS || '5');
const messageLimit = Number(process.env.DISCORD_MESSAGE_LIMIT || '10');
const alarmKeyword = String(process.env.DISCORD_ALARM_KEYWORD || 'KOLUMNA');
const alarmCooldownMinutes = Number(process.env.DISCORD_ALARM_COOLDOWN_MINUTES || '4');
const stateDocPath = process.env.DISCORD_STATE_DOC || 'config/discord_monitor';
const port = Number(process.env.PORT || '10000');
const eRemizaPollIntervalSeconds = Number(process.env.EREMIZA_POLL_INTERVAL_SECONDS || '5');

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
let eRemizaInFlight = false;
const knownEremizaIds = new Set();

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

// Znajdz aktywny wyjazd stworzony w ciagu ostatnich X minut (deduplication)
async function findRecentWyjazd(withinMinutes = 10) {
  const since = new Date(Date.now() - withinMinutes * 60 * 1000);
  const ts = admin.firestore.Timestamp.fromDate(since);
  const snap = await db.collection('wyjazdy')
    .where('createdAt', '>=', ts)
    .limit(5)
    .get();
  // Preferuj wyjazd z e-Remizy (ma eremizaId) - bardziej wiarygodny
  const withEremiza = snap.docs.filter(d => d.data().eremizaId);
  if (withEremiza.length > 0) return withEremiza[0];
  return snap.empty ? null : snap.docs[0];
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
    const errorText = await response.text();
    console.warn('Discord API error status:', response.status, 'body:', errorText);
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
  const fullText = `${title} ${body} ${content}`.toLowerCase();
  const alarmDetected = fullText.includes(alarmKeyword.toLowerCase());
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
  let wyjazdId = null;

  if (isAlarm) {
    lastAlarmAt = new Date();
    await saveState();
    console.log('ALARM detected by keyword');

    // Sprawdz czy juz istnieje wyjazd z ostatnich 10 minut (np. z e-Remizy)
    const existingWyjazd = await findRecentWyjazd(10);
    if (existingWyjazd) {
      wyjazdId = existingWyjazd.id;
      console.log('Discord alarm: znaleziono istniejacy wyjazd ' + wyjazdId + ' (zrodlo: ' + existingWyjazd.data().zrodlo + '), pomijam tworzenie');
    } else {
      // Stworz wyjazd w Firestore zeby strazacy mogli reagowac
      const alarmOpis = `${title} ${body} ${content}`.trim().substring(0, 300);
      const wyjazdRef = db.collection('wyjazdy').doc();
      wyjazdId = wyjazdRef.id;
      await wyjazdRef.set({
        tytul: 'Alarm - Kolumna',
        lokalizacja: '',
        opis: alarmOpis,
        kategoria: 'miejscoweZagrozenie',
        status: 'aktywny',
        zrodlo: 'discord',
        godzinaAlarmu: admin.firestore.FieldValue.serverTimestamp(),
        dataWyjazdu: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        utworzonePrzez: 'system_discord',
        strazacyIds: [],
      });
      console.log('Discord alarm: created wyjazd ' + wyjazdId);
    }
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
      wyjazdId: wyjazdId || '',
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

async function checkERemiza() {
  if (eRemizaInFlight) return;
  eRemizaInFlight = true;
  try {
    const cfgDoc = await db.collection('config').doc('eremiza').get();
    if (!cfgDoc.exists || !cfgDoc.data().aktywne) return;
    const { login, haslo } = cfgDoc.data();

    const cookieJar = {};
    const saveCookies = (response) => {
      const raw = response.headers.raw ? (response.headers.raw()['set-cookie'] || []) : [];
      raw.forEach((c) => {
        const part = c.split(';')[0];
        const [k, ...rest] = part.split('=');
        if (k) cookieJar[k.trim()] = rest.join('=').trim();
      });
    };
    const cookieHeader = () => Object.entries(cookieJar).map(([k, v]) => `${k}=${v}`).join('; ');

    const loginPageRes = await fetch('https://e-remiza.pl/OSP.UI.SSO/logowanie', {
      headers: { 'User-Agent': 'Mozilla/5.0' },
    });
    saveCookies(loginPageRes);
    const loginHtml = await loginPageRes.text();
    const $l = cheerio.load(loginHtml);
    const csrfToken = $l('input[name="__RequestVerificationToken"]').val() || '';

    const formBody = new URLSearchParams({
      Email: login,
      Password: haslo,
      __RequestVerificationToken: csrfToken,
    });

    const loginRes = await fetch('https://e-remiza.pl/OSP.UI.SSO/logowanie', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': 'Mozilla/5.0',
        Cookie: cookieHeader(),
      },
      body: formBody.toString(),
      redirect: 'manual',
    });
    saveCookies(loginRes);
    if (loginRes.status !== 302 && loginRes.status !== 200) {
      console.warn('eRemiza login error, status:', loginRes.status);
      return;
    }

    const alarmsRes = await fetch('https://e-remiza.pl/OSP.UI.EREMIZA/alarmy', {
      headers: { 'User-Agent': 'Mozilla/5.0', Cookie: cookieHeader() },
    });
    saveCookies(alarmsRes);
    if (alarmsRes.status !== 200) return;

    const alarmsHtml = await alarmsRes.text();
    const $ = cheerio.load(alarmsHtml);

    const rows = [];
    $('table tr').each((i, row) => {
      if (i === 0) return;
      const cols = $(row).find('td');
      if (cols.length < 3) return;
      rows.push({
        czasStr: $(cols[0]).text().trim(),
        rodzaj: $(cols[1]).text().trim(),
        miejsceZdarzenia: $(cols[2]).text().trim(),
        opis: cols.length > 3 ? $(cols[3]).text().trim() : '',
      });
    });

    for (const alarm of rows) {
      if (!alarm.czasStr) continue;
      const dtMatch = alarm.czasStr.match(/(\d{2})-(\d{2})-(\d{4})\s+(\d{2}):(\d{2})/);
      if (!dtMatch) continue;
      const [, dd, mm, yyyy, hh, min] = dtMatch;
      const dataAlarmu = new Date(`${yyyy}-${mm}-${dd}T${hh}:${min}:00`);

      const wiek = Date.now() - dataAlarmu.getTime();
      if (wiek > 2 * 60 * 60 * 1000) continue;

      const eremizaId = `eremiza_${yyyy}${mm}${dd}_${hh}${min}_${alarm.miejsceZdarzenia.replace(/\s+/g, '_').substring(0, 30)}`;
      if (knownEremizaIds.has(eremizaId)) continue;

      const existing = await db.collection('wyjazdy').where('eremizaId', '==', eremizaId).limit(1).get();
      if (!existing.empty) {
        knownEremizaIds.add(eremizaId);
        continue;
      }

      knownEremizaIds.add(eremizaId);
      console.log('eRemiza: nowy alarm:', eremizaId);

      const recentWyjazd = await findRecentWyjazd(10);
      if (recentWyjazd && !recentWyjazd.data().eremizaId) {
        // Discord byl szybszy - uzupelnij jego wyjazd o dane e-Remizy
        await recentWyjazd.ref.update({
          eremizaId,
          tytul: alarm.rodzaj || recentWyjazd.data().tytul,
          lokalizacja: alarm.miejsceZdarzenia || recentWyjazd.data().lokalizacja,
          opis: alarm.opis || recentWyjazd.data().opis,
          zrodlo: 'discord+eRemiza',
          eremizaAlarmWyslany: true,
        });
        console.log('eRemiza: uzupelniono wyjazd Discord ' + recentWyjazd.id + ' o eremizaId ' + eremizaId);
      } else if (!recentWyjazd) {
        // E-Remiza jest pierwsza - stworz wyjazd i wyslij FCM bezposrednio
        const kategoria = alarm.rodzaj.toLowerCase().includes('po') ? 'pozar'
          : alarm.rodzaj.toLowerCase().includes('miejscowe') ? 'miejscoweZagrozenie' : 'inne';
        const docRef = await db.collection('wyjazdy').add({
          eremizaId,
          tytul: alarm.rodzaj || 'Alarm',
          lokalizacja: alarm.miejsceZdarzenia || '',
          opis: alarm.opis || '',
          kategoria,
          dataWyjazdu: admin.firestore.Timestamp.fromDate(dataAlarmu),
          godzinaAlarmu: admin.firestore.FieldValue.serverTimestamp(),
          status: 'aktywny',
          zrodlo: 'e-remiza',
          rodzaj: alarm.rodzaj,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          utworzonePrzez: 'system_eremiza_worker',
          strazacyIds: [],
          eremizaAlarmWyslany: true,
        });
        console.log('eRemiza: stworzono wyjazd ' + docRef.id + ' dla ' + eremizaId);

        // Kolejkuj FCM bezposrednio (tak jak Discord) - bez czekania na Cloud Function
        const usersSnapshot = await db.collection('strazacy').get();
        const tokens = usersSnapshot.docs
          .map((d) => d.data().fcmToken)
          .filter((t) => t && String(t).length > 0);
        if (tokens.length > 0) {
          await db.collection('powiadomienia').add({
            tokens,
            title: '🚨 ALARM!',
            body: `${alarm.rodzaj || 'Alarm'} - ${alarm.miejsceZdarzenia || ''}`.trim(),
            data: {
              type: 'ALARM',
              wyjazdId: docRef.id,
              kategoria: 'eRemiza',
              lokalizacja: alarm.miejsceZdarzenia || '',
            },
            utworzonoO: admin.firestore.FieldValue.serverTimestamp(),
            wyslane: false,
          });
          console.log('eRemiza: FCM zakolejkowany dla ' + tokens.length + ' tokenow, wyjazdId: ' + docRef.id);
        }
      }
    }
  } catch (err) {
    console.error('eRemiza check error', err.message);
  } finally {
    eRemizaInFlight = false;
  }
}

async function start() {
  await loadState();
  await checkDiscord();
  const discordIntervalMs = Math.max(1000, pollIntervalSeconds * 1000);
  setInterval(checkDiscord, discordIntervalMs);
  console.log(`Discord worker started, interval ${discordIntervalMs}ms`);

  const eRemizaIntervalMs = Math.max(5000, eRemizaPollIntervalSeconds * 1000);
  setInterval(checkERemiza, eRemizaIntervalMs);
  console.log(`eRemiza worker started, interval ${eRemizaIntervalMs}ms`);
  // Pierwsze sprawdzenie e-Remizy po 3s (zeby Discord sie zaladowal pierwszy)
  setTimeout(checkERemiza, 3000);
}

// HTTP healthcheck endpoint dla Render Web Service
const app = express();
app.get('/', (req, res) => {
  res.json({ 
    status: 'running', 
    lastMessageId: lastMessageId || null,
    lastAlarmAt: lastAlarmAt ? lastAlarmAt.toISOString() : null,
    eRemizaKnownIds: knownEremizaIds.size,
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

// Self-ping co 10 minut zeby Render free tier nie zasypial
const renderUrl = process.env.RENDER_EXTERNAL_URL || '';
if (renderUrl) {
  setInterval(async () => {
    try {
      await fetch(`${renderUrl}/health`);
      console.log('Self-ping OK');
    } catch (e) {
      console.warn('Self-ping failed:', e.message);
    }
  }, 10 * 60 * 1000);
}
