# 🚀 Wdrożenie Powiadomień Push - Przewodnik Krok Po Kroku

## ✅ Co Jest Już Gotowe

1. **Kod aplikacji** - SerwisPowiadomien zaimplementowany
2. **Cloud Functions** - funkcje wyslijPowiadomienie i wyslijPrzypomnienia
3. **Integracja** - automatyczne wysyłanie przy dodawaniu wyjazdów/wydarzeń
4. **Dokumentacja** - POWIADOMIENIA_PUSH.md

---

## 📋 Kroki Wdrożenia

### KROK 1: Wdróż Cloud Functions

```bash
# W terminalu PowerShell
cd c:\Users\User\Desktop\Projekt\flutter_projekt_polski

# Zaloguj się do Firebase (jeśli jeszcze nie jesteś)
firebase login

# Wdróż funkcje
firebase deploy --only functions
```

**Oczekiwany wynik:**
```
✔  functions[wyslijPowiadomienie(europe-central2)] Successful create operation.
✔  functions[wyslijPrzypomnienia(europe-central2)] Successful update operation.
✔  Deploy complete!
```

---

### KROK 2: Włącz Cloud Messaging w Firebase Console

1. Otwórz: https://console.firebase.google.com/
2. Wybierz projekt: **OSP Kolumna**
3. Menu → **Cloud Messaging**
4. Kliknij **Get started** (jeśli jeszcze nie włączone)
5. Skopiuj **Server Key** (do późniejszego użycia w testach)

---

### KROK 3: Konfiguracja Schedulera (dla przypomnień)

Cloud Function `wyslijPrzypomnienia` używa Cloud Scheduler:

1. Otwórz: https://console.cloud.google.com/cloudscheduler
2. Wybierz projekt: **OSP Kolumna**
3. Kliknij **Enable** na Cloud Scheduler API (jeśli wymagane)
4. Job powinien być automatycznie utworzony: `firebase-schedule-wyslijPrzypomnienia-europe-central2`

**Harmonogram:** Codziennie o 18:00 czasu polskiego

---

### KROK 4: Testowanie

#### Test 1: Alarm Testowy (symulacja)
1. Uruchom aplikację: `flutter run -d chrome`
2. Zaloguj się jako Administrator
3. Kliknij ikonę alarmu testowego w AppBar
4. Powinieneś zobaczyć pełnoekranowy alarm z dźwiękiem

#### Test 2: Rzeczywisty Wyjazd
1. W aplikacji dodaj nowy wyjazd (Moderator/Admin)
2. Sprawdź kolekcję `notifications` w Firestore Console
3. Po ~10-30 sekundach dokument powinien mieć `wyslane: true`
4. Powiadomienie powinno przyjść na wszystkie urządzenia

#### Test 3: Wydarzenie
1. Dodaj nowe wydarzenie w terminarzu
2. Sprawdź kolekcję `notifications`
3. Powiadomienie powinno przyjść na urządzenia

#### Test 4: Przypomnienie (wymaga czekania)
1. Dodaj wydarzenie na jutro
2. O 18:00 Cloud Scheduler uruchomi funkcję
3. Wszyscy strażacy dostaną przypomnienie

---

### KROK 5: Monitorowanie

#### Logi Cloud Functions:
```bash
# Oglądaj logi na żywo
firebase functions:log --only wyslijPowiadomienie

# Logi przypomnień
firebase functions:log --only wyslijPrzypomnienia
```

#### Firebase Console:
1. Firestore → Kolekcja `notifications`
   - `wyslane: false` - w kolejce
   - `wyslane: true` - wysłane
   - Sprawdź `successCount` i `failureCount`

2. Cloud Functions → Dashboard
   - Liczba wywołań
   - Błędy
   - Czas wykonania

---

## 🔧 Rozwiązywanie Problemów

### Problem 1: Cloud Functions nie wdrażają się

**Błąd:** `Permission denied`
```bash
# Sprawdź czy jesteś zalogowany
firebase login --reauth

# Sprawdź projekt
firebase use --add
```

**Błąd:** `Node version mismatch`
- Zaktualizowano package.json do Node 20 ✅

---

### Problem 2: Powiadomienia nie przychodzą

**Sprawdź:**
1. Czy FCM token jest zapisany w Firestore?
   ```
   Firestore → strazacy → [userId] → fcmToken
   ```

2. Czy aplikacja ma uprawnienia?
   - Windows: Settings → Notifications → OSP Kolumna → ON
   - Android: Settings → Apps → OSP Kolumna → Notifications → ON

3. Czy Cloud Function się wykonała?
   ```bash
   firebase functions:log --only wyslijPowiadomienie
   ```

4. Czy dokument w `notifications` ma `wyslane: true`?

---

### Problem 3: Przypomnienia nie wysyłają się o 18:00

**Sprawdź:**
1. Cloud Scheduler jest włączony?
   - Console → Cloud Scheduler
   
2. Job istnieje i jest aktywny?
   - Powinien być: `firebase-schedule-wyslijPrzypomnienia-europe-central2`

3. Logi:
   ```bash
   firebase functions:log --only wyslijPrzypomnienia
   ```

4. Ręczne uruchomienie testu:
   ```bash
   # W Firebase Console → Cloud Scheduler
   # Znajdź job i kliknij "RUN NOW"
   ```

---

## 📊 Metryki Wydajności

**Oczekiwane czasy:**
- Dodanie wyjazdu → wysłanie powiadomienia: **< 30 sekund**
- Cloud Function wykonanie: **< 5 sekund**
- Dostarczenie FCM: **< 10 sekund**

**Koszty (darmowy tier):**
- Cloud Functions: 2M wywołań/miesiąc (wystarczy dla 100+ wyjazdów/dzień)
- Cloud Scheduler: 3 zadania/miesiąc (używamy 1)
- FCM: **bezpłatne** bez limitu

---

## ✅ Checklist Wdrożenia

- [ ] `firebase deploy --only functions` wykonane pomyślnie
- [ ] Cloud Messaging włączone w Firebase Console
- [ ] Cloud Scheduler aktywny
- [ ] Test alarmu działa
- [ ] Powiadomienia o wyjazdach działają
- [ ] Powiadomienia o wydarzeniach działają
- [ ] Tokeny FCM zapisują się w Firestore
- [ ] Logi Cloud Functions pokazują sukces
- [ ] Dokumentacja przeczytana

---

## 🎉 Gratulacje!

System powiadomień push jest gotowy do użycia produkcyjnego!

**Kolejne kroki:**
1. Przetestuj z prawdziwymi użytkownikami
2. Monitoruj metryki przez pierwszy tydzień
3. Zbierz feedback od strażaków
4. Opcjonalnie: dodaj personalizację (wybór typów powiadomień)

---

**Wsparcie techniczne:**  
Sprawdź: POWIADOMIENIA_PUSH.md dla szczegółowej dokumentacji
