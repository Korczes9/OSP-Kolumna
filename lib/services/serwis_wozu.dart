import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'serwis_cache_lokalnego.dart';
import 'serwis_polaczenia.dart';

/// Serwis obsługujący przypisywanie strażaków do wozów z wsparciem offline
class SerwisWozu {
  static final _bazaDanych = FirebaseFirestore.instance;

  /// Przypisuje strażaka do wozu
  ///
  /// [vehicle] - Nazwa wozu (np. "GBA", "GCBA", "SLRT")
  /// [userId] - ID użytkownika
  /// [name] - Imię i nazwisko
  /// Działa offline - dane zapisywane są lokalnie i synchronizowane po powrocie połączenia
  static Future<void> assignToVehicle({
    required String vehicle,
    required String userId,
    required String name,
  }) async {
    try {
      final czyOnline = await SerwisPolaczenia.czyOnline();
      
      if (czyOnline) {
        // Online - zapis do Firestore
        await _bazaDanych
            .collection('alarmy')
            .doc('aktywny')
            .collection('pojazdy')
            .doc(vehicle)
            .collection('zaloga')
            .doc(userId)
            .set({
          'name': name,
          'assignedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✓ Assigned to vehicle online: $vehicle');
      } else {
        // Offline - zapis do lokalnej kolejki
        await SerwisCacheLokalne.zapiszOperacjeOffline({
          'type': 'assignToVehicle',
          'vehicle': vehicle,
          'userId': userId,
          'name': name,
          'timestamp': DateTime.now().toIso8601String(),
        });
        debugPrint('📴 Assignment saved offline: $vehicle (oczekuje synchronizacji)');
      }
    } catch (e) {
      debugPrint('❌ Error assigning to vehicle: $e');
      // W razie błędu, zapisz offline
      await SerwisCacheLokalne.zapiszOperacjeOffline({
        'type': 'assignToVehicle',
        'vehicle': vehicle,
        'userId': userId,
        'name': name,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Usuwa strażaka z wozu
  /// Działa offline
  static Future<void> usunZWozu({
    required String woz,
    required String userId,
  }) async {
    try {
      final czyOnline = await SerwisPolaczenia.czyOnline();
      
      if (czyOnline) {
        await _bazaDanych
            .collection('alarmy')
            .doc('aktywny')
            .collection('pojazdy')
            .doc(woz)
            .collection('zaloga')
            .doc(userId)
            .delete();
        debugPrint('✓ Usunięto z wozu online: $woz');
      } else {
        await SerwisCacheLokalne.zapiszOperacjeOffline({
          'type': 'removeFromVehicle',
          'vehicle': woz,
          'userId': userId,
          'timestamp': DateTime.now().toIso8601String(),
        });
        debugPrint('📴 Remove from vehicle saved offline');
      }
    } catch (e) {
      debugPrint('❌ Błąd usuwania z wozu: $e');
    }
  }

  /// Gets vehicle crew stream
  /// Firestore automatycznie obsługuje offline cache
  static Stream<QuerySnapshot> getVehicleCrew(String vehicle) {
    return _bazaDanych
        .collection('alarmy')
        .doc('aktywny')
        .collection('pojazdy')
        .doc(vehicle)
        .collection('zaloga')
        .orderBy('assignedAt', descending: false)
        .snapshots();
  }

  /// Gets all vehicles
  static List<String> getVehicles() {
    return ['GBA', 'GCBA', 'SLRT', 'JRK', 'KDA'];
  }
  
  /// Synchronizuje oczekujące operacje offline
  static Future<void> synchronizujOperacjeOffline() async {
    try {
      final czyOnline = await SerwisPolaczenia.czyOnline();
      if (!czyOnline) {
        debugPrint('📴 Brak połączenia - synchronizacja niedostępna');
        return;
      }
      
      final operacje = await SerwisCacheLokalne.pobierzOczekujaceOperacje();
      if (operacje.isEmpty) {
        debugPrint('✓ Brak operacji do synchronizacji');
        return;
      }
      
      debugPrint('🔄 Synchronizacja operacji wozów...');
      
      for (final operacja in operacje) {
        try {
          if (operacja['type'] == 'assignToVehicle') {
            await _bazaDanych
                .collection('alarmy')
                .doc('aktywny')
                .collection('pojazdy')
                .doc(operacja['vehicle'])
                .collection('zaloga')
                .doc(operacja['userId'])
                .set({
              'name': operacja['name'],
              'assignedAt': FieldValue.serverTimestamp(),
            });
          } else if (operacja['type'] == 'removeFromVehicle') {
            await _bazaDanych
                .collection('alarmy')
                .doc('aktywny')
                .collection('pojazdy')
                .doc(operacja['vehicle'])
                .collection('zaloga')
                .doc(operacja['userId'])
                .delete();
          }
        } catch (e) {
          debugPrint('❌ Błąd synchronizacji operacji wozu: $e');
        }
      }
      
      debugPrint('✓ Synchronizacja wozów zakończona');
    } catch (e) {
      debugPrint('❌ Błąd podczas synchronizacji: $e');
    }
  }
}

