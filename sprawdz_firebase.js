const admin = require('firebase-admin');

// Sprawdź czy plik serviceAccountKey.json istnieje
const fs = require('fs');
if (!fs.existsSync('./serviceAccountKey.json')) {
  console.log('❌ BŁĄD: Brak pliku serviceAccountKey.json');
  console.log('');
  console.log('📋 ROZWIĄZANIE:');
  console.log('1. Firebase Console → Project Settings (⚙️)');
  console.log('2. Service Accounts');
  console.log('3. Generate new private key');
  console.log('4. Zapisz jako serviceAccountKey.json w głównym folderze projektu');
  console.log('');
  process.exit(1);
}

const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function sprawdzFirebase() {
  console.log('🔍 DIAGNOSTYKA FIREBASE\n');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  try {
    // 1. Sprawdź projekt
    console.log('📊 Projekt Firebase:');
    console.log('   Project ID:', serviceAccount.project_id);
    console.log('   Client Email:', serviceAccount.client_email);
    console.log('');

    // 2. Sprawdź Authentication
    console.log('🔐 Firebase Authentication:');
    const listUsersResult = await admin.auth().listUsers(1000);
    console.log(`   Użytkownicy: ${listUsersResult.users.length}`);
    
    if (listUsersResult.users.length > 0) {
      console.log('   ✅ Authentication działa!');
      console.log('   Przykładowi użytkownicy:');
      listUsersResult.users.slice(0, 3).forEach(user => {
        console.log(`      - ${user.email} (UID: ${user.uid.substring(0, 8)}...)`);
      });
    } else {
      console.log('   ⚠️  Brak użytkowników w Authentication');
    }
    console.log('');

    // 3. Sprawdź Firestore - kolekcja strazacy
    console.log('📁 Firestore - kolekcja "strazacy":');
    const strazacySnapshot = await db.collection('strazacy').limit(100).get();
    console.log(`   Dokumenty: ${strazacySnapshot.size}`);
    
    if (strazacySnapshot.size > 0) {
      console.log('   ✅ Firestore działa!');
      console.log('   Przykładowe dokumenty:');
      strazacySnapshot.docs.slice(0, 3).forEach(doc => {
        const data = doc.data();
        console.log(`      - ${data.email} (${data.imie} ${data.nazwisko})`);
        console.log(`        Aktywny: ${data.aktywny}, Role: ${data.role?.join(', ')}`);
      });
    } else {
      console.log('   ❌ Brak dokumentów w kolekcji "strazacy"!');
    }
    console.log('');

    // 4. Porównaj Authentication vs Firestore
    console.log('🔄 Porównanie Authentication <-> Firestore:');
    let zgodne = 0;
    let brakFirestore = 0;
    
    for (const user of listUsersResult.users) {
      const firestoreDoc = await db.collection('strazacy').doc(user.uid).get();
      if (firestoreDoc.exists) {
        zgodne++;
      } else {
        brakFirestore++;
        console.log(`   ⚠️  ${user.email} - ma konto w Auth, ale BRAK w Firestore!`);
      }
    }
    
    console.log(`   ✅ Zgodne: ${zgodne}`);
    console.log(`   ❌ Brak w Firestore: ${brakFirestore}`);
    console.log('');

    // 5. Podsumowanie
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('📋 PODSUMOWANIE:\n');
    
    if (listUsersResult.users.length > 0 && strazacySnapshot.size > 0 && brakFirestore === 0) {
      console.log('✅ WSZYSTKO DZIAŁA POPRAWNIE!');
      console.log('');
      console.log('Jeśli aplikacja nadal nie działa, problem może być w:');
      console.log('  1. Konfiguracji aplikacji (firebase_options.dart)');
      console.log('  2. Regułach Firestore (nie wdrożone lub błędne)');
      console.log('  3. Cache aplikacji (uruchom: flutter clean)');
    } else if (brakFirestore > 0) {
      console.log('⚠️  ZNALEZIONO PROBLEM!');
      console.log('');
      console.log(`${brakFirestore} użytkowników ma konto w Authentication,`);
      console.log('ale NIE MA dokumentu w Firestore!');
      console.log('');
      console.log('🔧 ROZWIĄZANIE:');
      console.log('   Uruchom: node create_all_firestore_docs.js');
    } else {
      console.log('❌ FIREBASE JEST PUSTY!');
      console.log('');
      console.log('🔧 ROZWIĄZANIE:');
      console.log('   1. Dodaj użytkowników w Firebase Console → Authentication');
      console.log('   2. Uruchom: node create_all_firestore_docs.js');
    }
    console.log('');

  } catch (error) {
    console.error('❌ BŁĄD:', error.message);
    console.error('');
    
    if (error.code === 'app/invalid-credential') {
      console.log('💡 Problem z serviceAccountKey.json');
      console.log('   Pobierz nowy klucz z Firebase Console → Project Settings → Service Accounts');
    }
  }
  
  process.exit(0);
}

sprawdzFirebase();
