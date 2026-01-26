// Konfiguracja Firebase dla aplikacji webowej OSP Kolumna
const konfiguracjaFirebase = {
  apiKey: "AIzaSyAN41HYHixjeDVUzJqSetNgQZ2hQRPpplI",
  authDomain: "osp-kolumna.firebaseapp.com",
  projectId: "osp-kolumna",
  storageBucket: "osp-kolumna.firebasestorage.app",
  messagingSenderId: "337488247760",
  appId: "1:337488247760:web:osp-kolumna-web",
};

// Inicjalizacja Firebase
firebase.initializeApp(konfiguracjaFirebase);

// Referencje do usług Firebase
const autentykacjaFirebase = firebase.auth();
const bazaDanychwFirestore = firebase.firestore();
const zaocznyMessaging = firebase.messaging();

// Konfiguracja Firestore
bazaDanychwFirestore.settings({
  timestampsInSnapshots: true
});

console.log("✓ Firebase zainicjalizowany pomyślnie");
