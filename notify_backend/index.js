const express = require('express');
const admin = require('firebase-admin');

const app = express();
app.use(express.json({ limit: '256kb' }));

const adminToken = process.env.ADMIN_TOKEN || '';
const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT || '';
const serviceAccountB64 = process.env.FIREBASE_SERVICE_ACCOUNT_B64 || '';

let credentials = null;
if (serviceAccountJson) {
  credentials = JSON.parse(serviceAccountJson);
} else if (serviceAccountB64) {
  const decoded = Buffer.from(serviceAccountB64, 'base64').toString('utf8');
  credentials = JSON.parse(decoded);
}

if (!credentials) {
  throw new Error('Missing FIREBASE_SERVICE_ACCOUNT or FIREBASE_SERVICE_ACCOUNT_B64');
}

admin.initializeApp({
  credential: admin.credential.cert(credentials),
});

app.get('/health', (req, res) => {
  res.json({ ok: true });
});

app.post('/notify', async (req, res) => {
  const token = req.get('X-Admin-Token') || '';
  if (!adminToken || token !== adminToken) {
    return res.status(401).json({ error: 'unauthorized' });
  }

  const { type, title, body, data, topic } = req.body || {};
  const targetTopic = (topic || 'all').toString();

  if (!type || !title) {
    return res.status(400).json({ error: 'missing type/title' });
  }

  const payloadData = {
    type: String(type),
    title: String(title),
    body: String(body || ''),
    ...(data || {}),
  };

  const message = {
    topic: targetTopic,
    data: payloadData,
    android: {
      priority: 'high',
      notification: type === 'ALARM'
        ? undefined
        : {
            title: String(title),
            body: String(body || ''),
            channelId: 'default_channel',
          },
    },
  };

  try {
    const response = await admin.messaging().send(message);
    return res.json({ ok: true, id: response });
  } catch (err) {
    console.error('send error', err);
    return res.status(500).json({ error: 'send_failed' });
  }
});

const port = process.env.PORT || 3000;
app.listen(port, () => {
  console.log(`notify backend running on :${port}`);
});
