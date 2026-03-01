const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

// KONFIGURACJA: stare i nowe ID strażaka
// UZUPEŁNIJ TE DWIE WARTOŚCI PRZED URUCHOMIENIEM!
const OLD_STRAZAK_ID = 'STARE_ID_STRAZAKA';
const NEW_STRAZAK_ID = 'NOWE_ID_STRAZAKA';

// OPCJONALNIE: dodatkowy filtr po nazwie szkolenia,
// np. tylko dokumenty, gdzie nazwa zawiera "badania"
// Pozostaw jako pusty string, jeśli chcesz przenosić WSZYSTKIE szkolenia typu "medyczne".
const FILTER_NAZWA_ZAWIERA = '';

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
  console.log('Przenoszenie BADAŃ (szkoleń medycznych) strażaka...');
  console.log('Stare ID:', OLD_STRAZAK_ID);
  console.log('Nowe ID:', NEW_STRAZAK_ID);

  if (!OLD_STRAZAK_ID || !NEW_STRAZAK_ID || OLD_STRAZAK_ID === NEW_STRAZAK_ID) {
    console.error('Błędna konfiguracja ID strażaków.');
    process.exit(1);
  }

  // W kolekcji "szkolenia" pole "typ" zapisywane jest jako typ.name,
  // dla szkoleń medycznych będzie to wartość: "medyczne".
  let query = firestore
    .collection('szkolenia')
    .where('strazakId', '==', OLD_STRAZAK_ID)
    .where('typ', '==', 'medyczne');

  const snapshot = await query.get();

  if (snapshot.empty) {
    console.log('Brak badań (szkoleń medycznych) dla podanego starego ID.');
    return;
  }

  console.log(`Znaleziono ${snapshot.size} dokumentów typu "medyczne" przed filtrem nazwy.`);

  const docsToUpdate = [];

  for (const doc of snapshot.docs) {
    const data = doc.data();
    if (FILTER_NAZWA_ZAWIERA && typeof data.nazwa === 'string') {
      if (!data.nazwa.toLowerCase().includes(FILTER_NAZWA_ZAWIERA.toLowerCase())) {
        continue;
      }
    }
    docsToUpdate.push(doc);
  }

  if (docsToUpdate.length === 0) {
    console.log('Po zastosowaniu filtra nazwy nie znaleziono dokumentów do przeniesienia.');
    return;
  }

  console.log(`Do przeniesienia wybrano ${docsToUpdate.length} dokumentów.`);

  let batch = firestore.batch();
  let countInBatch = 0;
  let updated = 0;

  for (const doc of docsToUpdate) {
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

  console.log(`✅ Zakończono. Przeniesiono ${updated} badań (szkoleń medycznych).`);
}

run().catch((err) => {
  console.error('❌ Błąd przenoszenia badań:', err);
  process.exit(1);
});
