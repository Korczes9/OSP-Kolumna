/**
 * Skrypt do masowego dodawania użytkowników OSP Kolumna do Firestore
 * 
 * JAK UŻYĆ:
 * 1. Otwórz Firebase Console → Firestore Database
 * 2. Kliknij zakładkę "Rules" (będziemy używać konsoli w przeglądarce)
 * 3. Otwórz Console w przeglądarce (F12)
 * 4. Kliknij zakładkę "Console"
 * 5. Skopiuj i wklej CAŁY ten kod
 * 6. Naciśnij Enter
 * 
 * WAŻNE: Najpierw musisz dodać użytkowników w Authentication i wkleić ich UID poniżej!
 */

// DANE UŻYTKOWNIKÓW - UZUPEŁNIJ User UID z Authentication!
const users = [
  {
    uid: "XGQrC30tekcPPJuCNJX5SRILNc32", // korczes9@gmail.com
    imie: "Sebastian",
    nazwisko: "Grochulski",
    email: "korczes9@gmail.com",
    numerTelefonu: "000000000",
    rola: "administrator",
    aktywny: true,
    dataRejestracji: "2026-01-28T10:00:00Z"
  },
  {
    uid: "JfGt9tryQfgPFBpP8xptuqlrWPk2", // osp_kolumna@straz.edu.pl
    imie: "OSP",
    nazwisko: "Kolumna",
    email: "osp_kolumna@straz.edu.pl",
    numerTelefonu: "000000000",
    rola: "moderator",
    aktywny: true,
    dataRejestracji: "2026-01-28T10:00:00Z"
  },
  {
    uid: "ANqIHWHneEOzLGeuJoMJDLtBRY32", // 2bora@wp.pl
    imie: "Dariusz",
    nazwisko: "Borkiewicz",
    email: "2bora@wp.pl",
    numerTelefonu: "000000000",
    rola: "strazak",
    aktywny: true,
    dataRejestracji: "2026-01-28T10:00:00Z"
  },
  {
    uid: "YS9gMgVwj2UCJlsy8uOpsEMhjks1", // patrykborzecki11@gmail.com
    imie: "Patryk",
    nazwisko: "Borzęcki",
    email: "patrykborzecki11@gmail.com",
    numerTelefonu: "000000000",
    rola: "strazak",
    aktywny: true,
    dataRejestracji: "2026-01-28T10:00:00Z"
  },
  {
    uid: "QlLqEfal13QHM7TdB3rqBbo0Uu72", // krystianof12@interia.pl
    imie: "Krystian",
    nazwisko: "Felcenloben",
    email: "krystianof12@interia.pl",
    numerTelefonu: "000000000",
    rola: "strazak",
    aktywny: true,
    dataRejestracji: "2026-01-28T10:00:00Z"
  },
  {
    uid: "PcL1wp0uncS0rqSaBirFnlwO0uI3", // kamil1703@o2.pl
    imie: "Kamil",
    nazwisko: "Grzelak",
    email: "kamil1703@o2.pl",
    numerTelefonu: "000000000",
    rola: "strazak",
    aktywny: true,
    dataRejestracji: "2026-01-28T10:00:00Z"
  },
  {
    uid: "JeFZenoH7ug5PVjt5lcydorW0qF3", // domio123dko@gmail.com
    imie: "Dominik",
    nazwisko: "Kłos",
    email: "domio123dko@gmail.com",
    numerTelefonu: "000000000",
    rola: "strazak",
    aktywny: true,
    dataRejestracji: "2026-01-28T10:00:00Z"
  },
  {
    uid: "xgqSfZkc9OVNtNZkMH7kzstKRNq1", // kacper.knop4@wp.pl
    imie: "Kacper",
    nazwisko: "Knop",
    email: "kacper.knop4@wp.pl",
    numerTelefonu: "000000000",
    rola: "strazak",
    aktywny: true,
    dataRejestracji: "2026-01-28T10:00:00Z"
  },
  {
    uid: "kdbDRqeAomZ3xqpAQtXQGz5321b2", // hubert.469b@gmail.com
    imie: "Hubert",
    nazwisko: "Kowalski",
    email: "hubert.469b@gmail.com",
    numerTelefonu: "000000000",
    rola: "strazak",
    aktywny: true,
    dataRejestracji: "2026-01-28T10:00:00Z"
  },
  {
    uid: "w4VHh68rkubI3C884nvyiRI0FMa2", // korkihard9@wp.pl
    imie: "Jerzy",
    nazwisko: "Kowalski",
    email: "korkihard9@wp.pl",
    numerTelefonu: "000000000",
    rola: "strazak",
    aktywny: true,
    dataRejestracji: "2026-01-28T10:00:00Z"
  },
  {
    uid: "wc9sHeoNbPfzkP9p0KKYKWVhQD72", // kamil.kubsz@o2.pl
    imie: "Kamil",
    nazwisko: "Kubsz",
    email: "kamil.kubsz@o2.pl",
    numerTelefonu: "000000000",
    rola: "strazak",
    aktywny: true,
    dataRejestracji: "2026-01-28T10:00:00Z"
  },
  {
    uid: "dDQ4oz3ODnVMTn275ncU7df38Pf1", // robertkujawa3108@gmail.com
    imie: "Robert",
    nazwisko: "Kujawa",
    email: "robertkujawa3108@gmail.com",
    numerTelefonu: "000000000",
    rola: "strazak",
    aktywny: true,
    dataRejestracji: "2026-01-28T10:00:00Z"
  },
  {
    uid: "ksn7s8A8IZMoUN7KO6ZHUD1oPuw2", // kubamarki@gmail.com
    imie: "Jakub",
    nazwisko: "Markiewicz",
    email: "kubamarki@gmail.com",
    numerTelefonu: "000000000",
    rola: "moderator",
    aktywny: true,
    dataRejestracji: "2026-01-28T10:00:00Z"
  },
  {
    uid: "DHBmdS1yndRH8IdH3T3tyUdsdK43", // michalmataska201@go2.pl
    imie: "Michał",
    nazwisko: "Mataśka",
    email: "michalmataska201@go2.pl",
    numerTelefonu: "000000000",
    rola: "strazak",
    aktywny: true,
    dataRejestracji: "2026-01-28T10:00:00Z"
  },
  {
    uid: "eygsNPnD9JWTzHffgUVU7FEF6ww2", // bartek1292001@wp.pl
    imie: "Bartłomiej",
    nazwisko: "Nowicki",
    email: "bartek1292001@wp.pl",
    numerTelefonu: "000000000",
    rola: "strazak",
    aktywny: true,
    dataRejestracji: "2026-01-28T10:00:00Z"
  },
  {
    uid: "PYuNOq8kyufXfZW0OZGEd6CIJbF2", // palmateusz641@gmail.com
    imie: "Mateusz",
    nazwisko: "Paliwoda",
    email: "palmateusz641@gmail.com",
    numerTelefonu: "000000000",
    rola: "strazak",
    aktywny: true,
    dataRejestracji: "2026-01-28T10:00:00Z"
  },
  {
    uid: "JHo9q4NRgiUzDPozgWqBmnNj5QX2", // dpawlak@autograf.pl
    imie: "Damian",
    nazwisko: "Pawlak",
    email: "dpawlak@autograf.pl",
    numerTelefonu: "000000000",
    rola: "strazak",
    aktywny: true,
    dataRejestracji: "2026-01-28T10:00:00Z"
  },
  {
    uid: "In3uO9ZJr5Smcekso6m6YLJOntl2", // ppiecyk@onet.pl
    imie: "Piotr",
    nazwisko: "Piecyk",
    email: "ppiecyk@onet.pl",
    numerTelefonu: "000000000",
    rola: "strazak",
    aktywny: true,
    dataRejestracji: "2026-01-28T10:00:00Z"
  }
];

// Funkcja dodająca użytkowników do Firestore
async function addUsersToFirestore() {
  console.log("🚀 Rozpoczynam dodawanie użytkowników do Firestore...");
  
  const db = firebase.firestore();
  let added = 0;
  let errors = 0;
  
  for (const user of users) {
    if (user.uid.startsWith("WKLEJ_USER_UID")) {
      console.warn(`⚠️  Pomiń: ${user.email} - brak UID!`);
      errors++;
      continue;
    }
    
    try {
      const { uid, ...userData } = user;
      await db.collection('strazacy').doc(uid).set(userData);
      console.log(`✅ Dodano: ${user.imie} ${user.nazwisko} (${user.email})`);
      added++;
    } catch (error) {
      console.error(`❌ Błąd dla ${user.email}:`, error);
      errors++;
    }
  }
  
  console.log("\n" + "=".repeat(50));
  console.log(`✅ Dodano: ${added} użytkowników`);
  console.log(`❌ Błędy: ${errors}`);
  console.log("=".repeat(50));
  
  if (added > 0) {
    console.log("\n🎉 GOTOWE! Sprawdź Firestore Database → Data → strazacy");
  }
}

// Uruchom
addUsersToFirestore();
