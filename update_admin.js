const admin = require('firebase-admin');

const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function updateAdmin() {
  const uid = 'XGQrC30tekcPPJuCNJX5SRILNc32';
  const now = new Date().toISOString();
  
  try {
    // Najpierw usuń stare pola
    await db.collection('strazacy').doc(uid).update({
      rola: admin.firestore.FieldValue.delete(),
      ostatniaAktywnosc: admin.firestore.FieldValue.delete()
    });
    
    console.log('✅ Usunięto stare pola');
    
    // Teraz ustaw poprawne dane
    await db.collection('strazacy').doc(uid).set({
      email: 'korczes9@gmail.com',
      role: ['administrator'],
      aktywny: true,
      imie: 'Sebastian',
      nazwisko: 'Grochulski',
      numerTelefonu: '691837009',
      dostepny: false,
      dataRejestracji: now,
      ostatnioAktywny: now
    });
    
    console.log('✅ Zaktualizowano dane!');
    
    const doc = await db.collection('strazacy').doc(uid).get();
    console.log('\n📋 Aktualne dane:');
    console.log(JSON.stringify(doc.data(), null, 2));
    
  } catch (error) {
    console.error('❌ Błąd:', error.message);
  }
  
  process.exit(0);
}

updateAdmin();
