# Wsparcie Offline dla Aplikacji OSP Kolumna

## Przegląd

Aplikacja została zaktualizowana o pełne wsparcie pracy offline. Dane są automatycznie cache'owane lokalnie i synchronizowane gdy połączenie internetowe jest dostępne.

## Funkcjonalności

### 1. Automatyczne Cache'owanie Danych (Firestore)
- **Firestore Persistence**: Włączona automatyczna persistencja offline dla wszystkich zapytań Firestore
- **Nielimitowany Cache**: Rozmiar cache nie jest ograniczony
- **Automatyczna Synchronizacja**: Firestore automatycznie synchronizuje dane gdy połączenie powraca

### 2. Kolejka Operacji Offline
- Wszystkie operacje zapisu wykonane offline są zapisywane w lokalnej kolejce
- Operacje są automatycznie synchronizowane gdy połączenie powraca
- Wspierane operacje:
  - Ustawianie statusu odpowiadających
  - Usuwanie z listy odpowiadających
  - Przypisywanie strażaków do wozów
  - Usuwanie strażaków z wozów

### 3. Monitorowanie Połączenia
- Widget `StatusPoloczeniaWidget` pokazuje aktualny status połączenia
- Kolory:
  - 🟢 Zielony = Online
  - 🟠 Pomarańczowy = Offline
- Przycisk synchronizacji ręcznej dostępny w trybie offline

## Nowe Serwisy

### SerwisPolaczenia
Monitoruje status połączenia internetowego.

**Metody:**
- `czyJestPolaczenie()` - sprawdza obecny status
- `monitorujPolaczenie()` - stream zmian połączenia
- `czyOnline()` - alias dla czyJestPolaczenie()

### SerwisCacheLokalne
Zarządza lokalnym cache przy użyciu Hive.

**Metody:**
- `init()` - inicjalizuje bazę lokalną
- `zapiszOperacjeOffline(Map)` - dodaje operację do kolejki
- `pobierzOczekujaceOperacje()` - pobiera kolejkę operacji
- `wyczyscOczekujaceOperacje()` - czyści kolejkę po synchronizacji
- `zapiszOdpowiadajacych(List)` - zapisuje dane odpowiadających
- `pobierzOdpowiadajacych()` - pobiera dane odpowiadających
- `zapiszZalogeWozu(String, List)` - zapisuje załogę pojazdu
- `pobierzZalogeWozu(String)` - pobiera załogę pojazdu
- `wyczyscCache()` - czyści cały cache

## Zaktualizowane Serwisy

### AlarmService
Dodano wsparcie offline:
- `setStatus()` - działa offline, zapisuje do kolejki
- `removeFromList()` - działa offline, zapisuje do kolejki
- `synchronizujOperacjeOffline()` - synchronizuje operacje z Firestore

### SerwisWozu
Dodano wsparcie offline:
- `assignToVehicle()` - działa offline, zapisuje do kolejki
- `usunZWozu()` - działa offline, zapisuje do kolejki
- `synchronizujOperacjeOffline()` - synchronizuje operacje z Firestore

## Widget Statusu Połączenia

Dodaj do AppBar dowolnego ekranu:

```dart
AppBar(
  title: const Text('Tytuł'),
  actions: const [
    Padding(
      padding: EdgeInsets.only(right: 16.0),
      child: StatusPoloczeniaWidget(),
    ),
  ],
)
```

## Jak To Działa

### Tryb Online
1. Użytkownik wykonuje akcję (np. ustawia status)
2. Dane są zapisywane bezpośrednio w Firestore
3. Firestore automatycznie cache'uje dane lokalnie
4. Aplikacja działa normalnie

### Tryb Offline
1. Użytkownik wykonuje akcję
2. System wykrywa brak połączenia
3. Operacja jest zapisywana w lokalnej kolejce (Hive)
4. Użytkownik widzi komunikat "📴 Status saved offline"
5. Dane są nadal dostępne z cache Firestore

### Powrót Połączenia
1. System wykrywa powrót połączenia
2. Automatycznie uruchamia synchronizację
3. Wszystkie oczekujące operacje są wysyłane do Firestore
4. Kolejka jest czyszczona
5. Użytkownik widzi "✓ Synchronizacja zakończona"

## Nowe Zależności

W `pubspec.yaml` dodano:
```yaml
connectivity_plus: ^6.1.1  # Detekcja połączenia
```

Istniejące zależności wykorzystywane dla offline:
```yaml
hive: ^2.2.3              # Lokalna baza danych
hive_flutter: ^1.1.0      # Integracja Hive z Flutter
cloud_firestore: ^6.1.2   # Firestore z offline persistence
```

## Konfiguracja Firebase

W `main.dart` skonfigurowano:

```dart
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

## Testowanie

### Test Trybu Offline
1. Uruchom aplikację
2. Wyłącz WiFi/dane mobilne
3. Widget statusu powinien pokazać "Offline" (pomarańczowy)
4. Wykonaj akcje (ustaw status, przypisz do wozu)
5. Sprawdź logi - powinny pokazać "📴 Status saved offline"
6. Włącz połączenie
7. Widget powinien pokazać "Online" (zielony)
8. Sprawdź logi - powinny pokazać "🔄 Synchronizacja..."
9. Dane powinny być zsynchronizowane z Firestore

### Test Cache'a Firestore
1. Uruchom aplikację online
2. Wczytaj dane (lista odpowiadających, załoga wozu)
3. Wyłącz połączenie
4. Dane nadal powinny być widoczne (z cache)
5. Interfejs nadal działa, pokazując ostatnio cache'owane dane

## Logi Debug

Aplikacja loguje:
- ✓ - Operacja zakończona sukcesem
- ❌ - Błąd
- 📴 - Operacja offline
- 🔄 - Synchronizacja w toku

## Najlepsze Praktyki

1. **Zawsze używaj serwisów** - nie wykonuj operacji Firestore bezpośrednio
2. **Monitoruj status** - dodaj `StatusPoloczeniaWidget` do głównych ekranów
3. **Informuj użytkowników** - pokazuj komunikaty o statusie offline
4. **Testuj offline** - regularnie testuj funkcjonalność bez połączenia

## Rozwiązywanie Problemów

### Dane nie synchronizują się
1. Sprawdź logi w konsoli
2. Upewnij się, że połączenie jest stabilne
3. Użyj ręcznej synchronizacji (przycisk sync w widgecie)
4. Sprawdź czy Firebase jest poprawnie skonfigurowany

### Cache zajmuje za dużo miejsca
Cache jest nielimitowany. Jeśli to problem:
1. Otwórz `main.dart`
2. Zmień `CACHE_SIZE_UNLIMITED` na konkretną wartość w bajtach
3. Przykład: `cacheSizeBytes: 100 * 1024 * 1024` (100 MB)

### Operacje duplikują się
Jeśli widzisz duplikaty po synchronizacji:
1. Sprawdź logi
2. Upewnij się, że `wyczyscOczekujaceOperacje()` jest wywoływane
3. Może być potrzebne ręczne wyczyszczenie cache

## Przyszłe Usprawnienia

Możliwe rozszerzenia:
- Wskaźnik liczby oczekujących operacji
- Historia synchronizacji
- Retry logic dla nieudanych synchronizacji
- Priorytetyzacja operacji w kolejce
- Kompresja danych w cache
- Limit czasu dla starych operacji
