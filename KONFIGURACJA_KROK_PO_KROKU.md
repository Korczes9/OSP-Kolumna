# ✅ Konfiguracja Firebase - Instrukcja Krok Po Kroku

## Szybka ścieżka (bez instalacji dodatkowego oprogramowania)

### Metoda 1: Konfiguracja przez Firebase Console (ZALECANA)

#### Krok 1: Wdróż reguły Firestore (5 minut)

1. **Otwórz Firebase Console:**
   - Przejdź do: https://console.firebase.google.com/
   - Wybierz swój projekt OSP Kolumna

2. **Zaktualizuj reguły bezpieczeństwa:**
   - W menu po lewej kliknij **"Firestore Database"**
   - Kliknij zakładkę **"Rules"** (u góry)
   - **USUŃ** wszystkie istniejące reguły
   - **SKOPIUJ I WKLEJ** zawartość z pliku `firestore.rules` (w katalogu projektu)
   - Kliknij **"Publish"** (Opublikuj)

   ⚠️ **Ważne:** Upewnij się, że skopiowałeś CAŁY plik `firestore.rules`

3. **Zweryfikuj:**
   - Po opublikowaniu powinieneś zobaczyć status "Published" w zielonym kolorze
   - Reguły powinny zawierać funkcje: `isAdministrator()`, `isModerator()`

---

#### Krok 2: Migracja istniejących użytkowników (10-15 minut)

**Opcja A - Jeśli masz 1-5 użytkowników (RĘCZNIE):**

1. W Firebase Console → **Firestore Database**
2. Kliknij kolekcję **"strazacy"**
3. Dla każdego dokumentu (użytkownika):
   
   **Jeśli rola = `naczelnik`:**
   - Kliknij na dokument
   - Znajdź pole `rola`
   - Zmień wartość z `naczelnik` na `administrator`
   - Kliknij "Update" (Aktualizuj)
   
   **Jeśli rola = `dowodca`:**
   - Zmień na `moderator`
   
   **Jeśli rola = `kierowca`:**
   - Zmień na `strazak`
   
   **Jeśli rola = `strazak`:**
   - Zostaw bez zmian

**Opcja B - Jeśli masz więcej użytkowników (UŻYJ KONSOLI FIRESTORE):**

1. W Firebase Console → **Firestore Database**
2. Kliknij zakładkę **"Query"** (u góry, obok Rules)
3. Wykonaj zapytanie:
   ```
   Kolekcja: strazacy
   Gdzie: rola == naczelnik
   ```
4. Dla każdego wyniku zmień `rola` na `administrator`

5. Powtórz dla `dowodca` → `moderator`

---

#### Krok 3: Utwórz pierwszego Administratora w aplikacji

1. **Uruchom aplikację Flutter:**
   ```powershell
   flutter run -d chrome
   ```

2. **Na ekranie logowania:**
   - Kliknij link: **"Pierwsze uruchomienie? Utwórz konto Administratora"**
   
3. **Wprowadź dane:**
   - Email: `administrator@ospkolumna.pl`
   - Hasło: `admin123` (lub własne)
   - Kliknij **"Utwórz konto Administratora"**

4. **Zaloguj się:**
   - Użyj właśnie utworzonych danych
   - Powinieneś zobaczyć **"Panel Administratora"**

---

#### Krok 4: Zaktualizuj role w aplikacji

1. **W aplikacji jako Administrator:**
   - Przejdź do **"Panel Administratora"** → **"Zarządzaj strażakami"**

2. **Dla każdego użytkownika:**
   - Kliknij menu (⋮) przy użytkowniku
   - Jeśli nie widzisz opcji edycji roli, użytkownicy są już zmigrowanei

3. **Przypisz role zgodnie z potrzebami:**
   - **Administrator** - 1-2 osoby (pełne uprawnienia)
   - **Moderator** - dowódcy, zarządcy (edycja wyjazdów, strażaków, etc.)
   - **Strażak** - pozostali członkowie (tylko podgląd)

---

#### Krok 5: Testowanie (5 minut)

**Test jako Strażak:**
1. Zaloguj się jako użytkownik z rolą `strazak`
2. Sprawdź:
   - ✅ Widzisz listę wyjazdów
   - ❌ NIE widzisz przycisku "DODAJ WYJAZD"
   - ❌ NIE widzisz "Panel Administratora"

