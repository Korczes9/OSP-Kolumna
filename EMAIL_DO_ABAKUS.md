# Email do Abakus - Zapytanie o Integrację API

## 📧 Dane kontaktowe

**DO:** support@abakus.net.pl  
**KOPIA:** kontakt@abakus.net.pl  
**TEMAT:** Zapytanie o integrację API - OSP Kolumna (ID: 2008000123)

---

## ✉️ Treść emaila (skopiuj poniżej)

```
Dzień dobry,

Jesteśmy jednostką Ochotniczej Straży Pożarnej Kolumna, korzystającą 
z systemu e-Remiza (ID jednostki: 2008000123, usługa aktywna do 27-02-2026).

Rozwijamy dedykowaną aplikację mobilną dla naszych strażaków OSP 
i chcielibyśmy zintegrować ją z systemem e-Remiza w celu automatyzacji 
przepływu informacji.

═══════════════════════════════════════════════════════════════

ZAKRES INTEGRACJI, O KTÓRY PYTAMY:

1. Automatyczne pobieranie nowych alarmów:
   - Webhooks (system e-Remiza wysyła alarmy do naszego endpointu)
   - lub REST API (aplikacja odpytuje e-Remizę co X sekund)
   
2. Synchronizacja danych o wyjazdach:
   - Aktualizacja statusów interwencji (w trakcie, zakończony)
   - Czas trwania wyjazdu, liczba zaangażowanych strażaków
   
3. Dane alarmowe, które nas interesują:
   - Czas alarmu
   - Rodzaj zdarzenia (P, MZ, Alarm, itp.)
   - Lokalizacja (adres + współrzędne GPS)
   - Opis zdarzenia
   - Numer zdarzenia/ID z systemu e-Remiza

═══════════════════════════════════════════════════════════════

PYTANIA TECHNICZNE:

1. Czy e-Remiza udostępnia publiczne REST API lub webhooks?
2. Czy jest dostępna dokumentacja techniczna integracji?
3. Czy wymagana jest dodatkowa licencja/moduł do włączenia API?
4. Jakie są koszty takiej integracji (jednorazowe/abonament)?
5. Czy są ograniczenia w liczbie zapytań (rate limiting)?
6. Jakie dane uwierzytelniające są potrzebne (API key, OAuth, token)?
7. Czy inne jednostki OSP korzystają z podobnej integracji?

═══════════════════════════════════════════════════════════════

ALTERNATYWNE ROZWIĄZANIA:

Jeśli API/webhooks nie są dostępne, jesteśmy otwarci na:
- Export automatyczny do CSV/Excel z harmonogramem
- Integrację przez Google Sheets
- Dedykowaną integrację na zamówienie (płatną)
- Inne rozwiązanie techniczne, które Państwo zaproponują

═══════════════════════════════════════════════════════════════

KONTEKST BIZNESOWY:

Aplikacja jest rozwijana PRO BONO dla potrzeb naszej jednostki OSP.
Integracja pozwoliłaby na:
- Szybszy dostęp strażaków do informacji o alarmach
- Zmniejszenie obciążenia dyspozytorów
- Lepszą koordynację działań w terenie
- Archiwizację danych dla celów sprawozdawczych

Bardzo prosimy o informację o możliwościach technicznej współpracy.
W razie potrzeby chętnie umówimy się na rozmowę telefoniczną lub 
spotkanie online, żeby przedyskutować szczegóły.

═══════════════════════════════════════════════════════════════

Dane kontaktowe:

Sebastian Grochulski
Ochotnicza Straż Pożarna Kolumna
Email: [WPISZ SWÓJ EMAIL]
Telefon: [WPISZ SWÓJ NUMER]

Oczekujemy odpowiedzi w terminie do 14 dni.

Z poważaniem,
Sebastian Grochulski
w imieniu OSP Kolumna
```

---

## 📋 Checklist przed wysłaniem

- [ ] Uzupełnij swój email kontaktowy
- [ ] Uzupełnij numer telefonu
- [ ] Dodaj w kopii (CC) komendanta/prezesa OSP Kolumna
- [ ] Sprawdź czy ID jednostki jest poprawny (2008000123)
- [ ] Wyślij email z oficjalnego adresu OSP (jeśli jest dostępny)

---

## 🔔 Co dalej?

**Jeśli otrzymasz odpowiedź pozytywną:**
1. Poproś o dokumentację API
2. Poproś o testowe dane dostępowe (sandbox/środowisko deweloperskie)
3. Zapisz otrzymane tokeny/klucze w pliku `.env` (NIE commituj do GitHuba!)

**Jeśli odpowiedź będzie negatywna/brak API:**
- Użyj ekranu importu CSV/Excel, który właśnie implementuję
- Rozważ płatną integrację na zamówienie (jeśli Abakus to oferuje)

**Brak odpowiedzi po 14 dniach:**
- Wyślij przypomnienie
- Zadzwoń do biura obsługi klienta e-Remiza

---

## 📞 Dodatkowe kontakty Abakus

**Strona główna:** https://www.abakus.net.pl  
**e-Remiza:** https://www.e-remiza.pl  
**Instrukcja:** https://abakus.net.pl/products/Instrukcja_e-Remiza.pdf  
**Zdalna pomoc:** https://get.teamviewer.com/abakus-qs  

**Telefon wsparcia:** (sprawdź na stronie www.abakus.net.pl/kontakt)

---

**Status:** 📤 Gotowe do wysłania  
**Data utworzenia:** 28 stycznia 2026  
**Priorytet:** Wysoki ⭐⭐⭐
