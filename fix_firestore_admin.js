const admin = require('firebase-admin');
const fs = require('fs');

// Inicjalizacja Firebase Admin SDK
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function fixAdminAccount() {
  const email = 'korczes9@gmail.com';
  const uid = 'XGQrC30tekcPPJuCNJX5SRILNc32';
  
  console.log('🔍 Szukam starych dokumentów dla:', email);
  
  try {
    // Znajdź i usuń stare dokumenty
    const querySnapshot = await db.collection('strazacy')
      .where('email', '==', email)
      .get();
    
    if (!querySnapshot.empty) {
      console.log(`📝 Znaleziono ${querySnapshot.size} dokument(ów) do usunięcia`);
      
      for (const doc of querySnapshot.docs) {
        if (doc.id !== uid) {
          console.log(`🗑️  Usuwam stary dokument: ${doc.id}`);
          await doc.ref.delete();
        } else {
          console.log(`✅ Dokument z prawidłowym UID już istnieje`);
        }
      }
    }
    
    // Utwórz/zaktualizuj dokument z prawidłowym UID
    console.log(`\n📄 Tworzę dokument z UID: ${uid}`);
    
    const now = new Date().toISOString();
    
    await db.collection('strazacy').doc(uid).set({
      email: email,
      role: ['administrator'],
      aktywny: true,
      imie: 'Sebastian',
      nazwisko: 'Grochulski',
      numerTelefonu: '691837009',
      dostepny: false,
      dataRejestracji: now,
      ostatnioAktywny: now
    }, { merge: true });
    
    console.log('✅ Pomyślnie utworzono/zaktualizowano dokument Firestore!');
    
    // Weryfikacja
    const doc = await db.collection('strazacy').doc(uid).get();
    if (doc.exists) {
      console.log('\n📋 Dane użytkownika:');
      console.log(JSON.stringify(doc.data(), null, 2));
    }
    
    console.log('\n✅ GOTOWE! Możesz się teraz zalogować:');
    console.log('   Email: korczes9@gmail.com');
    console.log('   UID: XGQrC30tekcPPJuCNJX5SRILNc32');
    console.log('\n⚠️  PAMIĘTAJ: Wdróż reguły Firestore w Firebase Console!');
    console.log('   https://console.firebase.google.com/project/osp-kolumna/firestore/rules');
    
  } catch (error) {
    console.error('❌ Błąd:', error.message);
    process.exit(1);
  }
  
  process.exit(0);
}

fixAdminAccount();
