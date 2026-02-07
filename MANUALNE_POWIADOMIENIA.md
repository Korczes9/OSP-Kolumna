# 📱 Manualne Wysyłanie Powiadomień Push - Przewodnik

## ✅ Wybrana opcja: Manualne wysyłanie z Firebase Console

Bez potrzeby Cloud Functions i planu Blaze - wystarczy Firebase Spark (darmowy).

---

## 🎯 Co Działa

- ✅ Odbieranie powiadomień push na urządzeniach
- ✅ Pełnoekranowy ekran alarmu z dźwiękiem syreny
- ✅ Powiadomienia standardowe
- ✅ Alarm testowy w aplikacji
- ✅ Zapisywanie tokenów FCM w bazie danych
- ✅ Wszystkie typy powiadomień (ALARM, WYDARZENIE, PRZYPOMNIENIE)

**Różnica:** Musisz wysłać powiadomienie ręcznie z Firebase Console zamiast automatycznie.

---

## 📋 KROK 1: Włącz Cloud Messaging

1. Otwórz Firebase Console: https://console.firebase.google.com/
2. Wybierz projekt: **OSP Kolumna**
3. Menu → **Cloud Messaging** (lub **Messaging**)
4. Jeśli nieaktywne, kliknij **Get started** lub **Enable**

---

## 📋 KROK 2: Znajdź Tokeny FCM Użytkowników

### Opcja A: Z Firestore Console (łatwiej)

1. Firebase Console → **Firestore Database**
2. Kolekcja: **strazacy**
3. Kliknij na dowolnego strażaka
4. Znajdź pole: **fcmToken**
5. Skopiuj wartość (długi ciąg znaków)

**Przykład:**
```
dXJ2eVNIRk9iVGc6QVBBOTFiRzF...(~160 znaków)
```

### Opcja B: Wyślij do wszystkich (topic)

Zamiast zbierać tokeny, możesz subskrybować wszystkich do tematu.

---

## 🚨 KROK 3: Wysyłanie ALARMU

### W Firebase Console:

1. Przejdź do: https://console.firebase.google.com/project/osp-kolumna/messaging
2. Kliknij **New campaign** → **Notifications**

### Wypełnij formularz:

**Notification:**
- **Title:** `🚨 ALARM!`
- **Text:** `Pożar - ul. Główna 15, Kolumna`
- **Image URL:** _(pozostaw puste)_

**Target:**
- Wybierz: **Select user segment**
- Wybierz: **All users** (lub **Single device** i wklej token FCM)

**Additional options** (WAŻNE - kliknij "+" aby rozwinąć):

Dodaj **Custom data** (kluczowe dla pełnoekranowego alarmu):

| Klucz | Wartość |
|-------|---------|
| `type` | `ALARM` |
| `kategoria` | `Pożar` |
| `lokalizacja` | `ul. Główna 15, Kolumna` |
| `opis` | `Zgłoszenie pożaru budynku mieszkalnego` |
| `wyjazdId` | `test123` _(opcjonalnie)_ |

**Scheduling:**
- Wybierz: **Now** (natychmiast)

**Kliknij:** **Review** → **Publish**

---

## 📅 KROK 4: Wysyłanie Powiadomienia o Wydarzeniu

**Title:** `📅 Nowe wydarzenie: Szkolenie`

**Text:** `Szkolenie BHP - 5 lutego 2026, godz. 18:00`

**Custom data:**

| Klucz | Wartość |
|-------|---------|
| `type` | `WYDARZENIE` |
| `tytul` | `Szkolenie BHP` |
| `typWydarzenia` | `Szkolenie` |
| `wydarzenieId` | `evt123` |

---

## ⏰ KROK 5: Wysyłanie Przypomnienia

**Title:** `⏰ Przypomnienie`

**Text:** `Jutro: Szkolenie BHP o 18:00`

**Custom data:**

| Klucz | Wartość |
|-------|---------|
| `type` | `PRZYPOMNIENIE` |
| `tytul` | `Szkolenie BHP` |
| `wydarzenieId` | `evt123` |

**Scheduling:** Ustaw na dzień wcześniej, np. o 18:00

---

## 🎯 Szybkie Szablony

### Szablon 1: ALARM - Pożar
```
Title: 🚨 ALARM!
Text: Pożar - [adres]

Custom data:
- type: ALARM
- kategoria: Pożar
- lokalizacja: [pełny adres]
- opis: [szczegóły]
```

### Szablon 2: ALARM - Miejscowe zagrożenie
```
Title: 🚨 ALARM!
Text: Miejscowe zagrożenie - [adres]

Custom data:
- type: ALARM
- kategoria: Miejscowe zagrożenie
- lokalizacja: [pełny adres]
- opis: [szczegóły]
```

