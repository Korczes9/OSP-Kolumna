# 🚨 Foreground Service - Pełnoekranowe Alarmy z Discord

## 📋 Opis
Aplikacja posiada zaimplementowany **Foreground Service** dla Androida, który:
- ✅ Działa w tle nawet gdy aplikacja jest zamknięta lub telefon zablokowany
- ✅ **Nasłuchuje Discord w czasie rzeczywistym** poprzez kolekcję Firebase `powiadomienia`
- ✅ **Wykrywa słowo kluczowe "KOLUMNA" z Discord**
- ✅ **Wyświetla pełnoekranowy alarm nawet na zablokowanym ekranie**
- ✅ Odtwarza dźwięk alarmu i wibracje
- ✅ Uruchamia się automatycznie przy starcie aplikacji

## 🔥 Jak to działa:

### 1. Monitoring Discord (worker na Render)
Worker Discord (deploy: `notify_backend/discord_worker.js`):
- Monitoruje kanał Discord co kilka sekund
- **Wykrywa słowo kluczowe "KOLUMNA"** w wiadomościach
- Tworzy dokument w Firebase `powiadomienia` z `type: "ALARM"`
- Cloud Function wysyła FCM do wszystkich użytkowników

### 2. Nasłuchiwanie Firebase Realtime (RealtimeService)
Serwis non-stop monitoruje kolekcję `powiadomienia` w Firebase:
- Gdy pojawi się nowy dokument z `type: "ALARM"`
- Sprawdza czy alarm jest świeży (ostatnie 2 minuty)
- **Natychmiast wyświetla pełnoekranowy alarm**

### 3. Pełnoekranowy alarm (nawet na zablokowanym telefonie)
Gdy wykryje nowy alarm z Discord:
- 📱 **Włącza ekran** (nawet gdy telefon jest zablokowany)
- 🔴 **Wyświetla czerwony ekran alarmu** na pełnym ekranie
- 🔊 **Odtwarza dźwięk alarmu** (system alarm ringtone)
- 📳 **Wibruje** w pętli
- 🚫 **Blokuje przycisk wstecz** - użytkownik musi potwierdzić
- 📍 Pokazuje lokalizację wyjazdu

### 3. Opcje po wyświetleniu alarmu
Strażak może:
- **"OTWIERAM APLIKACJĘ"** - otwiera aplikację i zatrzymuje alarm
- **"ZAMKNIJ ALARM"** - tylko zamyka alarm bez otwierania aplikacji

## ✅ Co zostało zaimplementowane:

### 1️⃣ Uprawnienia Android (AndroidManifest.xml)
- `FOREGROUND_SERVICE` - uprawnienie do uruchamiania foreground service
- `FOREGROUND_SERVICE_DATA_SYNC` - dla synchronizacji danych (Android 14+)
- `INTERNET` - dla komunikacji sieciowej
- `USE_FULL_SCREEN_INTENT` - pełnoekranowe powiadomienia
- `SYSTEM_ALERT_WINDOW` - okna na ekranie blokady
- `VIBRATE` - wibracje alarmu
- `WAKE_LOCK` - włączanie ekranu
- `TURN_SCREEN_ON` - odblokowywanie ekranu
- `DISABLE_KEYGUARD` - wyświetlanie nad ekranem blokady

### 2️⃣ Natywny Serwis (RealtimeService.kt)
Lokalizacja: `android/app/src/main/kotlin/pl/ospkolumna/app/RealtimeService.kt`

**Funkcjonalność:**
- ✅ Działa w tle jako Foreground Service
- ✅ Wyświetla notyfikację (nie można jej usunąć gdy serwis działa)
- ✅ **Nasłuchuje Firebase kolekcji `powiadomienia` w czasie rzeczywistym**
- ✅ **Wykrywa alarmy z Discord (type: "ALARM") natychmiast (SnapshotListener)**
- ✅ **Wyświetla pełnoekranowy alarm na zablokowanym telefonie**
- ✅ Automatyczne restartowanie (START_STICKY)
- ✅ Pamięta już przetworzone alarmy (unika duplikatów)

