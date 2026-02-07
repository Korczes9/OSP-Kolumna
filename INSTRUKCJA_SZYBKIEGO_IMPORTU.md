# 🚀 SZYBKI IMPORT UŻYTKOWNIKÓW DO FIRESTORE

## Metoda 1: Automatyczny import przez konsolę przeglądarki (NAJSZYBSZE - 2 minuty)

### Krok 1: Dodaj użytkowników w Authentication
1. Firebase Console → **Authentication** → **Users**
2. Kliknij **"Add user"** dla każdego z 18 emaili
3. Email: (z listy poniżej) / Hasło: **ospkolumna123**
4. **ZAPISZ User UID** każdego użytkownika (będzie potrzebny!)

### Krok 2: Przygotuj skrypt
1. Otwórz plik: **import_users.js**
2. Dla każdego użytkownika zamień `WKLEJ_USER_UID_X` na prawdziwy UID z Authentication
   - Przykład: `uid: "abc123def456"` zamiast `uid: "WKLEJ_USER_UID_1"`

### Krok 3: Uruchom skrypt w przeglądarce
1. W Firebase Console otwórz **Firestore Database**
2. Naciśnij **F12** (otwórz Developer Tools)
3. Kliknij zakładkę **"Console"**
4. **Skopiuj CAŁY kod** z pliku `import_users.js`
5. **Wklej** w Console
6. Naciśnij **Enter**
7. ✅ **Gotowe!** Wszyscy użytkownicy zostaną dodani automatycznie

---

## Metoda 2: Import przez aplikację Flutter (JESZCZE SZYBSZE)

### Opcja A: Użyj funkcji w aplikacji

Mogę dodać do aplikacji przycisk "Import użytkowników", który automatycznie:
1. Pobierze listę użytkowników z Authentication
2. Automatycznie utworzy dokumenty w Firestore
3. Dopasuje UID do danych

Chcesz, żebym to dodał? Napisz "tak" jeśli tak.

---

## Lista 18 emaili do dodania w Authentication:

```
1. korczes9@gmail.com
2. osp_kolumna@straz.edu.pl
3. 2bora@wp.pl
4. patrykborzecki11@gmail.com
5. krystianof12@interia.pl
6. kamil1703@o2.pl
7. domio123dko@gmail.com
8. kacper.knop4@wp.pl
9. hubert.469b@gmail.com
10. korkihard9@wp.pl
11. kamil.kubsz@o2.pl
12. robertkujawa3108@gmail.com
13. kubamarki@gmail.com
14. michalmataska201@go2.pl
15. bartek1292001@wp.pl
16. palmateusz641@gmail.com
17. dpawlak@autograf.pl
18. ppiecyk@onet.pl
```

**Hasło dla wszystkich:** `ospkolumna123`

---

## Mapowanie danych:

| Email | Imię | Nazwisko | Rola |
|-------|------|----------|------|
| korczes9@gmail.com | Sebastian | Grochulski | **administrator** |
| osp_kolumna@straz.edu.pl | OSP | Kolumna | **moderator** |
| Pozostałe 16 | - | - | **strazak** |

---

## ❓ Troubleshooting

### Problem: "firebase is not defined"
**Rozwiązanie:** Upewnij się, że jesteś w Firebase Console, na stronie Firestore Database

### Problem: "Permission denied"
**Rozwiązanie:** Najpierw wdróż reguły Firestore (z pliku `firestore.rules`)

### Problem: Skrypt nic nie robi
**Rozwiązanie:** Sprawdź czy zamieniłeś wszystkie `WKLEJ_USER_UID_X` na prawdziwe UID

---

## 💡 Najlepsza metoda?

**Polecam Metodę 1** - jest najszybsza i najprostsza!

Czas wykonania: ~5 minut
