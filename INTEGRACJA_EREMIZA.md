# Integracja z eRemiza - Instrukcja

## 🚀 Deployment Cloud Functions

### 1. Instalacja zależności
```powershell
cd functions
npm install
```

### 2. Login do Firebase
```powershell
firebase login
```

### 3. Deploy funkcji
```powershell
firebase deploy --only functions
```

Po deployment otrzymasz URL-e:
```
✔ functions[synchronizujAlarmZeRemiza(europe-central2)]
  https://europe-central2-[PROJEKT_ID].cloudfunctions.net/synchronizujAlarmZeRemiza

✔ functions[aktualizujWyjazdZeRemiza(europe-central2)]
  https://europe-central2-[PROJEKT_ID].cloudfunctions.net/aktualizujWyjazdZeRemiza

✔ functions[testConnection(europe-central2)]
  https://europe-central2-[PROJEKT_ID].cloudfunctions.net/testConnection
```

## 🔐 Konfiguracja w eRemiza

### Dane dla administratora eRemiza:

**Webhook URL do dodawania nowych alarmów:**
```
https://europe-central2-[TWOJ_PROJEKT_ID].cloudfunctions.net/synchronizujAlarmZeRemiza
```

**Webhook URL do aktualizacji zakończonych wyjazdów:**
```
https://europe-central2-[TWOJ_PROJEKT_ID].cloudfunctions.net/aktualizujWyjazdZeRemiza
```

**Metoda:** POST

**Nagłówki:**
- Content-Type: `application/json`
- Authorization: `Bearer OSP_KOLUMNA_SECRET_2026`

⚠️ **WAŻNE:** Zmień klucz `OSP_KOLUMNA_SECRET_2026` w pliku `functions/index.js` na własny tajny klucz!

### Format danych - Nowy alarm:
```json
{
  "id": "ER-2026-001234",
  "tytul": "Pożar budynku mieszkalnego",
  "opis": "Dym z okna na pierwszym piętrze",
  "adres": "ul. Główna 15, Kolumna",
  "typ": "pozar",
  "data": "2026-01-28T14:30:00Z",
  "priorytet": "wysoki",
  "liczbaStrazakow": 12
}
```

### Format danych - Aktualizacja wyjazdu:
```json
{
  "id": "ER-2026-001234",
  "status": "zakończony",
  "czasTrwania": 2.5,
  "liczbaStrazakow": 12,
  "uwagi": "Akcja zakończona sukcesem"
}
```

## 🧪 Testowanie

### Test 1: Sprawdź czy funkcje działają
```powershell
curl https://europe-central2-[PROJEKT_ID].cloudfunctions.net/testConnection
```

Odpowiedź:
```json
{
  "success": true,
  "message": "OSP Kolumna Cloud Functions działają!",
  "timestamp": "2026-01-28T14:30:00.000Z"
}
```

### Test 2: Dodaj testowy wyjazd
```powershell
curl -X POST https://europe-central2-[PROJEKT_ID].cloudfunctions.net/synchronizujAlarmZeRemiza `
  -H "Content-Type: application/json" `
  -H "Authorization: Bearer OSP_KOLUMNA_SECRET_2026" `
  -d '{
    "id": "TEST-001",
    "tytul": "Test synchronizacji z eRemiza",
    "adres": "Kolumna, ul. Testowa 1",
    "typ": "pozar",
    "data": "2026-01-28T15:00:00Z"
  }'
```

Odpowiedź:
```json
{
  "success": true,
  "wyjazdId": "abc123def456",
  "message": "Wyjazd pomyślnie dodany"
}
```

### Test 3: Zaktualizuj wyjazd
```powershell
curl -X POST https://europe-central2-[PROJEKT_ID].cloudfunctions.net/aktualizujWyjazdZeRemiza `
  -H "Content-Type: application/json" `
  -H "Authorization: Bearer OSP_KOLUMNA_SECRET_2026" `
  -d '{
    "id": "TEST-001",
    "status": "zakończony",
    "czasTrwania": 1.5,
    "liczbaStrazakow": 8
  }'
```

## 📱 Jak to działa w aplikacji

1. **eRemiza** otrzymuje nowy alarm
2. **eRemiza** wysyła POST do Cloud Function
3. **Cloud Function** dodaje wyjazd do Firestore
4. **StreamBuilder** w aplikacji automatycznie wykrywa zmiany
5. **Lista wyjazdów** odświeża się natychmiast (bez refresh!)

## 🔍 Monitorowanie

### Logi w czasie rzeczywistym:
```powershell
firebase functions:log --only synchronizujAlarmZeRemiza
```

### Logi w Firebase Console:
https://console.firebase.google.com/project/[PROJEKT_ID]/functions/logs

## ❓ Troubleshooting

### Problem: "Unauthorized"
- Sprawdź czy nagłówek Authorization jest poprawny
- Upewnij się że używasz tego samego klucza co w `index.js`

### Problem: "Wyjazd nie dodaje się"
- Sprawdź logi: `firebase functions:log`
- Sprawdź czy format JSON jest poprawny
- Zweryfikuj czy pole `tytul` lub `nazwa` jest wypełnione

### Problem: Duplikaty wyjazdów
- Upewnij się że eRemiza wysyła unikalne `id`
- Funkcja automatycznie sprawdza `eRemizaId` przed dodaniem

## 🔒 Bezpieczeństwo

1. **Zmień tajny klucz** w `index.js` na silny, losowy ciąg znaków
2. **Nie commituj** tajnego klucza do repozytorium Git
3. Rozważ użycie **Firebase Secret Manager**:
   ```powershell
   firebase functions:secrets:set EREMIZA_SECRET
   ```

## 📞 Kontakt z eRemiza

Zapytaj administratora eRemiza o:
- [ ] Czy obsługują webhooks?
- [ ] Jaki format danych wysyłają?
- [ ] Czy mogą dodać nagłówek Authorization?
- [ ] Czy wysyłają aktualizacje zakończonych wyjazdów?
- [ ] Dokumentacja API (jeśli dostępna)