### 3️⃣ Pełnoekranowa aktywność alarmu (AlarmActivity.kt)
Lokalizacja: `android/app/src/main/kotlin/pl/ospkolumna/app/AlarmActivity.kt`

**Funkcjonalność:**
- ✅ Wyświetla się na pełnym ekranie nawet gdy telefon jest zablokowany
- ✅ Włącza ekran i odblokowuje telefon
- ✅ Odtwarza dźwięk alarmu systemowego w pętli
- ✅ Wibruje w rytmie alarmu
- ✅ Czerwone tło z emoji 🚨
- ✅ Pokazuje lokalizację wyjazdu
- ✅ Dwa przyciski: "OTWIERAM APLIKACJĘ" i "ZAMKNIJ ALARM"
- ✅ Blokuje przycisk wstecz (użytkownik musi potwierdzić)

### 3️⃣ Komunikacja Flutter-Android (MainActivity.kt)
**Dostępne metody przez MethodChannel:**
- `startService()` - uruchom serwis
- `stopService()` - zatrzymaj serwis
- `isServiceRunning()` - sprawdź status

### 4️⃣ Manager w Dart (realtime_service_manager.dart)
Lokalizacja: `lib/services/realtime_service_manager.dart`

**API:**
```dart
// Uruchom serwis
await RealtimeServiceManager.startService();

// Zatrzymaj serwis
await RealtimeServiceManager.stopService();

// Sprawdź status
bool isRunning = await RealtimeServiceManager.isServiceRunning();
```

### 5️⃣ Auto-start w main.dart
**Serwis uruchamia się automatycznie przy starcie aplikacji (tylko Android).**

Lokalizacja: `lib/main.dart` (linie ~72-82)

## 🎯 Zastosowanie w aplikacji OSP:

### 🚨 Alarmy strażackie z Discord
Gdy na Discord pojawi się wiadomość ze słowem **"KOLUMNA"**:
1. **Discord Worker** wykrywa słowo kluczowe (działa na Render 24/7)
2. Tworzy dokument w Firebase `powiadomienia` z typem `ALARM`
3. **RealtimeService wykrywa natychmiast** (Firestore SnapshotListener)
4. **Pełnoekranowy alarm wyskakuje na WSZYSTKICH telefonach** nawet:
   - Gdy telefon jest zablokowany 🔒
   - Gdy aplikacja jest zamknięta ✖
   - Gdy użytkownik używa innej aplikacji 📱
5. Dźwięk + wibracje budzą strażaka
6. Strażak widzi treść z Discord i może natychmiast potwierdzić

### ⚡ Natychmiastowa reakcja
- **Brak opóźnień** - Firestore SnapshotListener to realtime
- **Niezawodność** - działa nawet gdy FCM (Firebase Cloud Messaging) zawiesi
- **Pewność** - alarm na pełnym ekranie nie do pominięcia
- **Discord jako źródło** - komenda strażacka może alarmować przez Discord

## 🔧 Jak używać:

### Automatyczne uruchomienie (domyślnie włączone)
Serwis startuje automatycznie gdy aplikacja się uruchamia. Nie musisz nic robić!

### Ręczne zarządzanie (opcjonalnie)
```dart
import 'package:osp_kolumna/services/realtime_service_manager.dart';

// Zatrzymaj serwis
await RealtimeServiceManager.stopService();

// Sprawdź czy działa
bool isRunning = await RealtimeServiceManager.isServiceRunning();

// Uruchom ponownie
await RealtimeServiceManager.startService();
```

## 🎯 Dostosowanie do własnych potrzeb:

### 1. Dost osowanie wyglądu alarmu (AlarmActivity.kt):

Możesz zmienić:
- Kolor tła (obecnie czerwony `#D32F2F`)
- Rozmiar tekstu
- Emoji (obecnie 🚨)
- Treść przycisków
- Interwał wibracji

### 2. Dodanie własnego dźwięku alarmu:

W `AlarmActivity.kt`, funkcja `playAlarmSound()`:n```kotlin
// Zamień na własny dźwięk
val alarmUri = Uri.parse("android.resource://" + packageName + "/" + R.raw.twoj_alarm)
```

