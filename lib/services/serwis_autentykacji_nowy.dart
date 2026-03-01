import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/strazak.dart';

/// Serwis obsługujący autentykację użytkownika i zarządzanie strażakami
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Zwraca aktualnie zalogowanego użytkownika
  User? get aktualnyUzytkownik => _auth.currentUser;

  /// Stream zmian stanu autoryzacji
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sprawdza czy użytkownik jest zalogowany
  bool isLoggedIn() => _auth.currentUser != null;

  /// Pomocnicza metoda - sprawdza czy string to email czy numer telefonu
  bool _jestEmailem(String text) {
    return text.contains('@');
  }

  /// Pobiera email użytkownika na podstawie numeru telefonu lub zwraca email jeśli podano email
  Future<String?> pobierzEmailPoIdentyfikatorze(String emailLubTelefon) async {
    try {
      // Jeśli to email, zwróć go bezpośrednio
      if (_jestEmailem(emailLubTelefon)) {
        return emailLubTelefon;
      }

      // Jeśli to numer telefonu, znajdź użytkownika w Firestore
      final numerTelefonu = emailLubTelefon.replaceAll(RegExp(r'\s+'), '');
      final query = await _firestore
          .collection('strazacy')
          .where('numerTelefonu', isEqualTo: numerTelefonu)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return null;
      }

      final strazak = Strazak.fromMap(query.docs.first.data(), query.docs.first.id);
      return strazak.email;
    } catch (e) {
      debugPrint('Błąd pobierania emaila: $e');
      return null;
    }
  }

  /// Loguje użytkownika i sprawdza czy konto istnieje w bazie
  /// Akceptuje email lub numer telefonu
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        return {
          'success': false,
          'error': 'Email/telefon i hasło są wymagane',
        };
      }

      // Jeśli podano numer telefonu, znajdź email
      String emailDoLogowania = email;
      if (!_jestEmailem(email)) {
        final znalezionyEmail = await pobierzEmailPoIdentyfikatorze(email);
        if (znalezionyEmail == null) {
          return {
            'success': false,
            'error': 'Nie znaleziono użytkownika o tym numerze telefonu',
          };
        }
        emailDoLogowania = znalezionyEmail;
      }

      // Zaloguj użytkownika w Firebase Auth
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: emailDoLogowania,
        password: password,
      );

      // Pobierz dane z Firestore z retry mechanism
      DocumentSnapshot<Map<String, dynamic>>? strazakDoc;
      int retries = 3;
      
      for (int i = 0; i < retries; i++) {
        try {
          // Odczekaj przed próbą odczytu (dłużej przy kolejnych próbach)
          if (i > 0) {
            await Future.delayed(Duration(milliseconds: 500 * i));
            debugPrint('Retry $i/3 - próba pobrania danych Firestore...');
          }
          
          strazakDoc = await _firestore
              .collection('strazacy')
              .doc(userCredential.user!.uid)
              .get();
          
          // Jeśli udało się pobrać, przerwij pętlę
          break;
        } on FirebaseException catch (e) {
          debugPrint('Błąd Firestore (próba ${i + 1}/$retries): ${e.code} - ${e.message}');
          
          // Jeśli to ostatnia próba, rzuć wyjątek dalej
          if (i == retries - 1) {
            rethrow;
          }
          // W przeciwnym razie spróbuj ponownie
        }
      }

      if (strazakDoc == null || !strazakDoc.exists) {
        await _auth.signOut();
        return {
          'success': false,
          'error': 'Konto nie istnieje w bazie. Skontaktuj się z administratorem.',
        };
      }

      final strazak = Strazak.fromMap(strazakDoc.data()!, strazakDoc.id);

      if (!strazak.aktywny) {
        await _auth.signOut();
        return {
          'success': false,
          'error': 'Konto zostało dezaktywowane. Skontaktuj się z administratorem.',
        };
      }

      // Aktualizuj ostatnią aktywność
      await _firestore.collection('strazacy').doc(strazak.id).update({
        'ostatnioAktywny': DateTime.now().toIso8601String(),
      });

      debugPrint('Zalogowano strażaka: ${strazak.pelneImie}');

      return {
        'success': true,
        'strazak': strazak,
      };
    } on FirebaseAuthException catch (e) {
      debugPrint('Błąd logowania Firebase Auth: ${e.code}');
      String errorMsg = 'Błąd logowania';

      switch (e.code) {
        case 'user-not-found':
          errorMsg = 'Nie znaleziono użytkownika o tym adresie email';
          break;
        case 'wrong-password':
          errorMsg = 'Nieprawidłowe hasło';
          break;
        case 'invalid-email':
          errorMsg = 'Nieprawidłowy format adresu email';
          break;
        case 'user-disabled':
          errorMsg = 'Konto zostało zablokowane';
          break;
        case 'too-many-requests':
          errorMsg = 'Zbyt wiele prób logowania. Spróbuj ponownie później.';
          break;
        default:
          errorMsg = 'Błąd logowania: ${e.message}';
      }

      return {
        'success': false,
        'error': errorMsg,
      };
    } catch (e) {
      debugPrint('Błąd podczas logowania: $e');
      return {
        'success': false,
        'error': 'Nieoczekiwany błąd: $e',
      };
    }
  }

  /// Wylogowuje użytkownika
  Future<void> logout() async {
    try {
      await _auth.signOut();
      debugPrint('Użytkownik wylogowany');
    } catch (e) {
      debugPrint('Błąd podczas wylogowywania: $e');
    }
  }

  /// Dodaje nowego strażaka (tylko admin)
  Future<Map<String, dynamic>> dodajStrazaka({
    required String imie,
    required String nazwisko,
    required String email,
    required String numerTelefonu,
    required String haslo,
    required RolaStrazaka rola,
  }) async {
    try {
      // Sprawdź czy email już istnieje
      final istniejacyQuery = await _firestore
          .collection('strazacy')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (istniejacyQuery.docs.isNotEmpty) {
        return {
          'success': false,
          'error': 'Strażak o tym adresie email już istnieje',
        };
      }

      // Sprawdź czy numer telefonu już istnieje
      final istniejacyTelefonQuery = await _firestore
          .collection('strazacy')
          .where('numerTelefonu', isEqualTo: numerTelefonu)
          .limit(1)
          .get();

      if (istniejacyTelefonQuery.docs.isNotEmpty) {
        return {
          'success': false,
          'error': 'Strażak o tym numerze telefonu już istnieje',
        };
      }

      // Utwórz konto w Firebase Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: haslo,
      );

      final uid = userCredential.user!.uid;

      // Utwórz profil strażaka w Firestore
      // NOWI UŻYTKOWNICY SĄ NIEAKTYWNI - WYMAGAJĄ ZATWIERDZENIA PRZEZ ADMINISTRATORA
      final nowyStrazak = Strazak(
        id: uid,
        imie: imie,
        nazwisko: nazwisko,
        email: email,
        numerTelefonu: numerTelefonu,
        role: [rola],
        aktywny: false, // ZMIENIONE: nowi użytkownicy wymagają zatwierdzenia
      );

      await _firestore
          .collection('strazacy')
          .doc(uid)
          .set(nowyStrazak.toMap());

      debugPrint('Dodano nowego strażaka: ${nowyStrazak.pelneImie}');

      return {
        'success': true,
        'strazak': nowyStrazak,
      };
    } on FirebaseAuthException catch (e) {
      debugPrint('Błąd Firebase Auth: ${e.code}');
      String errorMsg = 'Błąd tworzenia konta';

      switch (e.code) {
        case 'email-already-in-use':
          errorMsg = 'Ten adres email jest już używany';
          break;
        case 'invalid-email':
          errorMsg = 'Nieprawidłowy format adresu email';
          break;
        case 'weak-password':
          errorMsg = 'Hasło jest zbyt słabe (min. 6 znaków)';
          break;
        default:
          errorMsg = 'Błąd tworzenia konta: ${e.message}';
      }

      return {
        'success': false,
        'error': errorMsg,
      };
    } catch (e) {
      debugPrint('Błąd podczas dodawania strażaka: $e');
      return {
        'success': false,
        'error': 'Nieoczekiwany błąd: $e',
      };
    }
  }

  /// Rejestracja nowego użytkownika (z samego ekranu logowania)
  Future<Map<String, dynamic>> zarejestruj({
    required String imie,
    required String nazwisko,
    required String email,
    required String numerTelefonu,
    required String haslo,
  }) async {
    return dodajStrazaka(
      imie: imie,
      nazwisko: nazwisko,
      email: email,
      numerTelefonu: numerTelefonu,
      haslo: haslo,
      rola: RolaStrazaka.strazak, // Domyślnie zwykły strażak
    );
  }

  /// Pobiera dane strażaka po ID
  Future<Strazak?> pobierzStrazaka(String uid) async {
    try {
      final doc = await _firestore.collection('strazacy').doc(uid).get();
      if (doc.exists) {
        return Strazak.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Błąd pobierania strażaka: $e');
      return null;
    }
  }

  /// Pobiera listę wszystkich strażaków
  Stream<List<Strazak>> pobierzWszystkichStrazakow() {
    return _firestore
        .collection('strazacy')
        .where('aktywny', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      // Sortowanie po stronie klienta
      final strazacy = snapshot.docs
          .map((doc) => Strazak.fromMap(doc.data(), doc.id))
          .toList();
      
      strazacy.sort((a, b) => a.nazwisko.compareTo(b.nazwisko));
      return strazacy;
    });
  }

  /// Aktualizuje status aktywności strażaka
  Future<bool> aktualizujStatusStrazaka(String uid, bool aktywny) async {
    try {
      await _firestore.collection('strazacy').doc(uid).update({
        'aktywny': aktywny,
      });
      debugPrint('Zaktualizowano status strażaka $uid: $aktywny');
      return true;
    } catch (e) {
      debugPrint('Błąd aktualizacji statusu: $e');
      return false;
    }
  }

  /// Resetuje hasło użytkownika
  Future<Map<String, dynamic>> resetujHaslo(String email) async {
    try {
      if (email.isEmpty) {
        return {
          'success': false,
          'error': 'Email jest wymagany',
        };
      }

      await _auth.sendPasswordResetEmail(email: email);
      debugPrint('Link do resetowania hasła wysłany na: $email');

      return {
        'success': true,
        'message': 'Link do resetowania hasła został wysłany na adres $email',
      };
    } on FirebaseAuthException catch (e) {
      debugPrint('Błąd resetowania hasła: ${e.code}');
      String errorMsg = 'Błąd resetowania hasła';

      switch (e.code) {
        case 'user-not-found':
          errorMsg = 'Nie znaleziono użytkownika o tym adresie email';
          break;
        case 'invalid-email':
          errorMsg = 'Nieprawidłowy format adresu email';
          break;
        default:
          errorMsg = 'Błąd: ${e.message}';
      }

      return {
        'success': false,
        'error': errorMsg,
      };
    } catch (e) {
      debugPrint('Błąd podczas resetowania hasła: $e');
      return {
        'success': false,
        'error': 'Nieoczekiwany błąd: $e',
      };
    }
  }

  /// Zmienia hasło na podstawie emaila lub numeru telefonu oraz starego hasła
  Future<Map<String, dynamic>> zmienHasloPrzyLogowaniu({
    required String emailLubTelefon,
    required String stareHaslo,
    required String noweHaslo,
  }) async {
    try {
      if (emailLubTelefon.isEmpty || stareHaslo.isEmpty || noweHaslo.isEmpty) {
        return {
          'success': false,
          'error': 'Wszystkie pola są wymagane',
        };
      }

      if (noweHaslo.length < 6) {
        return {
          'success': false,
          'error': 'Nowe hasło musi mieć co najmniej 6 znaków',
        };
      }

      // Ustal właściwy email (obsługa numeru telefonu)
      final email = await pobierzEmailPoIdentyfikatorze(emailLubTelefon);
      if (email == null) {
        return {
          'success': false,
          'error': 'Nie znaleziono użytkownika o podanym emailu/telefonie',
        };
      }

      // Zaloguj użytkownika starym hasłem, żeby zweryfikować tożsamość
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: stareHaslo,
      );

      final user = credential.user;
      if (user == null) {
        return {
          'success': false,
          'error': 'Nie udało się zweryfikować użytkownika',
        };
      }

      // Zmień hasło
      await user.updatePassword(noweHaslo);

      // Opcjonalnie wyloguj po zmianie hasła
      await _auth.signOut();

      return {
        'success': true,
        'message': 'Hasło zostało zmienione. Zaloguj się nowym hasłem.',
      };
    } on FirebaseAuthException catch (e) {
      debugPrint('Błąd zmiany hasła przy logowaniu: ${e.code}');
      String errorMsg = 'Nie udało się zmienić hasła';

      switch (e.code) {
        case 'user-not-found':
          errorMsg = 'Nie znaleziono użytkownika o tym adresie email';
          break;
        case 'wrong-password':
          errorMsg = 'Stare hasło jest nieprawidłowe';
          break;
        case 'invalid-email':
          errorMsg = 'Nieprawidłowy format adresu email';
          break;
        case 'weak-password':
          errorMsg = 'Nowe hasło jest zbyt słabe (min. 6 znaków)';
          break;
        case 'too-many-requests':
          errorMsg = 'Zbyt wiele prób. Spróbuj ponownie później.';
          break;
        default:
          errorMsg = 'Błąd: ${e.message}';
      }

      return {
        'success': false,
        'error': errorMsg,
      };
    } catch (e) {
      debugPrint('Nieoczekiwany błąd zmiany hasła: $e');
      return {
        'success': false,
        'error': 'Nieoczekiwany błąd: $e',
      };
    }
  }

  /// Usuwa strażaka (soft delete - dezaktywacja)
  Future<bool> usunStrazaka(String uid) async {
    try {
      await _firestore.collection('strazacy').doc(uid).update({
        'aktywny': false,
      });
      debugPrint('Dezaktywowano strażaka: $uid');
      return true;
    } catch (e) {
      debugPrint('Błąd usuwania strażaka: $e');
      return false;
    }
  }
  /// Aktualizuje rolę strażaka (może być wiele ról)
  Future<bool> aktualizujRoleStrazaka(String uid, List<String> noweRole) async {
    try {
      await _firestore.collection('strazacy').doc(uid).update({
        'role': noweRole,
      });
      debugPrint('Zaktualizowano role strażaka $uid na: ${noweRole.join(", ")}');
      return true;
    } catch (e) {
      debugPrint('Błąd aktualizacji roli: $e');
      return false;
    }
  }

  /// Aktualizuje imię i nazwisko strażaka
  Future<bool> aktualizujNazweStrazaka(String uid, String imie, String nazwisko) async {
    try {
      await _firestore.collection('strazacy').doc(uid).update({
        'imie': imie,
        'nazwisko': nazwisko,
      });
      debugPrint('Zaktualizowano nazwę strażaka $uid na: $imie $nazwisko');
      return true;
    } catch (e) {
      debugPrint('Błąd aktualizacji nazwy: $e');
      return false;
    }
  }

  /// Aktywuje wszystkich strażaków (przydatne przy pierwszym uruchomieniu)
  Future<Map<String, dynamic>> aktywujWszystkichStrazakow() async {
    try {
      final snapshot = await _firestore.collection('strazacy').get();
      
      if (snapshot.docs.isEmpty) {
        return {
          'success': false,
          'error': 'Brak strażaków w bazie danych',
        };
      }

      int aktywowanych = 0;
      int juzAktywnych = 0;

      final batch = _firestore.batch();

      for (var doc in snapshot.docs) {
        final dane = doc.data();
        final aktywny = dane['aktywny'] as bool?;

        if (aktywny == false || aktywny == null) {
          batch.update(doc.reference, {'aktywny': true});
          aktywowanych++;
        } else {
          juzAktywnych++;
        }
      }

      if (aktywowanych > 0) {
        await batch.commit();
      }

      debugPrint('Aktywowano $aktywowanych strażaków, pominięto $juzAktywnych już aktywnych');

      return {
        'success': true,
        'aktywowanych': aktywowanych,
        'juzAktywnych': juzAktywnych,
      };
    } catch (e) {
      debugPrint('Błąd aktywacji strażaków: $e');
      return {
        'success': false,
        'error': 'Błąd aktywacji: $e',
      };
    }
  }}
