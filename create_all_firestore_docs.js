const admin = require('firebase-admin');

const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function createMissingDocuments() {
  try {
    const listUsersResult = await admin.auth().listUsers(1000);
    const now = new Date().toISOString();
    let created = 0;
    let skipped = 0;
    
    for (const userRecord of listUsersResult.users) {
      const firestoreDoc = await db.collection('strazacy').doc(userRecord.uid).get();
      
      if (!firestoreDoc.exists) {
        console.log(`📝 Tworzę dokument dla: ${userRecord.email}`);
        
        // Wyciągnij imię z emaila (przed @)
        const emailPrefix = userRecord.email.split('@')[0];
        
        await db.collection('strazacy').doc(userRecord.uid).set({
          email: userRecord.email,
          role: ['strazak'], // Domyślna rola
          aktywny: false, // Wymaga aktywacji przez admina
          imie: emailPrefix,
          nazwisko: '(do uzupełnienia)',
          numerTelefonu: '',
          dostepny: false,
          dataRejestracji: now,
          ostatnioAktywny: now
        });
        
        created++;
        console.log(`   ✅ Utworzono (UID: ${userRecord.uid})`);
      } else {
        skipped++;
      }
    }
    
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log(`✅ Utworzono ${created} nowych dokumentów`);
    console.log(`⏭️  Pominięto ${skipped} (już istnieją)`);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    console.log('⚠️  UWAGA: Wszyscy nowi użytkownicy mają:');
    console.log('   - Rolę: strazak');
    console.log('   - Aktywny: false (musisz ich aktywować!)');
    console.log('\nTeraz wszyscy mogą się zalogować! 🎉\n');
    
  } catch (error) {
    console.error('❌ Błąd:', error.message);
  }
  
  process.exit(0);
}

createMissingDocuments();
