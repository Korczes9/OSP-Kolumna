const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function aktywujUzytkownikow() {
  try {
    const emails = [
      'sebek112998@gmail.com',
      'osp_kolumna@straz.edu.pl'
    ];

    console.log('🔓 Aktywacja użytkowników:\n');

    for (const email of emails) {
      // Znajdź użytkownika po emailu
      const query = await db.collection('strazacy')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

      if (!query.empty) {
        const doc = query.docs[0];
        await doc.ref.update({ aktywny: true });
        console.log(`✅ ${email} - AKTYWOWANY`);
      } else {
        console.log(`❌ ${email} - nie znaleziono`);
      }
    }

    console.log('\n✅ Aktywacja zakończona!\n');
    console.log('Użytkownicy mogą się teraz zalogować do aplikacji.');

  } catch (error) {
    console.error('❌ Błąd:', error.message);
  }

  process.exit(0);
}

aktywujUzytkownikow();
