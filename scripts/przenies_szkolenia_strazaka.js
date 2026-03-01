const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

// KONFIGURACJA: stare i nowe ID strażaka
const OLD_STRAZAK_ID = 'wc9sHeoNbPfzkP9p0KKYKWVhQD72';
const NEW_STRAZAK_ID = 'hGg68vePE3bv82IPYRCqxxrreCj2';

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
  console.log('Przenoszenie szkoleń strażaka...');
  console.log('Stare ID:', OLD_STRAZAK_ID);
  console.log('Nowe ID:', NEW_STRAZAK_ID);

  if (!OLD_STRAZAK_ID || !NEW_STRAZAK_ID || OLD_STRAZAK_ID === NEW_STRAZAK_ID) {
    console.error('Błędna konfiguracja ID strażaków.');
    process.exit(1);
  }

  const snapshot = await firestore
    .collection('szkolenia')
    .where('strazakId', '==', OLD_STRAZAK_ID)
    .get();

  if (snapshot.empty) {
    console.log('Brak szkoleń dla podanego starego ID.');
    return;
  }

  console.log(`Znaleziono ${snapshot.size} szkoleń do przeniesienia.`);

  let batch = firestore.batch();
  let countInBatch = 0;
  let updated = 0;

  for (const doc of snapshot.docs) {
    batch.update(doc.ref, { strazakId: NEW_STRAZAK_ID });
    countInBatch += 1;
    updated += 1;

    if (countInBatch >= 400) {
      await batch.commit();
      console.log(`Zapisano batch, łącznie zaktualizowano ${updated} dokumentów...`);
      batch = firestore.batch();
      countInBatch = 0;
    }
  }

  if (countInBatch > 0) {
    await batch.commit();
  }

  console.log(`✅ Zakończono. Przeniesiono ${updated} szkoleń.`);
}

run().catch((err) => {
  console.error('❌ Błąd przenoszenia szkoleń:', err);
  process.exit(1);
});