**Test jako Moderator:**
1. Zaloguj się jako użytkownik z rolą `moderator`
2. Sprawdź:
   - ✅ Widzisz przycisk "DODAJ WYJAZD"
   - ✅ Widzisz "Panel Moderatora"
   - ❌ NIE widzisz "Panel Administratora"

**Test jako Administrator:**
1. Zaloguj się jako użytkownik z rolą `administrator`
2. Sprawdź:
   - ✅ Widzisz przycisk "DODAJ WYJAZD"
   - ✅ Widzisz "Panel Administratora"
   - ✅ Możesz zarządzać strażakami

---

## Metoda 2: Instalacja Firebase CLI (dla zaawansowanych)

Jeśli chcesz używać Firebase CLI do automatyzacji:

### Krok 1: Zainstaluj Node.js

1. Pobierz Node.js: https://nodejs.org/ (LTS version)
2. Zainstaluj (Next → Next → Install)
3. Restart PowerShell

### Krok 2: Zainstaluj Firebase CLI

```powershell
npm install -g firebase-tools
```

### Krok 3: Zaloguj się i wdróż

```powershell
# Zaloguj się
firebase login

# Wdróż reguły
firebase deploy --only firestore:rules

# Wdróż indeksy (opcjonalnie)
firebase deploy --only firestore:indexes
```

---

## ❓ Częste problemy

### Problem 1: "Permission denied" w aplikacji

**Rozwiązanie:**
1. Sprawdź czy reguły zostały opublikowane w Firebase Console
2. Wyloguj się i zaloguj ponownie w aplikacji
3. Sprawdź w Firestore czy pole `rola` ma poprawną wartość

### Problem 2: Nie widzę "Panel Administratora"

**Rozwiązanie:**
1. Sprawdź w Firestore Database czy Twoja rola to `administrator` (nie `naczelnik`)
2. Wyloguj się i zaloguj ponownie
3. Sprawdź w kodzie czy pole `rola` jest poprawnie odczytywane

### Problem 3: Reguły nie działają

**Rozwiązanie:**
1. Firebase Console → Firestore Database → Rules
2. Sprawdź czy data wygaśnięcia reguł NIE jest w przeszłości
3. Kliknij "Publish" ponownie

---

## ✅ Checklist - Co zrobić?

Zaznacz po wykonaniu:

- [ ] **Krok 1:** Wdrożono reguły Firestore przez Firebase Console
- [ ] **Krok 2:** Zmigrowano istniejących użytkowników (zmieniono role)
- [ ] **Krok 3:** Utworzono pierwszego Administratora w aplikacji
- [ ] **Krok 4:** Zalogowano się jako Administrator i zweryfikowano panel
- [ ] **Krok 5:** Przetestowano uprawnienia dla wszystkich ról
- [ ] **Opcjonalne:** Poinformowano użytkowników o zmianach

---

## 🎯 Podsumowanie zmian

### Co się zmieniło:

| Przed | Po | Uprawnienia |
|-------|-----|-------------|
| Naczelnik | **Administrator** | Pełne uprawnienia |
| Dowódca | **Moderator** | Edycja wyjazdów, strażaków, samochodów, kalendarza |
| Kierowca | **Strażak** | Tylko podgląd |
| Strażak | **Strażak** | Tylko podgląd |

### Nowe możliwości:

- ✅ Jasny podział uprawnień
- ✅ Bezpieczniejsze reguły Firebase
- ✅ Moderatorzy mogą zarządzać większością danych
- ✅ Strażacy mają tylko podgląd (nie mogą przypadkowo niczego zmienić)

---

## 📞 Potrzebujesz pomocy?

Jeśli coś nie działa:

1. **Sprawdź logi Firebase:**
   - Firebase Console → Firestore Database → Usage
   - Sprawdź czy są błędy uprawnień

2. **Sprawdź dane w Firestore:**
   - Firebase Console → Firestore Database
   - Sprawdź kolekcję `strazacy` → pole `rola`

3. **Sprawdź reguły:**
   - Firebase Console → Firestore Database → Rules
   - Upewnij się że są opublikowane

**Powodzenia! 🚀**
