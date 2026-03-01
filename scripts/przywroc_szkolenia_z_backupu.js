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
    console.error('Brak katalogu z backupami:', backupDir);
    process.exit(1);
  }

  const files = fs.readdirSync(backupDir).filter((f) => f.endsWith('.json'));
  if (files.length === 0) {
    console.error('Brak plików backupu w katalogu:', backupDir);
    process.exit(1);
  }

  const arg = process.argv[2];
  if (!arg) {
    console.log('Dostępne backupy szkoleń:');
    files.forEach((name, idx) => {
      console.log(`${idx + 1}. ${name}`);
    });
    console.log('\nUżycie:');
    console.log('  node scripts/przywroc_szkolenia_z_backupu.js NAZWA_PLIKU.json');
    console.log('albo');
    console.log('  node scripts/przywroc_szkolenia_z_backupu.js INDEX');
    process.exit(0);
  }

  let fileName = arg;
  const index = Number(arg);
  if (!Number.isNaN(index) && index >= 1 && index <= files.length) {
    fileName = files[index - 1];
  }

  const filePath = path.join(backupDir, fileName);
  if (!fs.existsSync(filePath)) {
    console.error('Nie znaleziono pliku backupu:', filePath);
    process.exit(1);
  }

  console.log('Wczytuję backup z pliku:', filePath);
  const content = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  const items = content.items || [];
  console.log(`Backup zawiera ${items.length} dokumentów.`);

  console.log('Przywracanie danych do kolekcji "szkolenia" (nadpisanie dokumentów o tych samych ID)...');

  let batch = firestore.batch();
  let countInBatch = 0;
  let written = 0;

  for (const item of items) {
    const ref = firestore.collection('szkolenia').doc(item.id);
    batch.set(ref, item.data, { merge: false });
    countInBatch += 1;
    written += 1;

    if (countInBatch >= 400) {
      await batch.commit();
      console.log(`Zapisano batch, łącznie przywrócono ${written} dokumentów...`);
      batch = firestore.batch();
      countInBatch = 0;
    }
  }

  if (countInBatch > 0) {
    await batch.commit();
  }

  console.log(`✅ Zakończono. Przywrócono ${written} dokumentów z backupu.`);
}

run().catch((err) => {
  console.error('❌ Błąd przywracania szkoleń z backupu:', err);
  process.exit(1);
});
