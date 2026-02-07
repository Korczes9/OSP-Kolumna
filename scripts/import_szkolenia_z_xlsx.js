const fs = require('fs');
const path = require('path');
const xlsx = require('xlsx');
const admin = require('firebase-admin');

const serviceAccountPath = path.resolve(__dirname, '..', 'serviceAccountKey.json');
const downloadsDir = 'C:/Users/User/Downloads';
const fileNamePrefix = 'Lista_strażaków_szkolenia';
const fileNameMarker = '2026_02_06_17_41';
const sheetNameMarker = 'szkolenia';
const regexDowodca = /dow[oó]dc/i;

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
  .replace(/[ąćęłńóśżź]/g, (m) => ({
    'ą': 'a',
    'ć': 'c',
    'ę': 'e',
    'ł': 'l',
    'ń': 'n',
    'ó': 'o',
    'ś': 's',
    'ż': 'z',
    'ź': 'z',
  }[m]));

const findFile = () => {
  const files = fs.readdirSync(downloadsDir);
  return files.find((name) => name.startsWith(fileNamePrefix) && name.includes(fileNameMarker));
};

const excelDateToJs = (value) => {
  if (value === null || value === undefined || value === '') return null;
  if (value instanceof Date) return value;
  if (typeof value === 'number') {
    const parsed = xlsx.SSF.parse_date_code(value);
    if (!parsed) return null;
    return new Date(parsed.y, parsed.m - 1, parsed.d, parsed.H, parsed.M, parsed.S || 0);
  }
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
};

const findColumnIndex = (headers, needle) => {
  const target = normalize(needle);
  return headers.findIndex((h) => normalize(h).includes(target));
};

const detectTyp = (nazwa) => {
  const text = normalize(nazwa);
  if (text.includes('kierowca')) return 'kierowca';
  if (text.includes('ratownictwo')) return 'ratownictwo';
  if (text.includes('KPP') || text.includes('KPP') || text.includes('kpp')) return 'medyczne';
  if (text.includes('techniczne')) return 'techniczne';
  if (text.includes('podstawowe')) return 'podstawowe';
  if (text.includes('specjalistyczne')) return 'specjalistyczne';
  return 'inne';
};

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

const run = async () => {
  const fileName = findFile();
  if (!fileName) {
    console.error('Nie znaleziono pliku w Downloads.');
    process.exit(1);
  }

  const filePath = path.join(downloadsDir, fileName);
  const workbook = xlsx.readFile(filePath);
  const sheetName = workbook.SheetNames.find((name) => normalize(name).includes(sheetNameMarker));
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
  const idxName = findColumnIndex(headers, 'Imię i nazwisko');
  const idxTraining = findColumnIndex(headers, 'Nazwa szkolenia');
  const idxRecert = findColumnIndex(headers, 'Nazwa recertyfikacji');
  const idxDateDone = findColumnIndex(headers, 'Data ukończenia');
  const idxDateValid = findColumnIndex(headers, 'Data ważności');
  const idxCert = findColumnIndex(headers, 'Numer certyfikacji');
  const idxIssuer = findColumnIndex(headers, 'Organ wydający');

  if (idxName < 0 || idxTraining < 0 || idxDateDone < 0) {
    console.error('Brakuje wymaganych kolumn (Imię i nazwisko / Nazwa szkolenia / Data ukończenia).');
    process.exit(1);
  }

  const strazacySnapshot = await firestore.collection('strazacy').get();
  const strazakMap = new Map();
  strazacySnapshot.docs.forEach((doc) => {
    const data = doc.data();
    const imie = data.imie || '';
    const nazwisko = data.nazwisko || '';
    const key = normalize(`${nazwisko} ${imie}`);
    strazakMap.set(key, { id: doc.id, data });
  });

  const existingSnapshot = await firestore.collection('szkolenia').get();
  const existingKeys = new Set();
  existingSnapshot.docs.forEach((doc) => {
    const data = doc.data();
    const dataOdbycia = data.dataOdbycia?.toDate ? data.dataOdbycia.toDate() : null;
    const dateKey = dataOdbycia ? dataOdbycia.toISOString().slice(0, 10) : '';
    existingKeys.add(`${data.strazakId}|${data.nazwa}|${dateKey}`);
  });

  let batch = firestore.batch();
  let batchCount = 0;
  let added = 0;
  let skipped = 0;
  let notFound = 0;
  let missingDate = 0;
  const dowodcaIds = new Set();

  for (let i = 1; i < rows.length; i += 1) {
    const row = rows[i];
    const fullName = (row[idxName] || '').toString().trim();
    const trainingName = (row[idxTraining] || '').toString().trim();

    if (!fullName || !trainingName) {
      skipped += 1;
      continue;
    }

    const variants = buildNameVariants(fullName);
    const match = variants
      .map((v) => strazakMap.get(normalize(v)))
      .find(Boolean);

    if (!match) {
      notFound += 1;
      continue;
    }

    const dataOdbycia = excelDateToJs(row[idxDateDone]);
    if (!dataOdbycia) {
      missingDate += 1;
      continue;
    }

    const dataWaznosci = excelDateToJs(row[idxDateValid]);
    const numerCertyfikatu = (row[idxCert] || '').toString().trim();
    const instytucja = (row[idxIssuer] || '').toString().trim();
    const recertyfikacja = (row[idxRecert] || '').toString().trim();

    const dateKey = dataOdbycia.toISOString().slice(0, 10);
    const key = `${match.id}|${trainingName}|${dateKey}`;
    if (existingKeys.has(key)) {
      skipped += 1;
      continue;
    }

    const docRef = firestore.collection('szkolenia').doc();
    batch.set(docRef, {
      strazakId: match.id,
      nazwa: trainingName,
      typ: detectTyp(trainingName),
      dataOdbycia: admin.firestore.Timestamp.fromDate(dataOdbycia),
      dataWaznosci: dataWaznosci ? admin.firestore.Timestamp.fromDate(dataWaznosci) : null,
      numerCertyfikatu: numerCertyfikatu || null,
      instytucja: instytucja || null,
      uwagi: recertyfikacja ? `Recertyfikacja: ${recertyfikacja}` : null,
    });

    existingKeys.add(key);
    added += 1;
    batchCount += 1;

    if (regexDowodca.test(trainingName)) {
      dowodcaIds.add(match.id);
    }

    if (batchCount >= 400) {
      await batch.commit();
      batch = firestore.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  for (const strazakId of dowodcaIds) {
    const doc = await firestore.collection('strazacy').doc(strazakId).get();
    const data = doc.data() || {};
    const role = (data.role || []).map((r) => r.toString());
    if (!role.includes('dowodca')) {
      role.push('dowodca');
      await firestore.collection('strazacy').doc(strazakId).update({ role });
    }
  }

  console.log('Import zakończony');
  console.log(`Dodano: ${added}`);
  console.log(`Pominięto (duplikaty/braki): ${skipped}`);
  console.log(`Nie znaleziono strażaka: ${notFound}`);
  console.log(`Brak daty ukończenia: ${missingDate}`);
  console.log(`Nadano rolę dowódca: ${dowodcaIds.size}`);
};

run().catch((err) => {
  console.error('Błąd importu:', err);
  process.exit(1);
});
