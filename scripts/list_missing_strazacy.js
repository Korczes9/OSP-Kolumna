const fs = require('fs');
const path = require('path');
const xlsx = require('xlsx');
const admin = require('firebase-admin');

const downloadsDir = 'C:/Users/User/Downloads';
const fileNamePrefix = 'Lista_stra';
const fileNameMarker = '2026_02_06_17_41';

const serviceAccountPath = path.resolve(__dirname, '..', 'serviceAccountKey.json');
if (!fs.existsSync(serviceAccountPath)) {
  console.error('Brak serviceAccountKey.json w katalogu projektu.');
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(require(serviceAccountPath)),
  });
}

const firestore = admin.firestore();

const normalize = (value) => (value || '')
  .toString()
  .trim()
  .toLowerCase()
  .normalize('NFD')
  .replace(/[\u0300-\u036f]/g, '');

const buildNameVariants = (fullName) => {
  const parts = fullName.trim().split(/\s+/).filter(Boolean);
  if (parts.length < 2) return [];
  const nazwisko = parts[0];
  const imie = parts.slice(1).join(' ');
  return [
    `${nazwisko} ${imie}`,
    `${imie} ${nazwisko}`,
  ];
};

const findFile = () => {
  const files = fs.readdirSync(downloadsDir);
  return files.find((name) => name.startsWith(fileNamePrefix) && name.includes(fileNameMarker));
};

const run = async () => {
  const fileName = findFile();
  if (!fileName) {
    console.error('Nie znaleziono pliku w Downloads.');
    process.exit(1);
  }

  const filePath = path.join(downloadsDir, fileName);
  const workbook = xlsx.readFile(filePath);
  const sheetName = workbook.SheetNames.find((name) => normalize(name).includes('szkole'));
  if (!sheetName) {
    console.error('Brak arkusza ze szkoleniami.');
    process.exit(1);
  }

  const sheet = workbook.Sheets[sheetName];
  const rows = xlsx.utils.sheet_to_json(sheet, { header: 1, defval: '' });
  if (rows.length < 2) {
    console.error('Arkusz ze szkoleniami jest pusty.');
    process.exit(1);
  }

  const headers = rows[0];
  const idxName = headers.findIndex((h) => normalize(h).includes('imie i nazwisko'));
  if (idxName < 0) {
    console.error('Nie znaleziono kolumny "Imię i nazwisko".');
    process.exit(1);
  }

  const strazacySnapshot = await firestore.collection('strazacy').get();
  const strazakMap = new Map();
  strazacySnapshot.docs.forEach((doc) => {
    const data = doc.data();
    const key = normalize(`${data.nazwisko || ''} ${data.imie || ''}`);
    strazakMap.set(key, doc.id);
  });

  const notFound = new Set();

  for (let i = 1; i < rows.length; i += 1) {
    const fullName = (rows[i][idxName] || '').toString().trim();
    if (!fullName) continue;

    const variants = buildNameVariants(fullName);
    const match = variants
      .map((v) => strazakMap.get(normalize(v)))
      .find(Boolean);

    if (!match) {
      notFound.add(fullName);
    }
  }

  const list = Array.from(notFound).sort();
  console.log(`Braki: ${list.length}`);
  console.log(list.join('\n'));
};

run().catch((err) => {
  console.error('Błąd:', err);
  process.exit(1);
});
