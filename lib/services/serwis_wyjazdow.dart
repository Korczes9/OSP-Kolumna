import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wyjazd.dart';
import 'serwis_powiadomien.dart';

/// Serwis zarządzania wyjazdami
class SerwisWyjazdow {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Dodaje nowy wyjazd
  Future<Map<String, dynamic>> dodajWyjazd({
    required KategoriaWyjazdu kategoria,
    required String lokalizacja,
    required String opis,
    required String utworzonePrzez,
    DateTime? dataWyjazdu, // Opcjonalna data
    String? dowodcaId,
    List<String>? strazacyIds,
    String? wozId,
    String? woz1Id,
    String? woz2Id,
    List<String>? woz1StrazacyIds,
    List<String>? woz2StrazacyIds,
    String? uwagi,
    DateTime? godzinaRozpoczecia,
    DateTime? godzinaZakonczenia,
  }) async {
    try {
      final wyjazd = Wyjazd(
        id: '',
        kategoria: kategoria,
        status: StatusWyjazdu.oczekujacy,
        lokalizacja: lokalizacja,
        opis: opis,
        dataWyjazdu: dataWyjazdu ?? DateTime.now(),
        utworzonePrzez: utworzonePrzez,
        dowodcaId: dowodcaId,
        strazacyIds: strazacyIds ?? [],
        wozId: wozId,
        woz1Id: woz1Id,
        woz2Id: woz2Id,
        woz1StrazacyIds: woz1StrazacyIds ?? [],
        woz2StrazacyIds: woz2StrazacyIds ?? [],
        uwagi: uwagi,
        godzinaRozpoczecia: godzinaRozpoczecia,
        godzinaZakonczenia: godzinaZakonczenia,
      );

      final docRef = await _firestore.collection('wyjazdy').add(wyjazd.toMap());

      debugPrint('Dodano wyjazd: ${docRef.id} - $lokalizacja');

      // Wyślij powiadomienie push do wszystkich strażaków
      await SerwisPowiadomien.wyslijPowiadomienieOWyjezdzie(
        wyjazdId: docRef.id,
        kategoria: kategoria.nazwa,
        lokalizacja: lokalizacja,
        opis: opis,
      );

      return {
        'success': true,
        'wyjazdId': docRef.id,
      };
    } catch (e) {
      debugPrint('Błąd dodawania wyjazdu: $e');
      return {
        'success': false,
        'error': 'Błąd dodawania wyjazdu: $e',
      };
    }
  }

