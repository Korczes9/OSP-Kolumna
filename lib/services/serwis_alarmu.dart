import 'package:cloud_firestore/cloud_firestore.dart';

/// Serwis obsługujący alarmy w Firestore
class AlarmService {
  static final _db = FirebaseFirestore.instance;

  /// Saves responder status in Firestore
  /// Data saved in: alarms > active > responses > userId
  static Future<void> setStatus({
    required String userId,
    required String name,
    required String status,
  }) async {
    try {
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
      print('✓ Status updated: $status');
    } catch (e) {
      print('✌️ Error saving status: $e');
    }
  }

  /// Removes responder from list
  static Future<void> removeFromList(String userId) async {
    try {
      await _db
          .collection('alarmy')
          .doc('aktywny')
          .collection('odpowiadajacy')
          .doc(userId)
          .delete();
      print('✓ Removed from list');
    } catch (e) {
      print('✌️ Error removing: $e');
    }
  }

  /// Gets responders stream for active alarm
  static Stream<QuerySnapshot> getResponders() {
    return _db
        .collection('alarmy')
        .doc('aktywny')
        .collection('odpowiadajacy')
        .orderBy('responseTime', descending: false)
        .snapshots();
  }
}
