import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'serwis_cache_lokalnego.dart';
import 'serwis_polaczenia.dart';

/// Serwis obsługujący alarmy w Firestore z wsparciem offline
class AlarmService {
  static final _db = FirebaseFirestore.instance;

  /// Saves responder status in Firestore
  /// Data saved in: alarms > active > responses > userId
  /// Działa offline - dane zapisywane są lokalnie i synchronizowane po powrocie połączenia
  static Future<void> setStatus({
    required String userId,
    required String name,
    required String status,
  }) async {
    try {
      final czyOnline = await SerwisPolaczenia.czyOnline();
      
      if (czyOnline) {
        // Online - zapis do Firestore
        await _db
            .collection('alarmy')
            .doc('aktywny')
            .collection('odpowiadajacy')
            .doc(userId)
            .set({
          'name': name,
          'status': status,
          'responseTime': FieldValue.serverTimestamp(),
        });
        debugPrint('✓ Status updated online: $status');
      } else {
        // Offline - zapis do lokalnej kolejki
        await SerwisCacheLokalne.zapiszOperacjeOffline({
          'type': 'setStatus',
          'userId': userId,
          'name': name,
          'status': status,
          'timestamp': DateTime.now().toIso8601String(),
        });
        debugPrint('📴 Status saved offline: $status (oczekuje synchronizacji)');
      }
    } catch (e) {
      debugPrint('❌ Error saving status: $e');
      // W razie błędu, zapisz offline
      await SerwisCacheLokalne.zapiszOperacjeOffline({
        'type': 'setStatus',
        'userId': userId,
        'name': name,
        'status': status,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Removes responder from list
  /// Działa offline
  static Future<void> removeFromList(String userId) async {
    try {
      final czyOnline = await SerwisPolaczenia.czyOnline();
      
      if (czyOnline) {
        await _db
            .collection('alarmy')
            .doc('aktywny')
            .collection('odpowiadajacy')
            .doc(userId)
            .delete();
        debugPrint('✓ Removed from list online');
      } else {
        await SerwisCacheLokalne.zapiszOperacjeOffline({
          'type': 'removeFromList',
          'userId': userId,
          'timestamp': DateTime.now().toIso8601String(),
        });
        debugPrint('📴 Remove operation saved offline');
      }
    } catch (e) {
      debugPrint('❌ Error removing: $e');
    }
  }

  /// Gets responders stream for active alarm
  /// Firestore automatycznie obsługuje offline cache
  static Stream<QuerySnapshot> getResponders() {
    return _db
        .collection('alarmy')
        .doc('aktywny')
        .collection('odpowiadajacy')
        .orderBy('responseTime', descending: false)
        .snapshots();
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
      
      debugPrint('🔄 Synchronizacja ${operacje.length} operacji...');
      
      for (final operacja in operacje) {
        try {
          if (operacja['type'] == 'setStatus') {
            await _db
                .collection('alarmy')
                .doc('aktywny')
                .collection('odpowiadajacy')
                .doc(operacja['userId'])
                .set({
              'name': operacja['name'],
              'status': operacja['status'],
              'responseTime': FieldValue.serverTimestamp(),
            });
          } else if (operacja['type'] == 'removeFromList') {
            await _db
                .collection('alarmy')
                .doc('aktywny')
                .collection('odpowiadajacy')
                .doc(operacja['userId'])
                .delete();
          }
        } catch (e) {
          debugPrint('❌ Błąd synchronizacji operacji: $e');
        }
      }
      
      await SerwisCacheLokalne.wyczyscOczekujaceOperacje();
      debugPrint('✓ Synchronizacja zakończona');
    } catch (e) {
      debugPrint('❌ Błąd podczas synchronizacji: $e');
    }
  }
}

