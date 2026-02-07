# Firebase - Instrukcja konfiguracji logowania

## Problem: Użytkownik nie może się zalogować

### Możliwe przyczyny i rozwiązania:

## 1. Konto nieaktywne (najczęstszy problem)

**Symptomy:** "Twoje konto zostało dezaktywowane"

**Rozwiązanie:**
1. Przejdź do Firebase Console: https://console.firebase.google.com/
2. Wybierz projekt "osp-kolumna-app"
3. Kliknij **Firestore Database** w menu
4. Otwórz kolekcję **strazacy**
5. Znajdź użytkownika (po emailu)
6. Edytuj dokument
7. Zmień pole **aktywny** na `true`
8. Kliknij **Update**

## 2. Użytkownik nie istnieje w Firestore

**Symptomy:** Logowanie działa, ale aplikacja wyrzuca błąd

**Rozwiązanie:**
1. Sprawdź czy użytkownik istnieje w **Authentication**:
   - Firebase Console → Authentication → Users
   - Skopiuj **User UID**

2. Dodaj użytkownika do **Firestore**:
   - Firestore Database → strazacy → Add document
   - **Document ID**: wklej skopiowany User UID
   - Dodaj pola:
   ```
   imie: "Jan"
   nazwisko: "Kowalski"  
   email: "jan@example.com"
   numerTelefonu: "123456789"
   role: ["strazak"]  // tablica!
   aktywny: true
   dataRejestracji: "2026-01-30T10:00:00Z"
   dostepny: false
   ```

## 3. Niewłaściwe reguły Firestore

**Symptomy:** "Missing or insufficient permissions"

**Rozwiązanie:**
1. Firebase Console → Firestore Database → Rules
2. Wklej reguły z pliku `firestore.rules`:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Funkcja sprawdzająca czy użytkownik jest zalogowany
    function isSignedIn() {
      return request.auth != null;
    }
    
    // Funkcja sprawdzająca czy użytkownik jest aktywny
    function isActive() {
      return isSignedIn() && 
             get(/databases/$(database)/documents/strazacy/$(request.auth.uid)).data.aktywny == true;
    }
    
    // Kolekcja strażaków - wszyscy mogą czytać aktywnych
    match /strazacy/{strazakId} {
      allow read: if isActive();
      allow create: if isSignedIn(); // Nowi użytkownicy mogą się zarejestrować
      allow update, delete: if isActive();
    }
    
    // Wyjazdy
    match /wyjazdy/{wyjazdId} {
      allow read: if isActive();
      allow create, update, delete: if isActive();
    }
    
    // Wydarzenia (terminarz)
    match /wydarzenia/{wydarzenieId} {
      allow read: if isActive();
      allow create, update, delete: if isActive();
    }
    
    // Pozostałe kolekcje - dostęp dla zalogowanych i aktywnych
    match /{document=**} {
      allow read, write: if isActive();
    }
  }
}
```

3. Kliknij **Publish**

## 4. Problem z hasłem

**Rozwiązanie - Reset hasła:**
1. Firebase Console → Authentication → Users
2. Znajdź użytkownika
3. Kliknij menu **⋮** (trzy kropki)
4. Wybierz **Reset password**
5. Firebase wyśle email z linkiem do zmiany hasła

**LUB ustaw hasło ręcznie:**
1. Kliknij użytkownika
2. Przewiń do **Password**
3. Kliknij **Set password**
4. Wpisz nowe hasło (min. 6 znaków)
5. Zapisz

## 5. Diagnostyka problemów z logowaniem

### W aplikacji - Ekran debugowania:
1. Na ekranie logowania kliknij: **"🔍 Nie możesz się zalogować? Sprawdź konto"**
2. Wpisz email użytkownika
3. Zobacz szczegółową diagnozę:
   - Czy konto istnieje w Authentication
   - Czy dokument istnieje w Firestore
   - Czy pole `aktywny: true`
   - Szczegółowe błędy i rozwiązania

⚠️ **NAJCZĘSTSZY PROBLEM**: Nowi użytkownicy mają `aktywny: false` i wymagają zatwierdzenia przez administratora.

## 6. Sprawdzenie logów błędów

W aplikacji mobilnej:
1. Spróbuj się zalogować
2. Jeśli pojawi się błąd, zapisz dokładny komunikat
3. Sprawdź w Firebase Console → Authentication → Users czy użytkownik się pojawił

## 7. Problem z email verification

Jeśli w ustawieniach włączona jest weryfikacja email:

1. Firebase Console → Authentication → Settings
2. Znajdź **Email verification**
3. Wyłącz **Require email verification** (jeśli chcesz)

## 8. Tworzenie nowego użytkownika

### Przez Firebase Console:
1. **Authentication → Users → Add user**
2. Podaj email i hasło
3. Skopiuj wygenerowany **User UID**
4. **Firestore Database → strazacy → Add document**
5. Document ID = User UID
6. Dodaj wszystkie wymagane pola (patrz punkt 2)

### Przez aplikację:
1. Otwórz aplikację
2. Ekran logowania → **Zarejestruj się**
3. Wypełnij formularz
4. **WAŻNE**: Administrator musi zatwierdzić konto:
   - Zaloguj się jako admin
   - Menu → **Zatwierdzanie użytkowników**
   - Zatwierdź nowe konto

## 9. Eksport/Import użytkowników

Jeśli masz listę użytkowników w pliku `SZABLON_UZYTKOWNIKOW.txt`:

1. Użyj skryptu `import_users.js`:
```bash
cd functions
node import_users.js
```

2. LUB importuj ręcznie przez Firebase Console

## 10. Kontakt

Jeśli problem nadal występuje:
- Użyj ekranu debugowania w aplikacji: "🔍 Nie możesz się zalogować? Sprawdź konto"
- Sprawdź logi w Firebase Console
- Sprawdź czy wszystkie usługi Firebase są włączone
- Zrestartuj aplikację mobilną

**Administrator systemu OSP Kolumna**  
💡 Więcej informacji: DIAGNOZA_LOGOWANIA.md