Umieść plik MP3 w `android/app/src/main/res/raw/twoj_alarm.mp3`

### 3. Zmiana logiki wykrywania alarmów (RealtimeService.kt):

W funkcji `startFirebaseListener()` możesz:
- Zmienić limit czasu "freśwości" alarmu (obecnie 2 minuty)
- Filtrować konkretne kategorie alarmów
- Dodać dodatkowe warunki

## 📱 Testowanie:

### 1. Build i uruchom aplikację:
```bash
flutter run
```

### 2. Serwis uruchomi się automatycznie - zobaczysz powiadomienie w pasku statusu

### 3. Zminimalizuj lub zamknij aplikację - serwis dalej działa!

### 4. Sprawdź logi:
```bash
adb logcat | grep RealtimeService
```

Zobaczysz logi typu:
```
RealtimeService: 🔄 Wykonywanie pracy w czasie rzeczywistym...
RealtimeService: ✓ Praca wykonana - timestamp: 1707744123456
```

## ⚠️ Ważne informacje:

### Android 10+ (API 29+)
- Foreground Service MUSI wyświetlać notyfikację
- Nie można usunąć notyfikacji gdy serwis działa
- Service może być zabity przez system przy niskim stanie baterii

### Android 12+ (API 31+)
- Wymaga `android:foregroundServiceType` w AndroidManifest
- Dostępne typy: `dataSync`, `location`, `mediaPlayback`, etc.

### Battery Optimization
System może zabić serwis. Aby tego uniknąć:
1. Wyłącz optymalizację baterii dla aplikacji
2. Użyj `WorkManager` jako backup
3. Ustaw interwał > 15 minut dla długotrwałych operacji

## 🔄 Dodatkowe możliwości:

### A. Restart serwisu po rebootcie:
Dodaj w AndroidManifest.xml:
```xml
<receiver android:name=".BootReceiver"
    android:enabled="true"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
    </intent-filter>
</receiver>
```

### B. WorkManager jako backup:
```dart
// W pubspec.yaml dodaj:
// workmanager: ^0.5.2

import 'package:workmanager/workmanager.dart';

Workmanager().registerPeriodicTask(
  "realtime-sync",
  "realtimeSync",
  frequency: Duration(minutes: 15),
);
```

## 📊 Pliki zmodyfikowane/utworzone:

1. ✅ `android/app/src/main/AndroidManifest.xml` - uprawnienia i deklaracje
2. ✅ `android/app/src/main/kotlin/.../RealtimeService.kt` - nasłuchiwanie Firebase 24/7
3. ✅ `android/app/src/main/kotlin/.../AlarmActivity.kt` - pełnoekranowy alarm
4. ✅ `android/app/src/main/kotlin/.../MainActivity.kt` - MethodChannel
5. ✅ `android/app/build.gradle.kts` - zależności (Kotlin coroutines, AppCompat)
6. ✅ `lib/services/realtime_service_manager.dart` - Dart manager
7. ✅ `lib/main.dart` - auto-start serwisu przy uruchomieniu aplikacji

---

## 🚨 ALARM GOTOWY! 🎉

**Teraz gdy na Discord pojawi się wiadomość ze słowem "KOLUMNA":**
1. 📱 Wszystkie telefony natychmiast dostaną pełnoekranowy alarm
2. 🔊 Dźwięk alarmu + wibracje
3. 🔓 Ekran się włączy nawet gdy telefon zablokowany
4. ✅ Strażak musi potwierdzić alarm
5. 🚒 Może otworzyć aplikację jednym kliknięciem

**Działa nawet gdy:**
- ❌ Aplikacja jest zamknięta
- 🔒 Telefon jest zablokowany
- 📵 Użytkownik używa innej aplikacji
- 💤 Telefon jest w trybie snu

**Jak przetestować:**
1. Uruchom aplikację na telefonie
2. Na Discord napisz wiadomość zawierającą słowo **"KOLUMNA"**
3. **ALARM NATYCHMIAST WYSKAKUJE NA TELEFONIE!** 🚨
