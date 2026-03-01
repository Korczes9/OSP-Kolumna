const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const serviceAccountPath = path.resolve(__dirname, '..', 'serviceAccountKey.json');

if (!fs.existsSync(serviceAccountPath)) {
  console.error('Brak pliku serviceAccountKey.json w katalogu projektu.');
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(require(serviceAccountPath)),
  });
}

const firestore = admin.firestore();

async function run() {
  const backupDir = path.resolve(__dirname, '..', 'backups', 'szkolenia');
  if (!fs.existsSync(backupDir)) {
    fs.mkdirSync(backupDir, { recursive: true });
  }

  console.log('Pobieram wszystkie dokumenty z kolekcji "szkolenia"...');
  const snapshot = await firestore.collection('szkolenia').get();

  console.log(`Znaleziono ${snapshot.size} dokumentów.`);

  const items = snapshot.docs.map((doc) => ({
    id: doc.id,
    data: doc.data(),
  }));

  const now = new Date();
  const stamp = now.toISOString().replace(/[:.]/g, '-').slice(0, 19);
  const fileName = `szkolenia-${stamp}.json`;
  const filePath = path.join(backupDir, fileName);

  fs.writeFileSync(filePath, JSON.stringify({
    createdAt: now.toISOString(),
    count: items.length,
    items,
  }, null, 2), 'utf8');

  console.log(`✅ Backup zapisany w pliku: ${filePath}`);
}

run().catch((err) => {
  console.error('❌ Błąd tworzenia backupu szkoleń:', err);
  process.exit(1);
});
