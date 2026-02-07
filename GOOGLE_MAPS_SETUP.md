# Konfiguracja Google Maps API - Przewodnik

## 🗺️ Jak zdobyć klucz Google Maps API

### Krok 1: Utwórz projekt w Google Cloud Console

1. Otwórz [Google Cloud Console](https://console.cloud.google.com/)
2. Zaloguj się swoim kontem Google
3. Kliknij menu rozwijane projektu (górny pasek) → **"Nowy projekt"**
4. Podaj nazwę: **"OSP Kolumna Maps"**
5. Kliknij **"Utwórz"**

### Krok 2: Włącz Maps SDK for Android

1. W menu bocznym: **APIs & Services** → **Library**
2. Wyszukaj: **"Maps SDK for Android"**
3. Kliknij na wynik → **"Enable"** (Włącz)
4. Poczekaj ~30 sekund na aktywację

### Krok 3: Utwórz klucz API

1. W menu: **APIs & Services** → **Credentials** (Dane logowania)
2. Kliknij **"+ CREATE CREDENTIALS"** → **"API key"**
3. Skopiuj wygenerowany klucz (rozpoczyna się od `AIzaSy...`)
4. **WAŻNE**: Kliknij **"Restrict key"** (Ogranicz klucz)

### Krok 4: Zabezpiecz klucz (BARDZO WAŻNE!)

1. W ustawieniach klucza:
   - **Nazwa**: `OSP Kolumna Android Key`
   - **Ograniczenia aplikacji**: Wybierz **"Android apps"**
   - Kliknij **"Add an item"**

2. Pobierz SHA-1 fingerprint:
   ```powershell
   # Uruchom w terminalu VS Code:
   cd c:\Users\User\Desktop\Projekt\flutter_projekt_polski\android
   
   # Debug keystore (do testów):
   keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
   ```

3. Skopiuj **SHA-1** (linia: `SHA1: AB:CD:EF:...`)
4. W Google Cloud Console:
   - **Package name**: `com.example.osp_kolumna` (sprawdź w `android/app/build.gradle.kts`)
   - **SHA-1 certificate fingerprint**: Wklej skopiowany SHA-1
   - Kliknij **"Done"** → **"Save"**

### Krok 5: Ograniczenia API

1. Przewiń do sekcji **"API restrictions"**
2. Wybierz **"Restrict key"**
3. Zaznacz tylko:
   - ✅ **Maps SDK for Android**
4. Kliknij **"Save"**

### Krok 6: Dodaj klucz do aplikacji

1. Otwórz plik:
   ```
   c:\Users\User\Desktop\Projekt\flutter_projekt_polski\android\app\src\main\AndroidManifest.xml
   ```

2. Znajdź linię (ok. 18):
   ```xml
   android:value="AIzaSyDUo_PLACEHOLDER_KEY_NEEDS_TO_BE_REPLACED"/>
   ```

3. Zamień `AIzaSyDUo_PLACEHOLDER_KEY_NEEDS_TO_BE_REPLACED` na swój klucz

4. Zapisz plik

### Krok 7: Testowanie

1. Uruchom aplikację:
   ```bash
   flutter run -d chrome  # Najpierw web (mapa nie działa ale UI tak)
   flutter run -d <android-device>  # Potem Android
   ```

2. W menu głównym kliknij **"Mapa wyjazdów"**
3. Jeśli widzisz mapę Google → **SUKCES!** ✅

## 🆓 Koszty i limity

### Plan darmowy (wystarczający dla OSP):
- **$200 darmowych kredytów miesięcznie**
- **28,500 darmowych wyświetleń mapy/miesiąc**
- **40,000 darmowych geocodingów/miesiąc**

Dla OSP Kolumna (szacunkowo 20-30 użytkowników):
- **Koszt miesięczny: 0 zł** (mieścisz się w limicie darmowym)
- Wymaga karty kredytowej (zabezpieczenie, nie będą pobierane opłaty)

## ⚠️ Troubleshooting

### Problem: "This API project is not authorized to use this API"
**Rozwiązanie**: Upewnij się że włączyłeś "Maps SDK for Android" (Krok 2)

### Problem: Mapa szara/pusta
**Rozwiązanie**: 
1. Sprawdź SHA-1 fingerprint (może być inny dla release build)
2. Sprawdź package name w ograniczeniach klucza
3. Poczekaj 5-10 minut (propagacja zmian w Google)

### Problem: "Authorization failure"
**Rozwiązanie**: Klucz API nie pasuje do SHA-1 lub package name

## 📝 Checklist

- [ ] Utworzono projekt w Google Cloud Console
- [ ] Włączono Maps SDK for Android
- [ ] Utworzono klucz API
- [ ] Dodano ograniczenia Android (package name + SHA-1)
- [ ] Ograniczono do Maps SDK for Android
- [ ] Wklejono klucz do AndroidManifest.xml
- [ ] Przetestowano na urządzeniu Android

## 🔗 Przydatne linki

- [Google Cloud Console](https://console.cloud.google.com/)
- [Maps SDK Pricing](https://mapsplatform.google.com/pricing/)
- [Flutter Google Maps Plugin](https://pub.dev/packages/google_maps_flutter)

---

**Potrzebujesz pomocy?** Daj znać jeśli coś nie działa!
