const admin = require('firebase-admin');

const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function activateAll() {
  try {
    const snapshot = await db.collection('strazacy').where('aktywny', '==', false).get();
    
    console.log(`📋 Znaleziono ${snapshot.size} nieaktywnych użytkowników\n`);
    
    for (const doc of snapshot.docs) {
      const data = doc.data();
      console.log(`✅ Aktywuję: ${data.email} (${data.imie} ${data.nazwisko})`);
      
      await doc.ref.update({
        aktywny: true
      });
    }
    
    console.log(`\n🎉 Aktywowano ${snapshot.size} użytkowników!`);
    console.log('Wszyscy mogą się teraz zalogować!\n');
    
  } catch (error) {
    console.error('❌ Błąd:', error.message);
  }
  
  process.exit(0);
}

activateAll();
