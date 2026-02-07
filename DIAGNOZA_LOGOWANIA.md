# 🔍 Diagnoza problemu z logowaniem

## Problem
Użytkownik wpisuje poprawny email i hasło, ale **nic się nie dzieje**.

## Możliwe przyczyny

### 1. ❌ Konto nieaktywne (aktywny: false)
**Jak sprawdzić:**
1. Firebase Console → Firestore Database
2. Kolekcja `strazacy`
3. Znajdź dokument użytkownika
4. Sprawdź pole `aktywny`

**Rozwiązanie:**
```
aktywny: true
```

### 2. ❌ Brak dokumentu w Firestore
**Jak sprawdzić:**
1. Firebase Console → Authentication → Users
2. Skopiuj UID użytkownika
3. Firestore Database → strazacy
4. Czy istnieje dokument o tym UID?

**Rozwiązanie:**
- Jeśli brak: Utwórz dokument manualnie (patrz FIREBASE_INSTRUKCJA_LOGOWANIA.md)
- Lub: Usuń konto z Authentication i zarejestruj ponownie

### 3. ❌ Błędne hasło / email
**Jak sprawdzić:**
1. Użyj ekranu debugowania w aplikacji:
   - Kliknij: "🔍 Nie możesz się zalogować? Sprawdź konto"
   - Wpisz email użytkownika
   - Sprawdź czy konto istnieje i jest aktywne
2. Jeśli konto istnieje i jest aktywne → problem z hasłem

**Rozwiązanie:**
- Użyj funkcji "Zapomniałeś hasła?" w aplikacji
- Lub zresetuj hasło w Firebase Console → Authentication

### 4. ❌ Błędne reguły Firestore
**Jak sprawdzić:**
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /strazacy/{userId} {
      // Strażak może odczytać swoje dane po zalogowaniu
      allow read: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

**Rozwiązanie:**
Sprawdź plik `firestore.rules` i wdróż go:
```powershell
firebase deploy --only firestore:rules
```

### 5. ❌ Problem z połączeniem internetowym
**Jak sprawdzić:**
- Czy urządzenie ma połączenie z internetem?
- Czy Firebase Console działa w przeglądarce?

**Rozwiązanie:**
- Sprawdź połączenie
- Zrestartuj aplikację

### 6. ❌ Problem z cache
**Jak sprawdzić:**
1. Odinstaluj aplikację
2. Zainstaluj ponownie APK
3. Spróbuj zalogować się ponownie

**Rozwiązanie:**
```powershell
# Usuń cache Flutter
flutter clean
flutter pub get
flutter build apk --release
```

## 🧪 Test krok po kroku

### Krok 1: Sprawdź Firebase Console
- [ ] Firebase Authentication: Czy konto istnieje?
- [ ] Firestore: Czy dokument w `strazacy` istnieje?
- [ ] Firestore: Czy pole `aktywny` = true?

### Krok 2: Test ekranu debugowania
- [ ] Na ekranie logowania kliknij: "🔍 Nie możesz się zalogować? Sprawdź konto"
- [ ] Wpisz email użytkownika, który ma problem
- [ ] Sprawdź wyniki diagnozy

### Krok 3: Sprawdź komunikaty błędów
- [ ] Podłącz urządzenie do komputera
- [ ] Uruchom: `flutter logs` lub `adb logcat`
- [ ] Spróbuj zalogować się
- [ ] Jakie błędy się pojawiają?

### Krok 4: Debugging
**W kodzie ekran_logowania_nowy.dart (linia 43-65)** aplikacja wyświetla:
- ✅ Szczegółowy komunikat błędu (linia 61)
- ✅ Sprawdza czy konto istnieje
- ✅ Sprawdza czy konto aktywne

**Jeśli nie widzisz komunikatu błędu:**
- Aplikacja się zawiesza podczas ładowania
- Problem z połączeniem Firebase
- Problem z build APK (stary cache)

## 📋 Checklist dla administratora

Aby użytkownik mógł się zalogować:

1. ✅ **Firebase Authentication**
   - Konto istnieje
   - Email zweryfikowany (opcjonalnie)

2. ✅ **Firestore Database → strazacy**
   - Dokument istnieje (ID = UID z Authentication)
   - Pole `aktywny`: true
   - Pole `email`: zgodne z Authentication
   - Pole `role`: lista ról np. ["Strażak"]

3. ✅ **Firestore Rules**
   - Użytkownik może odczytać swoje dane
   - Reguły wdrożone (nie w trybie test)

4. ✅ **Aplikacja**
   - Najnowsza wersja APK
   - Połączenie internetowe działa

## 🆘 Szybkie rozwiązanie

**Jeśli użytkownik nie może się zalogować:**

1. **Firebase Console → Firestore → strazacy**
2. Znajdź dokument użytkownika (po email)
3. Edytuj dokument:
   ```
   aktywny: true
   ```
4. Zapisz
5. Użytkownik próbuje ponownie

**Jeśli nadal nie działa:**
1. Firebase Console → Authentication
2. Znajdź użytkownika
3. Delete user
4. W aplikacji: **Zarejestruj się** ponownie
5. Administrator zatwierdza konto w: **Zarządzanie strażakami**

## 🔧 Kontakt z wsparciem

Jeśli problem nadal występuje, wyślij:
- [ ] Screenshot ekranu logowania
- [ ] Email użytkownika
- [ ] Screenshot dokumentu Firestore (strazacy/UID)
- [ ] Logi z `flutter logs` lub `adb logcat`

---

**Ostatnia aktualizacja:** 2024
**Wersja aplikacji:** 1.0.0
