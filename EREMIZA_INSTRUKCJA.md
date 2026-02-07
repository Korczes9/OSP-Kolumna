# ✅ eRemiza - Przewodnik Szybkiego Startu

## 🎯 Co to jest?

**eRemiza** to system zarządzania alarmami dla straży pożarnych w Polsce.  
**OSP Kolumna** może synchronizować alarmy automatycznie z eRemiza do aplikacji.

---

## 🚀 Jak to uruchomić (3 proste kroki)

### KROK 1: Otwórz Konfigurację eRemiza

1. Uruchom aplikację OSP Kolumna
2. Kliknij **Menu** (≡) w prawym górnym rogu
3. Wybierz **"Konfiguracja eRemiza"**

---

### KROK 2: Wprowadź Dane Logowania

**Potrzebujesz:**
- Email do konta eRemiza
- Hasło do konta eRemiza

**W formularzu wypełnij:**
1. **Email:** Twój email z systemu eRemiza
2. **Hasło:** Twoje hasło z systemu eRemiza
3. Kliknij **"Testuj Połączenie"**

**Oczekiwany wynik:**
```
✅ Połączenie z eRemiza OK!
```

**Jeśli błąd:**
- Sprawdź email i hasło (literówki?)
- Sprawdź połączenie internetowe
- Upewnij się że konto eRemiza jest aktywne

---

### KROK 3: Synchronizuj Alarmy

1. Kliknij przycisk **"Synchronizuj Alarmy"**
2. Poczekaj 5-10 sekund
3. Zobaczysz wynik:

```
✅ Synchronizacja zakończona!
Dodano: 3, Pominięto: 17
```

**Co się stało:**
- Aplikacja pobrała ostatnie 20 alarmów z eRemiza
- Automatycznie odfiltrowano tylko alarmy **SK KP** (Stały Komisariat Powiatowy)
- Pominięto duplikaty (które już są w bazie)
- Dodano 3 nowe wyjazdy do aplikacji

---

## 📊 Jak często synchronizować?

**Zalecenia:**

### Opcja A: Manualna (zalecana)
- Synchronizuj **raz dziennie** rano (np. o 8:00)
- Lub **po otrzymaniu informacji** o nowym alarmie
- **Czas:** 30 sekund

### Opcja B: Automatyczna (opcjonalna)
- Włącz przełącznik **"Auto-sync (co 5 min)"**
- System automatycznie synchronizuje co 5 minut
- ⚠️ **Uwaga:** Zużywa więcej baterii i internetu

---

## 🔍 Co jest synchronizowane?

### Automatycznie pobierane dane:

| Z eRemiza | Do OSP Kolumna |
|-----------|----------------|
| ID alarmu | eRemizaId |
| Opis zdarzenia | Opis wyjazdu |
| Adres | Lokalizacja |
| Kategoria (P, MZ, Ć) | Kategoria wyjazdu |
| Data i godzina | Data wyjazdu |
| Współrzędne GPS | Mapa (jeśli dostępne) |
| Liczba strażaków | Metadane |

### Filtrowanie:

✅ **Synchronizowane:** Tylko alarmy z **SK KP**  
❌ **Pomijane:** Alarmy spoza SK KP, duplikaty

---

## 📋 Mapowanie Kategorii

| eRemiza | OSP Kolumna | Opis |
|---------|-------------|------|
| **P** | Pożar | Pożary budynków, lasów, etc. |
| **Alarm (MZ)** | Miejscowe zagrożenie | Wypadki, zalania, etc. |
| **Ć** lub **C** | Ćwiczenia | Ćwiczenia strażackie |
| **PNZR** | Zabezpieczenie rejonu | Zabezpieczenie JRG Łask |

---

## ✅ Sprawdź Czy Działa

### Test 1: W aplikacji OSP
1. Przejdź do **Wyjazdy** (zakładka)
2. Filtruj po źródle: **"eRemiza API"**
3. Powinieneś zobaczyć zsynchronizowane alarmy

### Test 2: W Firestore (dla admina)
1. Otwórz Firebase Console
2. Firestore Database → Kolekcja **"wyjazdy"**
3. Znajdź dokumenty z polem **eRemizaId**

---

## 🛠️ Rozwiązywanie Problemów

### Problem 1: "Błędne dane logowania"

**Rozwiązanie:**
- Sprawdź email i hasło (wielkość liter!)
- Zaloguj się na https://e-remiza.pl/ aby potwierdzić dane
- Upewnij się że konto NIE jest zablokowane

---

### Problem 2: "Timeout - eRemiza nie odpowiada"

**Rozwiązanie:**
- Sprawdź połączenie internetowe
- eRemiza może być czasowo niedostępna - spróbuj za 5 minut
- Sprawdź czy https://e-remiza.pl/ działa w przeglądarce

---

### Problem 3: "Dodano: 0, Pominięto: 20"

**Dlaczego?**
- Wszystkie alarmy już są w bazie (duplikaty)
- LUB: Żaden alarm nie jest z SK KP

**Rozwiązanie:**
- To normalne! Oznacza że wszystko jest aktualne
- Synchronizuj ponownie gdy pojawi się nowy alarm

---

### Problem 4: "Brak połączenia z internetem"

**Rozwiązanie:**
- Sprawdź WiFi lub dane mobilne
- Sprawdź czy inne aplikacje działają
- Zrestartuj aplikację

---

## 📝 Wyłączenie eRemiza

Jeśli nie chcesz używać eRemiza:

1. Menu → Konfiguracja eRemiza
2. Kliknij **"Wyloguj"**
3. Potwierdź

Auto-sync zostanie wyłączony.

---

## 💡 Najlepsze Praktyki

### ✅ Zalecane:
- Synchronizuj raz dziennie rano
- Sprawdzaj status synchronizacji w aplikacji
- Używaj manualnej synchronizacji (oszczędza baterię)

### ❌ Odradzane:
- Auto-sync na słabym internecie
- Synchronizacja co minutę (niepotrzebne)

---

## 📞 Pomoc Techniczna

**Problem nie rozwiązany?**

1. Sprawdź logi w aplikacji (jeśli dostępne)
2. Zrób screenshot błędu
3. Skontaktuj się z administratorem aplikacji

**Dane kontaktowe:**
- Email: korczes9@gmail.com
- Administrator: Sebastian Grochulski

---

## ✅ Podsumowanie

**eRemiza jest OPCJONALNA** - aplikacja działa również bez niej!

**Jeśli skonfigurowana:**
- ✅ Automatyczne pobieranie alarmów z systemu krajowego
- ✅ Filtrowanie tylko alarmów SK KP
- ✅ Bez duplikatów
- ✅ Synchronizacja w 30 sekund

**Status:** Integracja naprawiona i gotowa do użycia! 🚀
