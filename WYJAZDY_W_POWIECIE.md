# Wyjazdy w powiecie - Dokumentacja

## Przegląd
Nowa funkcja "Wyjazdy w powiecie" umożliwia użytkownikom z rolą **Pro** zgłaszanie wyjazdów strażackich w całym powiecie z automatycznym powiadomieniem na Discord.

## Dostęp
- **Wymagana rola**: Pro lub Administrator
- **Lokalizacja**: Ekran główny → "Wyjazdy w powiecie" (oznaczone jako PRO)

## Rola Pro
Dodano nową rolę użytkownika **Pro** z następującymi charakterystykami:
- **Poziom uprawnień**: 4 (między Gospodarzem a Administratorem)
- **Nazwa**: "Pro"
- **Dostęp**: Wyjazdy w powiecie + wszystkie funkcje podstawowe

### Hierarchia ról:
1. **Administrator** (poziom 5) - pełny dostęp
2. **Pro** (poziom 4) - dostęp do wyjazdów w powiecie
3. **Gospodarz** (poziom 3) - rezerwacje sali
4. **Moderator** (poziom 2) - edycja wyjazdów i kalendarza
5. **Strażak** (poziom 1) - tylko podgląd

## Funkcjonalność

### Formularz zgłoszenia
Użytkownicy z rolą Pro mogą zgłaszać wyjazdy wypełniając:
- **Tytuł wyjazdu** (wymagane) - np. "Pożar budynku mieszkalnego"
- **Miejscowość** (wymagane) - lokalizacja zdarzenia
- **Opis wyjazdu** (wymagane) - szczegółowy opis sytuacji

### Discord Webhook
Zgłoszenie jest automatycznie wysyłane na kanał Discord jako:
- **Embed** z pełnymi informacjami
- **Kolor**: Czerwony (#E74C3C)
- **Zawiera**:
  - Tytuł wyjazdu
  - Opis sytuacji
  - Miejscowość
  - Imię i nazwisko zgłaszającego
  - Data i czas zgłoszenia

**Webhook URL**: 
```
https://discord.com/api/webhooks/1230875529297530910/jjEvvj-BZVx6LexWVvzey9Dc0Li23yDqC-3sphm3aXQj0gF8muchRQVY2GhJM4LQzmyK
```

### Firestore
Wszystkie zgłoszenia są również zapisywane w Firestore:
- **Kolekcja**: `wyjazdy_w_powiecie`
- **Dane**:
  - tytul
  - opis
  - miejscowosc
  - data
  - zglosil_id
  - zglosil_imie
  - utworzono (timestamp)

### Historia wyjazdów
Na ekranie wyświetlana jest historia ostatnich 50 wyjazdów w powiecie:
- Chronologicznie (od najnowszych)
- Z pełnymi informacjami
- Możliwość podglądu szczegółów po kliknięciu

## Przyznawanie roli Pro

### Dla administratorów
Aby przyznać użytkownikowi rolę Pro:

1. Przejdź do **Firestore Console**
2. Znajdź kolekcję `strazacy`
3. Wybierz użytkownika
4. Edytuj pole `role` (tablica)
5. Dodaj wartość: `"pro"`

**Przykład** (JSON):
```json
{
  "role": ["pro"]
}
```

Lub dla użytkownika z wieloma rolami:
```json
{
  "role": ["strazak", "pro"]
}
```

## Bezpieczeństwo
- Dostęp do ekranu jest chroniony - użytkownicy bez roli Pro widzą komunikat o braku dostępu
- Wszystkie zgłoszenia są zapisywane w Firestore z informacją o zgłaszającym
- Webhook jest bezpieczny i nie wymaga dodatkowej autentykacji

## Pliki zmodyfikowane
1. `/lib/models/strazak.dart` - dodano rolę Pro i właściwość `jestPro`
2. `/lib/screens/ekran_wyjazdow_w_powiecie.dart` - nowy ekran (UTWORZONY)
3. `/lib/screens/ekran_domowy_osp.dart` - dodano przycisk dostępu

## Zrzut ekranu funkcji
Ekran składa się z:
- Formularza zgłoszenia (górna połowa)
- Historii wyjazdów (dolna połowa)
- Informacji o statusie wysyłania
- Walidacji pól formularza

## Wsparcie
W razie problemów sprawdź:
- Czy użytkownik ma przypisaną rolę "pro" w Firestore
- Czy webhook Discord jest aktywny
- Czy aplikacja ma połączenie z internetem
- Logi w konsoli (błędy wysyłania)
