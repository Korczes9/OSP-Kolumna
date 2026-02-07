# 🔧 Diagnoza i Naprawa Integracji eRemiza

## ❌ **Zdiagnozowane Problemy:**

### 1. **Problem z JWT Token**
Obecny kod używa standardowego base64, ale eRemiza wymaga **base64url** (bez paddingu).

### 2. **Niepoprawna autoryzacja**
eRemiza może wymagać innego formatu tokenu lub nagłówków.

### 3. **Auto-sync może nie działać**
Timer może być zatrzymywany przez system lub nie ma odpowiednich uprawnień.

### 4. **Brak obsługi błędów sieciowych**
Timeout, retry logic nie są zaimplementowane.

---

## ✅ **ROZWIĄZANIE - 3 Opcje**

### **OPCJA A: Uproszczona Integracja (Zalecana dla OSP)**

**Rezygnujemy z automatycznej synchronizacji** i używamy **manualnej synchronizacji** z aplikacji.

**Dlaczego?**
- ✅ Prostsze w konfiguracji
- ✅ Nie wymaga Cloud Functions
- ✅ Działa na planie Spark (darmowy)
- ✅ Pełna kontrola nad synchronizacją
- ⏱️ Wymaga ręcznego kliknięcia "Synchronizuj" (30 sekund)

**Status:** KOD JUŻ GOTOWY - trzeba tylko naprawić JWT

---

### **OPCJA B: Webhook z eRemiza**

eRemiza **wysyła powiadomienie** do Twojego systemu gdy pojawi się nowy alarm.

**Wymaga:**
- Plan Blaze w Firebase (Cloud Functions)
- Konfiguracja webhook w panelu eRemiza
- Dostęp do panelu administracyjnego eRemiza

**Plusy:**
- Natychmiastowa synchronizacja (< 5 sekund)
- Automatyczne powiadomienia push do strażaków

**Minusy:**
- Wymaga upgrade Firebase
- Wymaga konfiguracji w eRemiza przez administratora systemu

---

### **OPCJA C: Pełna Rezygnacja z eRemiza**

Ręczne dodawanie wyjazdów w aplikacji OSP Kolumna.

**Zalety:**
- Najprostsze
- Bez zależności zewnętrznych
- Pełna kontrola

**Wady:**
- Brak automatyzacji

---

## 🚀 **NAPRAWIAMY OPCJĘ A (Manualna synchronizacja)**

### Co naprawię:

1. ✅ Poprawny JWT dla eRemiza
2. ✅ Lepszą obsługę błędów
3. ✅ Wyjaśnienie kroków w UI
4. ✅ Test connection przed synchronizacją
5. ✅ Szczegółowe logi błędów

---

## 📋 **Instrukcja Użycia (po naprawie):**

### Krok 1: Skonfiguruj dane logowania

1. W aplikacji przejdź do **Menu → Konfiguracja eRemiza**
2. Wprowadź:
   - **Email:** Twój email do konta eRemiza
   - **Hasło:** Twoje hasło do eRemiza
3. Kliknij **"Testuj Połączenie"**
4. Jeśli OK → zobaczysz ✅ zielony komunikat

### Krok 2: Ręczna synchronizacja

1. Kliknij przycisk **"Synchronizuj Alarmy"**
2. System pobierze ostatnie 20 alarmów z eRemiza
3. Automatycznie filtruje tylko alarmy **SK KP**
4. Pomija duplikaty (które już są w bazie)
5. Wyświetla wynik: "Dodano: X, Pominięto: Y"

### Krok 3: Synchronizuj regularnie

- Raz dziennie kliknij "Synchronizuj"
- Lub po otrzymaniu informacji o nowym alarmie

---

## ⚙️ **Szczegóły Techniczne (dla developera)**

### Jak działa eRemiza API:

**Endpoint:** `https://e-remiza.pl/Terminal/Alarm/GetAlarmList`

**Autoryzacja:** JWT token w nagłówku `JWT`

**Wymagany JWT:**
```
Header: {"alg":"none","typ":"JWT"}
Payload: {"email":"user@example.com","password":"haslo123","iat":1234567890}
Signature: (brak - algorithm: none)
```

**Format:** `base64url(header).base64url(payload).`

### Filtrowanie:

Aplikacja automatycznie filtruje tylko alarmy gdzie:
- `bsisName` zawiera "SK KP" lub "SK_KP" lub "SKKP"

### Mapowanie kategorii:

| eRemiza subKind | OSP Kategoria |
|-----------------|---------------|
| P | pozar |
| Alarm (MZ), MZ | miejscoweZagrozenie |
| Ć, C | cwiczenia |
| PNZR | zabezpieczenieRejonu |

---

## 🧪 **Testowanie**

### Test 1: Połączenie
```dart
// W aplikacji: Menu → Konfiguracja eRemiza
// Wprowadź dane i kliknij "Testuj Połączenie"
```

**Oczekiwany wynik:** ✅ "Połączenie z eRemiza OK!"

### Test 2: Synchronizacja
```dart
// Kliknij "Synchronizuj Alarmy"
```

**Oczekiwany wynik:** 
```
✅ Synchronizacja zakończona!
Dodano: 5, Pominięto: 15
```

### Test 3: Sprawdź w Firestore
```
Firebase Console → Firestore → wyjazdy
Filtruj: zrodlo == "eRemiza API"
```

Powinieneś zobaczyć nowe wyjazdy z polem `eRemizaId`.

---

## 📝 **Status Naprawy**

Naprawię teraz:
1. JWT token (base64url zamiast base64)
2. Lepsza obsługa błędów
3. Informacje w UI o statusie

**Czas naprawy: ~5 minut**

---

**Wybierz opcję:**
- **A** - Napraw manualną synchronizację (zalecane)
- **B** - Skonfiguruj webhook (wymaga Blaze)
- **C** - Wyłącz eRemiza całkowicie

Która opcja Cię interesuje?