### Szablon 3: Szkolenie
```
Title: 📅 Nowe szkolenie
Text: [nazwa szkolenia] - [data]

Custom data:
- type: WYDARZENIE
- typWydarzenia: Szkolenie
- tytul: [nazwa]
```

### Szablon 4: Ćwiczenia
```
Title: 📅 Nowe ćwiczenia
Text: [opis] - [data]

Custom data:
- type: WYDARZENIE
- typWydarzenia: Ćwiczenia
- tytul: [opis]
```

---

## 📊 Test Powiadomień

### Test 1: Lokalny (w aplikacji)
1. Uruchom aplikację: `flutter run -d chrome`
2. Kliknij ikonę alarmu testowego w AppBar
3. Sprawdź czy działa pełnoekranowy alarm z dźwiękiem ✅

### Test 2: Rzeczywiste FCM
1. Pobierz token FCM z Firestore (kolekcja `strazacy`)
2. Wyślij powiadomienie testowe (jak w KROK 3)
3. Sprawdź czy powiadomienie przychodzi
4. Kliknij w powiadomienie - powinien się otworzyć pełnoekranowy alarm

---

## 💡 Automatyzacja (Opcjonalna)

Jeśli chcesz częściowo zautomatyzować, możesz:

### Opcja 1: Trigger w aplikacji
Dodaj przycisk "Wyślij alarm do wszystkich" dla Administratora.

### Opcja 2: Aplikacja webowa
Prosta strona HTML z formularzem, która wysyła powiadomienia przez Firebase Admin SDK.

### Opcja 3: Skrypt Python/Node.js
Lokalny skrypt na komputerze do szybkiego wysyłania alarmów.

**Przykład Node.js:**
```javascript
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function wyslijAlarm(lokalizacja, opis) {
  const tokens = []; // Pobierz z Firestore
  
  await admin.messaging().sendToDevice(tokens, {
    notification: {
      title: '🚨 ALARM!',
      body: `Pożar - ${lokalizacja}`
    },
    data: {
      type: 'ALARM',
      kategoria: 'Pożar',
      lokalizacja: lokalizacja,
      opis: opis
    }
  });
}

// Użycie:
wyslijAlarm('ul. Główna 15', 'Pożar budynku');
```

---

## 📝 Najlepsze Praktyki

1. **Przygotuj szablony** - zapisz gotowe wiadomości w notesie
2. **Test przed wysłaniem** - zawsze testuj na swoim urządzeniu
3. **Sprawdzaj tokeny** - upewnij się że są aktualne w Firestore
4. **Czas reakcji** - wysyłaj natychmiast po otrzymaniu zgłoszenia
5. **Jasne komunikaty** - precyzyjny adres i kategoria

---

## ⚙️ Konfiguracja Subskrypcji Tematów (Zaawansowane)

Zamiast zbierać tokeny, możesz używać tematów (topics):

### W aplikacji (dodaj do SerwisPowiadomien):
```dart
// Subskrybuj wszystkich do tematu 'alarmy'
await FirebaseMessaging.instance.subscribeToTopic('alarmy_osp');
```

### W Firebase Console:
Wysyłając powiadomienie wybierz:
- **Target:** Topic
- **Topic name:** `alarmy_osp`

**Zalety:**
- Nie musisz znać tokenów
- Automatyczne zarządzanie subskrybentami
- Łatwiejsze wysyłanie

---

## 🎯 Checklist Wdrożenia

- [ ] Cloud Messaging włączone w Firebase Console
- [ ] Aplikacja zapisuje tokeny FCM w Firestore
- [ ] Test lokalny alarmu działa (przycisk w AppBar)
- [ ] Wysłane testowe powiadomienie z Firebase Console
- [ ] Powiadomienie dotarło na urządzenie
- [ ] Kliknięcie w powiadomienie otwiera pełnoekranowy alarm
- [ ] Przygotowane szablony dla różnych typów alarmów
- [ ] Wszyscy strażacy mają aplikację zainstalowaną

---

## ✅ Gotowe!

System powiadomień działa manualnie - wystarczy wysłać z Firebase Console gdy potrzeba.

**Zalety:**
- ✅ Bez kosztów (plan Spark - darmowy)
- ✅ Bez Cloud Functions
- ✅ Pełna kontrola nad każdym powiadomieniem
- ✅ Wszystkie funkcje aplikacji działają

**Wady:**
- ⏱️ Wymaga ręcznego wysłania (30 sekund)
- 👤 Wymaga dostępu do Firebase Console

---

**Wsparcie:** Zobacz POWIADOMIENIA_PUSH.md dla szczegółów technicznych
