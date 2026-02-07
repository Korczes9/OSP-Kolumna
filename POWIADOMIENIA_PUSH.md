# 📱 Powiadomienia Push - Dokumentacja

## ✅ Zaimplementowane Funkcje

### 1. **Powiadomienia o Nowych Wyjazdach/Alarmach**
- Automatyczne wysyłanie alarmu do wszystkich aktywnych strażaków
- Pełnoekranowy ekran alarmu z dźwiękiem syreny
- Priorytet WYSOKI dla natychmiastowego dostarczenia
- Dane zawierają: lokalizację, kategorię, opis, ID wyjazdu

### 2. **Powiadomienia o Nowych Wydarzeniach**
- Informacja o dodaniu szkolenia, ćwiczeń, zebrania
- Tylko dla wydarzeń widocznych dla wszystkich
- Dane zawierają: tytuł, typ wydarzenia, datę

### 3. **Przypomnienia o Nadchodzących Wydarzeniach**
- Automatyczne przypomnienie 1 dzień przed wydarzeniem
- Wysyłane codziennie o 18:00
- Cloud Function z harmonogramem (cron job)

### 4. **System Zarządzania Tokenami FCM**
- Automatyczne zapisywanie tokenów w bazie danych
- Odświeżanie tokenów przy każdej zmianie
- Przechowywanie w profilu użytkownika (`strazacy` -> `fcmToken`)

---

## 🔧 Architektura Systemu

### Komponenty:

1. **SerwisPowiadomien** (`lib/services/serwis_powiadomien.dart`)
   - Inicjalizacja FCM i żądanie uprawnień
   - Obsługa powiadomień w foreground i background
   - Funkcje wysyłania powiadomień
   - Odtwarzanie dźwięku alarmu

2. **Cloud Functions** (`functions/index.js`)
   - `wyslijPowiadomienie` - wysyła powiadomienia do tokenów
   - `wyslijPrzypomnienia` - cron job dla przypomnień (18:00 codziennie)

3. **Kolekcja Firestore: notifications**
   ```
   {
     type: 'ALARM' | 'WYDARZENIE' | 'PRZYPOMNIENIE',
     tokens: [array tokenów FCM],
     wyslane: false,
     timestamp: ServerTimestamp,
     // ... dane specyficzne dla typu
   }
   ```

---

## 📝 Jak Działa System

### Wysyłanie Powiadomienia o Wyjeździe:

1. Administrator/Moderator dodaje wyjazd
2. `SerwisWyjazdow.dodajWyjazd()` wywołuje:
   ```dart
   SerwisPowiadomien.wyslijPowiadomienieOWyjeździe(
     wyjazdId: docRef.id,
     kategoria: kategoria.nazwa,
     lokalizacja: lokalizacja,
     opis: opis,
   )
   ```
3. Funkcja tworzy dokument w kolekcji `notifications`
4. Cloud Function `wyslijPowiadomienie` zostaje uruchomiona
5. FCM wysyła powiadomienia do wszystkich aktywnych strażaków
6. Dokument oznaczany jako `wyslane: true`

### Odbiór Powiadomienia:

**Aplikacja otwarta (foreground):**
- `FirebaseMessaging.onMessage` - wyświetla SnackBar lub pełny ekran alarmu
- Dla typu ALARM - pełnoekranowy dialog + dźwięk syreny

**Aplikacja w tle (background):**
- System Android/iOS wyświetla standardowe powiadomienie
- Kliknięcie otwiera aplikację i uruchamia akcję

**Aplikacja zamknięta:**
- `FirebaseMessaging.onMessageOpenedApp` obsługuje otwarcie z powiadomienia
- Przekierowanie do odpowiedniego ekranu

---

## 🚀 Konfiguracja (dla Firebase Console)

### 1. Włącz Firebase Cloud Messaging:
- Przejdź do Firebase Console
- Projekt: OSP Kolumna
- Cloud Messaging → Włącz API

### 2. Wdróż Cloud Functions:
```bash
cd functions
npm install
firebase deploy --only functions
```

### 3. Skonfiguruj harmonogram:
Cloud Function `wyslijPrzypomnienia` automatycznie:
- Uruchamia się codziennie o 18:00 czasu polskiego
- Sprawdza wydarzenia na następny dzień
- Wysyła przypomnienia

### 4. Testowanie:
W aplikacji użyj przycisku "Testowy Alarm" w AppBar.

---

## 📊 Typy Powiadomień

