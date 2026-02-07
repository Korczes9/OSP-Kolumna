const admin = require('firebase-admin');

const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function listUsers() {
  try {
    // Pobierz wszystkich użytkowników z Authentication
    const listUsersResult = await admin.auth().listUsers(1000);
    
    console.log('👥 Użytkownicy w Firebase Authentication:\n');
    
    for (const userRecord of listUsersResult.users) {
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      console.log('Email:', userRecord.email);
      console.log('UID:', userRecord.uid);
      
      // Sprawdź czy istnieje w Firestore
      const firestoreDoc = await db.collection('strazacy').doc(userRecord.uid).get();
      
      if (firestoreDoc.exists) {
        console.log('✅ Firestore: TAK');
        const data = firestoreDoc.data();
        console.log('   Imię:', data.imie);
        console.log('   Nazwisko:', data.nazwisko);
        console.log('   Role:', data.role);
      } else {
        console.log('❌ Firestore: BRAK DOKUMENTU');
        console.log('   ⚠️  Ten użytkownik NIE MOŻE się zalogować!');
      }
    }
    
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    console.log('💡 Aby naprawić użytkownika bez dokumentu:');
    console.log('   1. Skopiuj jego UID');
    console.log('   2. Podaj mi email tego użytkownika');
    console.log('   3. Utworzę dla niego dokument Firestore\n');
    
  } catch (error) {
    console.error('❌ Błąd:', error.message);
  }
  
  process.exit(0);
}

listUsers();
