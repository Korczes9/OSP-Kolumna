# Naprawa zapisu strażaków do wydarzeń

## Problem
Strażacy (użytkownicy z najniższą rolą) nie mogli zapisywać się do wydarzeń w terminarzu.

## Przyczyna
Reguły Firestore dla kolekcji `wydarzenia` zezwalały tylko moderatorom i administratorom na edycję (`update`). Ponieważ zapisywanie się do wydarzenia wymaga aktualizacji pola `uczestnicyIds`, strażacy byli blokowani.

## Rozwiązanie

### Zmiana w regułach Firestore
Zaktualizowano reguły w pliku `firestore.rules`:

**Przed:**
```javascript
match /wydarzenia/{wydarzenieId} {
  allow read: if isSignedIn();
  allow create, update, delete: if isModerator();
}
```

**Po:**
```javascript
match /wydarzenia/{wydarzenieId} {
  allow read: if isSignedIn();
  
  // Moderator i Administrator mogą tworzyć i usuwać wydarzenia
  allow create, delete: if isModerator();
  
  // Każdy zalogowany może aktualizować uczestników (zapisz/wypisz się)
  // Moderator i Administrator mogą edytować wszystko
  allow update: if isSignedIn() && (
    isModerator() || 
    (
      // Strażak może tylko dodawać/usuwać siebie z listy uczestników
      request.resource.data.diff(resource.data).affectedKeys().hasOnly(['uczestnicyIds']) &&
      (
        // Dodawanie się (arrayUnion)
        request.resource.data.uczestnicyIds.toSet().difference(resource.data.uczestnicyIds.toSet()) == [request.auth.uid].toSet() ||
        // Wypisywanie się (arrayRemove)
        resource.data.uczestnicyIds.toSet().difference(request.resource.data.uczestnicyIds.toSet()) == [request.auth.uid].toSet()
      )
    )
  );
}
```

### Jak działa nowa reguła

1. **Moderatorzy i Administratorzy** - mogą edytować wszystko w wydarzeniu
2. **Strażacy** - mogą aktualizować **tylko** pole `uczestnicyIds` i **tylko** dla siebie:
   - Dodawanie własnego ID do listy (zapisywanie się)
   - Usuwanie własnego ID z listy (wypisywanie się)
   - **Nie mogą** edytować innych pól wydarzenia (tytuł, opis, data itp.)
   - **Nie mogą** dodawać/usuwać innych użytkowników

### Funkcje w aplikacji

W pliku `lib/screens/ekran_terminarza.dart` już istnieją odpowiednie funkcje:

**Zapisywanie się:**
```dart
Future<void> _zapisz(String wydarzenieId) async {
  await _firestore.collection('wydarzenia').doc(wydarzenieId).update({
    'uczestnicyIds': FieldValue.arrayUnion([widget.aktualnyStrazak.id]),
  });
}
```

**Wypisywanie się:**
```dart
Future<void> _wypisz(String wydarzenieId) async {
  await _firestore.collection('wydarzenia').doc(wydarzenieId).update({
    'uczestnicyIds': FieldValue.arrayRemove([widget.aktualnyStrazak.id]),
  });
}
```

## Weryfikacja
Reguły zostały wdrożone za pomocą:
```bash
firebase deploy --only firestore:rules
```

## Testowanie
Aby przetestować poprawkę:
1. Zaloguj się jako strażak (użytkownik z rolą "Strażak")
2. Przejdź do zakładki "Terminarz"
3. Wybierz wydarzenie
4. Kliknij przycisk "Zapisz się"
5. Powinno się wyświetlić potwierdzenie
6. Twoje ID pojawi się na liście uczestników

## Status
✅ **Naprawione** - Strażacy mogą teraz zapisywać się i wypisywać z wydarzeń w terminarzu.
