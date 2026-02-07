# Instrukcja: Automatyczne tworzenie konta Administrator w Firebase Authentication

## Krok 1: Pobierz klucz Service Account

1. Przejdź do: https://console.firebase.google.com/project/osp-kolumna/settings/serviceaccounts/adminsdk
2. Kliknij przycisk **"Wygeneruj nowy klucz prywatny"**
3. Pobierze się plik JSON (np. `osp-kolumna-firebase-adminsdk-xxxxx.json`)
4. Zmień nazwę tego pliku na: **serviceAccountKey.json**
5. Przenieś go do folderu projektu: `C:\Users\User\Desktop\Projekt\flutter_projekt_polski\`

## Krok 2: Zainstaluj zależności

Otwórz terminal w folderze projektu i wykonaj:

```powershell
npm install firebase-admin
```

## Krok 3: Uruchom skrypt

```powershell
node create_admin_auth.js
```

## Co zrobi skrypt?

✅ Automatycznie utworzy konto Authentication dla: **korczes9@gmail.com**
✅ Ustawi hasło tymczasowe: **Admin123!** (zmień je po zalogowaniu!)
✅ Pokaże UID nowego użytkownika

## Krok 4: Zaktualizuj Firestore (WAŻNE!)

Po uruchomieniu skryptu:

1. Skopiuj **UID** wyświetlony w terminalu
2. Przejdź do Firestore Console: https://console.firebase.google.com/project/osp-kolumna/firestore/data
3. Znajdź kolekcję **strazacy**
4. **USUŃ** stary dokument dla korczes9@gmail.com
5. **UTWÓRZ NOWY** dokument z ID = skopiowany UID
6. Dodaj pola:
   ```
   email: "korczes9@gmail.com"
   role: ["administrator"]  ← MUSI BYĆ TABLICA!
   aktywny: true
   imie: "Admin"
   nazwisko: "(twoje nazwisko)"
   ```

## Krok 5: Wdróż reguły Firestore

1. Przejdź do: https://console.firebase.google.com/project/osp-kolumna/firestore/rules
2. Skopiuj zawartość pliku `firestore.rules` z projektu
3. Wklej do edytora w Firebase Console
4. Kliknij **"Publikuj"**

## Gotowe!

Teraz możesz się zalogować w aplikacji:
- **Email:** korczes9@gmail.com
- **Hasło:** Admin123!

⚠️ **ZMIEŃ HASŁO** po pierwszym zalogowaniu!

---

## Troubleshooting

**Błąd: "email-already-exists"**
- Użytkownik już istnieje! Skrypt automatycznie pokaże jego UID
- Użyj tego UID do aktualizacji dokumentu Firestore

**Błąd: "Permission denied"**
- Upewnij się, że serviceAccountKey.json ma prawidłowe uprawnienia
- Sprawdź czy klucz jest z właściwego projektu Firebase
