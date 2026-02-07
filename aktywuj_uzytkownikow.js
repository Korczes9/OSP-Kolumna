// Skrypt do aktywacji wszystkich użytkowników w Firestore
// UWAGA: Użyj tylko raz do naprawy istniejących kont!

const admin = require('firebase-admin');

// Inicjalizacja (jeśli jeszcze nie zainicjalizowane)
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault()
  });
}

const db = admin.firestore();

async function aktywujWszystkichUzytkownikow() {
  console.log('🔧 Aktywacja wszystkich użytkowników...\n');
  
  try {
    // Pobierz wszystkich strażaków
    const snapshot = await db.collection('strazacy').get();
    
    if (snapshot.empty) {
      console.log('❌ Brak użytkowników w kolekcji "strazacy"');
      return;
    }
    
    let aktywowanych = 0;
    let juzAktywnych = 0;
    
    const batch = db.batch();
    
    snapshot.forEach(doc => {
      const dane = doc.data();
      
      if (dane.aktywny === false || dane.aktywny === undefined) {
        console.log(`✅ Aktywuję: ${dane.email} (${dane.imie} ${dane.nazwisko})`);
        batch.update(doc.ref, { aktywny: true });
        aktywowanych++;
      } else {
        console.log(`⏭️  Już aktywny: ${dane.email}`);
        juzAktywnych++;
      }
    });
    
    // Zatwierdź zmiany
    if (aktywowanych > 0) {
      await batch.commit();
      console.log(`\n✅ Aktywowano ${aktywowanych} kont`);
    }
    
    console.log(`⏭️  Pomięto ${juzAktywnych} aktywnych kont`);
    console.log('\n✅ Gotowe!');
    
  } catch (error) {
    console.error('❌ Błąd:', error);
  }
}

// Uruchom skrypt
aktywujWszystkichUzytkownikow()
  .then(() => process.exit(0))
  .catch(error => {
    console.error('❌ Nieobsłużony błąd:', error);
    process.exit(1);
  });
