# 🔧 Rozwiązywanie Błędu 400 - eRemiza API

## ❌ Błąd: "eRemiza API error 400"

**Kod 400** = Bad Request - serwer odrzucił zapytanie z powodu nieprawidłowego formatu.

---

## 🔍 Możliwe Przyczyny

### 1. **Nieprawidłowy Format JWT** (najbardziej prawdopodobne)
eRemiza wymaga specyficznego formatu JWT z algorithm: "none"

**Naprawione w kodzie:**
- ✅ Używamy base64url zamiast base64
- ✅ Usuwamy padding (=)
- ✅ Zamieniamy znaki (+→-, /→_)

### 2. **Brakujące lub Nieprawidłowe Parametry**
Endpoint `/Alarm/GetAlarmList` wymaga:
- `ouId` - ID jednostki (obowiązkowe)
- `count` - liczba alarmów (obowiązkowe)
- `offset` - przesunięcie (obowiązkowe)

### 3. **Nieaktywne Konto eRemiza**
Konto może być:
- Nieaktywowane przez administratora
- Zablokowane
- Bez przypisanej jednostki OSP

### 4. **Nieprawidłowe Nagłówki HTTP**
eRemiza może wymagać specyficznych nagłówków.

---

## 🛠️ Kroki Diagnostyczne

### KROK 1: Sprawdź Logi w Aplikacji

Po uruchomieniu synchronizacji sprawdź w logach (konsola/terminal):

```
🔐 Próba logowania do eRemiza...
📧 Email: seb***
📡 eRemiza response: 400
❌ BAD REQUEST 400
📄 Response body: [sprawdź co tu jest]
```

**Co szukać w "Response body":**
- `"Invalid token"` → Problem z JWT
- `"Missing parameter"` → Brakuje parametru
- `"Unauthorized"` → Problem z kontem
- `"Invalid credentials"` → Złe hasło/email

---

### KROK 2: Zweryfikuj Dane Logowania

1. Otwórz https://e-remiza.pl/ w przeglądarce
2. Zaloguj się tym samym emailem i hasłem
3. Sprawdź czy widzisz alarmy w systemie
4. Sprawdź czy Twoje konto ma przypisaną jednostkę OSP

**Jeśli nie możesz się zalogować na stronie** → Hasło jest nieprawidłowe

---

### KROK 3: Test z Prostym JWT

Możemy przetestować czy JWT jest prawidłowy:

**Obecny format JWT:**
```
eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJlbWFpbCI6InRlc3RAZW1haWwucGwiLCJwYXNzd29yZCI6InRlc3QxMjMiLCJpYXQiOjE3MzgwMDAwMDB9.
```

Składa się z:
- Header: `{"alg":"none","typ":"JWT"}`
- Payload: `{"email":"test@email.pl","password":"test123","iat":1738000000}`
- Signature: (pusta)

---

## ✅ ROZWIĄZANIA

### Rozwiązanie A: Zaktualizuj Kod (JUŻ ZROBIONE)

Kod został naprawiony z następującymi zmianami:
1. ✅ Poprawny base64url encoding
2. ✅ Szczegółowe logi błędów 400
3. ✅ Walidacja parametrów przed wysłaniem
4. ✅ Lepsze komunikaty o błędach

**Przetestuj ponownie:**
1. Restart aplikacji: `flutter run -d chrome`
2. Menu → Konfiguracja eRemiza
3. Wprowadź dane i kliknij "Testuj Połączenie"

---

### Rozwiązanie B: Sprawdź Odpowiedź 400

**W logach znajdź:**
```
📄 Response body: {...}
```

**Prześlij mi tę odpowiedź** - na jej podstawie będę mógł dokładnie określić problem.

**Przykładowe odpowiedzi:**

#### Problem 1: Nieprawidłowy JWT
```json
{
  "error": "Invalid token format",
  "message": "JWT validation failed"
}
```
**Rozwiązanie:** Sprawdź czy email/hasło są poprawne

#### Problem 2: Brak dostępu
```json
{
  "error": "Access denied",
  "message": "User not authorized for this resource"
}
```
**Rozwiązanie:** Konto nie ma uprawnień - skontaktuj się z administratorem eRemiza

#### Problem 3: Brak jednostki
```json
{
  "error": "Missing organization",
  "message": "User not assigned to any OSP unit"
}
```
**Rozwiązanie:** W panelu eRemiza przypisz konto do jednostki OSP Kolumna

---

### Rozwiązanie C: Alternatywny Endpoint

Możliwe że endpoint `/User/GetUser` działa, ale `/Alarm/GetAlarmList` nie.

**Test:**
1. Jeśli "Testuj Połączenie" działa ✅
2. Ale "Synchronizuj Alarmy" daje 400 ❌

To problem z dostępem do alarmów.

**Sprawdź w eRemiza:**
- Czy Twoje konto ma uprawnienia do przeglądania alarmów?
- Czy jednostka OSP Kolumna ma przypisany `bsisOuId`?

---

## 🧪 Test Debugowy

Dodaj to tymczasowo do `ekran_konfiguracji_eremiza.dart`:

```dart
// Po kliknięciu "Testuj Połączenie"
Future<void> _testConnection() async {
  // ... istniejący kod ...
  
  // DODAJ TO:
  try {
    final user = await _eremizaService.login();
    print('👤 Dane użytkownika:');
    print(user);  // Wyświetl WSZYSTKIE dane
    
    // Sprawdź czy jest bsisOuId
    if (user['bsisOuId'] == null) {
      throw Exception('Brak bsisOuId - skontaktuj się z adminem eRemiza');
    }
  } catch (e) {
    print('DEBUG ERROR: $e');
  }
}
```

To pokaże dokładnie jakie dane zwraca eRemiza.

---

## 📋 Checklist Diagnozy

- [ ] Sprawdź czy możesz zalogować się na https://e-remiza.pl/
- [ ] Sprawdź logi aplikacji (Response body przy błędzie 400)
- [ ] Zweryfikuj email i hasło (wielkość liter!)
- [ ] Sprawdź czy konto ma przypisaną jednostkę OSP
- [ ] Sprawdź uprawnienia konta w panelu eRemiza
- [ ] Przetestuj "Testuj Połączenie" - czy działa?
- [ ] Przetestuj "Synchronizuj Alarmy" - czy to tutaj błąd 400?

---

## 🆘 Co zrobić teraz?

**1. Uruchom aplikację i spróbuj ponownie**
```bash
flutter run -d chrome
```

**2. Kliknij "Testuj Połączenie"**

**3. Skopiuj logi z konsoli** (szczególnie część z błędem 400)

**4. Prześlij mi:**
- Czy "Testuj Połączenie" działa?
- Jaki dokładnie jest komunikat błędu 400?
- Co jest w "Response body"?

**Lub jeśli wolisz:**
- Wyłącz eRemiza (Menu → Konfiguracja → Wyloguj)
- Używaj aplikacji bez eRemiza (wyjazdy można dodawać ręcznie)

---

**Status:** Kod naprawiony, czekam na szczegóły błędu 400 aby dokładnie zdiagnozować. 🔍