### ALARM (Najwyższy priorytet)
```dart
{
  'type': 'ALARM',
  'wyjazdId': 'xyz123',
  'kategoria': 'Pożar',
  'lokalizacja': 'ul. Główna 15',
  'opis': 'Zgłoszenie pożaru',
  'godzina': '2026-02-02T14:30:00Z'
}
```
**Zachowanie:**
- Pełnoekranowy dialog
- Dźwięk syreny
- Czerwony kolor
- Przycisk "POTWIERDŹ ODBIÓR"

### WYDARZENIE
```dart
{
  'type': 'WYDARZENIE',
  'wydarzenieId': 'abc456',
  'tytul': 'Szkolenie BHP',
  'typWydarzenia': 'Szkolenie',
  'dataRozpoczecia': Timestamp
}
```
**Zachowanie:**
- Standardowe powiadomienie
- Niebieski kolor
- Przekierowanie do terminarza

### PRZYPOMNIENIE
```dart
{
  'type': 'PRZYPOMNIENIE',
  'wydarzenieId': 'abc456',
  'tytul': 'Szkolenie BHP',
  'dataRozpoczecia': Timestamp
}
```
**Zachowanie:**
- Standardowe powiadomienie
- Pomarańczowy kolor
- Przekierowanie do terminarza

---

## 🔐 Bezpieczeństwo

### Reguły Firestore dla `notifications`:
```javascript
match /notifications/{notificationId} {
  // Tylko Cloud Functions mogą tworzyć/modyfikować
  allow read: if false;
  allow write: if false;
}
```

### Tokeny FCM:
- Przechowywane bezpiecznie w Firestore
- Aktualizowane automatycznie przy każdej zmianie
- Dostępne tylko dla Cloud Functions

---

## 🧪 Testowanie

### Test lokalny (symulacja):
```dart
// W dowolnym miejscu aplikacji
SerwisPowiadomien.wyslijTestowyAlarm();
```

### Test rzeczywisty (Cloud Function):
1. Dodaj wyjazd przez aplikację
2. Sprawdź kolekcję `notifications` w Firestore
3. Obserwuj logi Cloud Functions
4. Powiadomienie powinno przyjść na urządzenie

### Logi Cloud Functions:
```bash
firebase functions:log --only wyslijPowiadomienie
firebase functions:log --only wyslijPrzypomnienia
```

---

## 📈 Metryki i Monitorowanie

Każde wysłane powiadomienie zawiera:
- `successCount` - liczba pomyślnie dostarczonych
- `failureCount` - liczba błędów
- `wyslaneDnia` - timestamp wysłania

Możesz monitorować skuteczność w Firestore Console.

---

## ⚡ Optymalizacja

### Limity FCM:
- Maksymalnie 500 tokenów na jedno wywołanie
- System automatycznie dzieli na partie (batches)

### Koszty:
- Cloud Functions - bezpłatne do 2M wywołań/miesiąc
- FCM - całkowicie bezpłatne

---

## 🛠️ Rozwiązywanie Problemów

### Powiadomienia nie przychodzą:
1. Sprawdź uprawnienia w aplikacji (Settings → Notifications)
2. Sprawdź czy token FCM jest zapisany w Firestore
3. Sprawdź logi Cloud Functions
4. Sprawdź kolekcję `notifications` - czy `wyslane: true`?

### Token null/undefined:
- Upewnij się że `SerwisPowiadomien.inicjalizuj()` jest wywoływane
- Sprawdź połączenie internetowe
- Zrestartuj aplikację

### Cloud Function nie działa:
```bash
# Sprawdź logi
firebase functions:log

# Wdróż ponownie
firebase deploy --only functions:wyslijPowiadomienie
```

---

## 📚 Dalszy Rozwój

### Planowane funkcje:
- [ ] Personalizacja powiadomień (wybór typów)
- [ ] Historia powiadomień w aplikacji
- [ ] Powiadomienia o zmianach w dyżurach
- [ ] Powiadomienia o wygasających certyfikatach sprzętu
- [ ] Grupowanie powiadomień
- [ ] Akcje z poziomu powiadomienia (Potwierdź/Odrzuć)

---

## ✅ Podsumowanie

System powiadomień push jest w pełni funkcjonalny i gotowy do użycia:

✅ Automatyczne powiadomienia o alarmach  
✅ Powiadomienia o wydarzeniach  
✅ Przypomnienia (cron job)  
✅ Zarządzanie tokenami FCM  
✅ Cloud Functions działają  
✅ Obsługa foreground/background  
✅ Pełnoekranowy alarm z dźwiękiem  

**Status: GOTOWE do wdrożenia produkcyjnego** 🚀
