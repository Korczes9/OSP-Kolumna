const admin = require('firebase-admin');

// Inicjalizacja Firebase Admin SDK
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function createAdminUser() {
  const email = 'korczes9@gmail.com';
  const password = 'Admin123!'; // Zmień hasło po pierwszym logowaniu!
  
  try {
    // Tworzenie użytkownika Authentication
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      emailVerified: true,
      disabled: false
    });
    
    console.log('✅ Pomyślnie utworzono użytkownika Authentication!');
    console.log('UID:', userRecord.uid);
    console.log('Email:', userRecord.email);
    console.log('\n⚠️  WAŻNE: Skopiuj poniższy UID i zaktualizuj dokument Firestore!');
    console.log('\n📋 Kroki do wykonania:');
    console.log('1. Przejdź do: https://console.firebase.google.com/project/osp-kolumna/firestore/data');
    console.log('2. Znajdź kolekcję "strazacy"');
    console.log('3. Usuń stary dokument dla korczes9@gmail.com');
    console.log('4. Utwórz NOWY dokument z ID:', userRecord.uid);
    console.log('5. Dodaj pola:');
    console.log('   - email: "korczes9@gmail.com"');
    console.log('   - role: ["administrator"]  (TABLICA!)');
    console.log('   - aktywny: true');
    console.log('   - imie: "Admin"');
    console.log('   - nazwisko: "(twoje nazwisko)"');
    console.log('\n🔐 Hasło tymczasowe: Admin123!');
    console.log('(Zmień je po pierwszym zalogowaniu!)');
    
  } catch (error) {
    console.error('❌ Błąd:', error.message);
    
    if (error.code === 'auth/email-already-exists') {
      console.log('\n⚠️  Użytkownik już istnieje w Authentication!');
      console.log('Pobieram jego UID...\n');
      
      try {
        const existingUser = await admin.auth().getUserByEmail(email);
        console.log('✅ Znaleziono istniejącego użytkownika:');
        console.log('UID:', existingUser.uid);
        console.log('Email:', existingUser.email);
        console.log('\n📋 Zaktualizuj dokument Firestore używając tego UID jako ID dokumentu!');
      } catch (getError) {
        console.error('Błąd pobierania użytkownika:', getError.message);
      }
    }
  }
  
  process.exit(0);
}

createAdminUser();
