const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function aktywujUzytkownikow() {
  try {
    const users = [
      { uid: '7w8bKg5qgwOnYaMlYU4qcARZApw2', email: 'sebek112998@gmail.com' },
      { uid: 'JfGt9tryQfgPFBpP8xptuqlrWPk2', email: 'osp_kolumna@straz.edu.pl' }
    ];

    console.log('🔓 Aktywacja użytkowników:\n');

    for (const user of users) {
      await db.collection('strazacy').doc(user.uid).update({ 
        aktywny: true 
      });
      console.log(`✅ ${user.email} - AKTYWOWANY`);
    }

    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('✅ Aktywacja zakończona!\n');
    console.log('Użytkownicy mogą się teraz zalogować.');

  } catch (error) {
    console.error('❌ Błąd:', error.message);
  }

  process.exit(0);
}

aktywujUzytkownikow();