  /// Pobiera listę wyjazdów (stream)
  Stream<List<Wyjazd>> pobierzWyjazdy({
    StatusWyjazdu? status,
    int limit = 50,
  }) {
    Query query = _firestore
        .collection('wyjazdy')
        .orderBy('dataWyjazdu', descending: true)
        .limit(limit);

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) =>
              Wyjazd.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  /// Pobiera pojedynczy wyjazd
  Future<Wyjazd?> pobierzWyjazd(String wyjazdId) async {
    try {
      final doc = await _firestore.collection('wyjazdy').doc(wyjazdId).get();
      if (doc.exists) {
        return Wyjazd.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Błąd pobierania wyjazdu: $e');
      return null;
    }
  }

  /// Przypisuje strażaków do wyjazdu
  Future<bool> przypiszStrazakow(
      String wyjazdId, List<String> strazacyIds) async {
    try {
      await _firestore.collection('wyjazdy').doc(wyjazdId).update({
        'strazacyIds': strazacyIds,
      });
      debugPrint(
          'Przypisano strażaków do wyjazdu $wyjazdId: ${strazacyIds.length}');
      return true;
    } catch (e) {
      debugPrint('Błąd przypisywania strażaków: $e');
      return false;
    }
  }

  /// Przypisuje wóz do wyjazdu
  Future<bool> przypiszWoz(String wyjazdId, String wozId) async {
    try {
      await _firestore.collection('wyjazdy').doc(wyjazdId).update({
        'wozId': wozId,
      });
      debugPrint('Przypisano wóz $wozId do wyjazdu $wyjazdId');
      return true;
    } catch (e) {
      debugPrint('Błąd przypisywania wozu: $e');
      return false;
    }
  }

  /// Aktualizuje wyjazd
  Future<bool> edytujWyjazd({
    required String wyjazdId,
    required String lokalizacja,
    required String opis,
    required KategoriaWyjazdu kategoria,
    required DateTime dataWyjazdu,
    DateTime? godzinaRozpoczecia,
    DateTime? godzinaZakonczenia,
    String? dowodcaId,
    List<String>? strazacyIds,
    String? wozId,
    String? woz1Id,
    String? woz2Id,
    List<String>? woz1StrazacyIds,
    List<String>? woz2StrazacyIds,
    String? uwagi,
  }) async {
    try {
      final Map<String, dynamic> updateData = {
        'opis': opis,
        'lokalizacja': lokalizacja,
        'kategoria': kategoria.name,
        'dataWyjazdu': Timestamp.fromDate(dataWyjazdu),
        'godzinaRozpoczecia': godzinaRozpoczecia != null
            ? Timestamp.fromDate(godzinaRozpoczecia)
            : null,
        'godzinaZakonczenia': godzinaZakonczenia != null
            ? Timestamp.fromDate(godzinaZakonczenia)
            : null,
      };

      if (dowodcaId != null) updateData['dowodcaId'] = dowodcaId;
      if (strazacyIds != null) updateData['strazacyIds'] = strazacyIds;
      if (wozId != null) updateData['wozId'] = wozId;
      if (woz1Id != null) updateData['woz1Id'] = woz1Id;
      if (woz2Id != null) updateData['woz2Id'] = woz2Id;
      if (woz1StrazacyIds != null) updateData['woz1StrazacyIds'] = woz1StrazacyIds;
      if (woz2StrazacyIds != null) updateData['woz2StrazacyIds'] = woz2StrazacyIds;
      if (uwagi != null) updateData['uwagi'] = uwagi;

      await _firestore.collection('wyjazdy').doc(wyjazdId).update(updateData);
      debugPrint('Zaktualizowano wyjazd: $wyjazdId');
      return true;
    } catch (e) {
      debugPrint('Błąd aktualizacji wyjazdu: $e');
      return false;
    }
  }

  /// Przypisuje dowódcę do wyjazdu
  Future<bool> przypiszDowodce(String wyjazdId, String dowodcaId) async {
    try {
      await _firestore.collection('wyjazdy').doc(wyjazdId).update({
        'dowodcaId': dowodcaId,
      });
      debugPrint('Przypisano dowódcę $dowodcaId do wyjazdu $wyjazdId');
      return true;
    } catch (e) {
      debugPrint('Błąd przypisywania dowódcy: $e');
      return false;
    }
  }

  /// Zmienia status wyjazdu
  Future<bool> zmienStatus(String wyjazdId, StatusWyjazdu nowyStatus) async {
    try {
      final Map<String, dynamic> updateData = {
        'status': nowyStatus.name,
      };

      // Jeśli kończymy wyjazd, zapisz datę zakończenia
      if (nowyStatus == StatusWyjazdu.zakonczony) {
        updateData['dataZakonczenia'] = Timestamp.fromDate(DateTime.now());
      }

      await _firestore.collection('wyjazdy').doc(wyjazdId).update(updateData);
      debugPrint('Zmieniono status wyjazdu $wyjazdId na ${nowyStatus.nazwa}');
      return true;
    } catch (e) {
      debugPrint('Błąd zmiany statusu: $e');
      return false;
    }
  }

  /// Potwierdza wyjazd (tylko Administrator lub Moderator)
  Future<bool> potwierdzWyjazd(String wyjazdId, String administratorId) async {
    try {
      await _firestore.collection('wyjazdy').doc(wyjazdId).update({
        'potwierdzony': true,
        'potwierdzonyPrzez': administratorId,
        'dataPotwierdzenia': Timestamp.fromDate(DateTime.now()),
      });
      debugPrint('Wyjazd $wyjazdId potwierdzony przez $administratorId');
      return true;
    } catch (e) {
      debugPrint('Błąd potwierdzania wyjazdu: $e');
      return false;
    }
  }

  /// Aktualizuje szczegóły wyjazdu
  Future<bool> aktualizujWyjazd({
    required String wyjazdId,
    KategoriaWyjazdu? kategoria,
    String? lokalizacja,
    String? opis,
    String? uwagi,
  }) async {
    try {
      final Map<String, dynamic> updateData = {};

      if (kategoria != null) updateData['kategoria'] = kategoria.name;
      if (lokalizacja != null) updateData['lokalizacja'] = lokalizacja;
      if (opis != null) updateData['opis'] = opis;
      if (uwagi != null) updateData['uwagi'] = uwagi;

      if (updateData.isEmpty) return false;

      await _firestore.collection('wyjazdy').doc(wyjazdId).update(updateData);
      debugPrint('Zaktualizowano wyjazd $wyjazdId');
      return true;
    } catch (e) {
      debugPrint('Błąd aktualizacji wyjazdu: $e');
      return false;
    }
  }

  /// Usuwa wyjazd (tylko Administrator)
  Future<bool> usunWyjazd(String wyjazdId) async {
    try {
      await _firestore.collection('wyjazdy').doc(wyjazdId).delete();
      debugPrint('Usunięto wyjazd $wyjazdId');
      return true;
    } catch (e) {
      debugPrint('Błąd usuwania wyjazdu: $e');
      return false;
    }
  }

  /// Pobiera aktywne wyjazdy
  Stream<List<Wyjazd>> pobierzAktywneWyjazdy() {
    return _firestore
        .collection('wyjazdy')
        .where('status', whereIn: [
          StatusWyjazdu.oczekujacy.name,
          StatusWyjazdu.wTrakcie.name,
        ])
        .orderBy('dataWyjazdu', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Wyjazd.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  /// Pobiera statystyki wyjazdów
  Future<Map<String, int>> pobierzStatystyki() async {
    try {
      final snapshot = await _firestore.collection('wyjazdy').get();

      Map<String, int> statystyki = {
        'ogolnie': snapshot.docs.length,
        'oczekujace': 0,
        'wTrakcie': 0,
        'zakonczone': 0,
        'anulowane': 0,
      };

      for (var doc in snapshot.docs) {
        final status = doc.data()['status'] as String;
        statystyki[status] = (statystyki[status] ?? 0) + 1;
      }

      return statystyki;
    } catch (e) {
      debugPrint('Błąd pobierania statystyk: $e');
      return {};
    }
  }
}
