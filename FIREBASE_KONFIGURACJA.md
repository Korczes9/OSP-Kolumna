# Konfiguracja Firebase - Nowy System Ról

## 📋 Spis treści
1. [Aktualizacja istniejących danych](#1-aktualizacja-istniejących-danych)
2. [Wdrożenie reguł bezpieczeństwa](#2-wdrożenie-reguł-bezpieczeństwa)
3. [Testowanie konfiguracji](#3-testowanie-konfiguracji)
4. [Migracja użytkowników](#4-migracja-użytkowników)

---

## 1. Aktualizacja istniejących danych

### Mapowanie starych ról na nowe:

| Stara rola | Nowa rola | Poziom uprawnień |
|-----------|-----------|------------------|
| `naczelnik` | `administrator` | Pełne uprawnienia |
| `dowodca` | `moderator` | Edycja wyjazdów, strażaków, samochodów, kalendarza |
| `kierowca` | `strazak` | Tylko podgląd |
| `strazak` | `strazak` | Tylko podgląd |

### Skrypt migracji w Firebase Console:

1. Otwórz **Firebase Console** → Twój projekt
2. Przejdź do **Firestore Database**
3. Kliknij zakładkę **"Rules"** (na razie nie zmieniaj)
4. Otwórz **Cloud Firestore** w widoku danych
5. Wykonaj ręczną aktualizację lub użyj skryptu poniżej

### Automatyczna migracja (Cloud Functions):

Jeśli masz włączone Cloud Functions, możesz użyć tego skryptu:

```javascript
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

async function migrateRoles() {
  const snapshot = await db.collection('strazacy').get();
  
  const roleMapping = {
    'naczelnik': 'administrator',
    'dowodca': 'moderator',
    'kierowca': 'strazak',
    'strazak': 'strazak'
  };
  
  const batch = db.batch();
  let count = 0;
  
  snapshot.forEach(doc => {
    const data = doc.data();
    const oldRole = data.rola;
    const newRole = roleMapping[oldRole] || 'strazak';
    
    if (oldRole !== newRole) {
      batch.update(doc.ref, { rola: newRole });
      count++;
      console.log(`Updating ${doc.id}: ${oldRole} → ${newRole}`);
    }
  });
  
  await batch.commit();
  console.log(`✅ Zaktualizowano ${count} użytkowników`);
}

migrateRoles().catch(console.error);
```

### Ręczna aktualizacja (dla małej liczby użytkowników):

1. Otwórz **Firestore Database** w Firebase Console
2. Przejdź do kolekcji `strazacy`
3. Dla każdego dokumentu:
   - Kliknij na dokument
   - Znajdź pole `rola`
   - Zmień wartość zgodnie z tabelą mapowania powyżej
   - Zapisz zmiany

---

## 2. Wdrożenie reguł bezpieczeństwa

### Krok 1: Wdróż reguły Firestore

W katalogu projektu znajduje się plik `firestore.rules`. Wdróż go:

```bash
# Zainstaluj Firebase CLI (jeśli jeszcze nie masz)
npm install -g firebase-tools

# Zaloguj się do Firebase
firebase login

# Zainicjuj projekt (jeśli jeszcze nie zrobiono)
firebase init firestore

# Wdróż reguły
firebase deploy --only firestore:rules
```

### Krok 2: Zweryfikuj reguły w konsoli

1. Otwórz **Firebase Console** → Twój projekt
2. **Firestore Database** → zakładka **Rules**
3. Sprawdź czy reguły zostały wdrożone
4. Kliknij **Publish** jeśli wdrażałeś ręcznie

### Krok 3: Wdróż indeksy (opcjonalne, ale zalecane)

```bash
firebase deploy --only firestore:indexes
```

---

## 3. Testowanie konfiguracji

### Test 1: Strażak (tylko podgląd)

1. Zaloguj się jako użytkownik z rolą `strazak`
2. Sprawdź czy:
   - ✅ Możesz przeglądać wyjazdy
   - ✅ Możesz przeglądać strażaków
   - ❌ NIE możesz dodawać wyjazdów
   - ❌ NIE możesz edytować danych

### Test 2: Moderator

1. Zaloguj się jako użytkownik z rolą `moderator`
2. Sprawdź czy:
   - ✅ Możesz dodawać wyjazdy
   - ✅ Możesz edytować wyjazdy
   - ✅ Możesz zarządzać strażakami
   - ✅ Możesz edytować samochody
   - ❌ NIE możesz usuwać wyjazdów (tylko Administrator)

### Test 3: Administrator

1. Zaloguj się jako użytkownik z rolą `administrator`
2. Sprawdź czy:
   - ✅ Możesz robić wszystko
   - ✅ Możesz usuwać wyjazdy
   - ✅ Możesz zarządzać raportami
   - ✅ Pełny dostęp do wszystkich funkcji

---

## 4. Migracja użytkowników

### Krok po kroku:

#### 1. Utwórz pierwszego Administratora

```bash
# Uruchom aplikację
flutter run

# Na ekranie logowania kliknij:
# "Pierwsze uruchomienie? Utwórz konto Administratora"

# Domyślne dane:
Email: administrator@ospkolumna.pl
Hasło: admin123
```

#### 2. Zaktualizuj istniejących użytkowników

Po zalogowaniu jako Administrator:

1. Przejdź do **Panel Administratora** → **Zarządzaj strażakami**
2. Dla każdego użytkownika:
   - Kliknij menu (⋮)
   - Edytuj dane
   - Zmień rolę na odpowiednią (Administrator/Moderator/Strażak)
   - Zapisz

#### 3. Usuń stare konto "Naczelnika" (opcjonalnie)

Po utworzeniu nowego Administratora i migracji:

1. W Firebase Console → Authentication
2. Znajdź stare konto z rolą `naczelnik`
3. Usuń je (jeśli już niepotrzebne)

---

## 🔒 Najlepsze praktyki bezpieczeństwa

### 1. Unikaj nadawania roli Administrator wszystkim

- Tylko 1-2 osoby powinny mieć rolę Administrator
- Większość użytkowników powinna być Moderatorami lub Strażakami

### 2. Regularnie sprawdzaj uprawnienia

```bash
# W Firebase Console → Firestore Database
# Wykonaj zapytanie:
db.collection('strazacy').where('rola', '==', 'administrator').get()
```

### 3. Monitoruj aktywność

- Włącz **Firebase Analytics**
- Włącz **Audit Logs** w Google Cloud Console
- Sprawdzaj podejrzane operacje

### 4. Backup danych

```bash
# Eksportuj dane przed migracją
firebase firestore:export gs://twój-projekt-backup/backup-$(date +%Y%m%d)

# Importuj w razie potrzeby
firebase firestore:import gs://twój-projekt-backup/backup-20260128
```

---

## 📊 Struktura danych w Firestore

### Kolekcja `strazacy`

```json
{
  "id": "abc123",
  "imie": "Jan",
  "nazwisko": "Kowalski",
  "email": "jan.kowalski@osp.pl",
  "numerTelefonu": "123456789",
  "rola": "administrator",  // ← NOWA WARTOŚĆ
  "aktywny": true,
  "dataRejestracji": "2026-01-28T10:00:00Z"
}
```

### Możliwe wartości pola `rola`:

- `administrator` - pełne uprawnienia
- `moderator` - edycja wyjazdów, strażaków, samochodów, kalendarza
- `strazak` - tylko podgląd

---

## ❓ Częste problemy i rozwiązania

### Problem 1: "Permission denied" po migracji

**Przyczyna:** Reguły Firebase nie zostały wdrożone

**Rozwiązanie:**
```bash
firebase deploy --only firestore:rules
```

### Problem 2: Użytkownicy nie widzą swoich uprawnień

**Przyczyna:** Aplikacja cache'uje dane

**Rozwiązanie:**
1. Wyloguj się
2. Wyczyść cache aplikacji
3. Zaloguj się ponownie

### Problem 3: Nie można zaktualizować ról w aplikacji

**Przyczyna:** Brak uprawnień Moderatora/Administratora

**Rozwiązanie:**
1. Zaktualizuj role ręcznie w Firebase Console
2. Najpierw utwórz jednego Administratora

---

## 🚀 Wdrożenie na produkcję

### Checklist przed wdrożeniem:

- [ ] Wykonano backup bazy danych
- [ ] Zmigrowano wszystkie role użytkowników
- [ ] Wdrożono reguły Firestore
- [ ] Przetestowano wszystkie poziomy uprawnień
- [ ] Utworzono co najmniej jednego Administratora
- [ ] Zaktualizowano dokumentację dla użytkowników
- [ ] Poinformowano użytkowników o zmianach

### Kolejność wdrożenia:

1. **Backup danych**
2. **Wdróż nową wersję aplikacji** (bez zmiany Firebase)
3. **Migruj role użytkowników** (ręcznie lub skryptem)
4. **Wdróż reguły Firebase**
5. **Testuj na środowisku produkcyjnym**
6. **Monitoruj błędy przez 24-48h**

---

## 📞 Wsparcie

W razie problemów:
1. Sprawdź logi w Firebase Console
2. Sprawdź reguły w zakładce Rules
3. Zweryfikuj uprawnienia użytkownika w Firestore

**Powodzenia z migracją! 🔥**
