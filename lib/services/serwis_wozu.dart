import 'package:cloud_firestore/cloud_firestore.dart';

/// Serwis obsługujący przypisywanie strażaków do wozów
class SerwisWozu {
  static final _bazaDanych = FirebaseFirestore.instance;

  /// Przypisuje strażaka do wozu
  ///
  /// [woz] - Nazwa wozu (np. "GBA", "GCBA", "SLRT")
  /// [userId] - ID użytkownika
  /// [imię] - Imię i nazwisko
  static Future<void> assignToVehicle({
    required String vehicle,
    required String userId,
    required String name,
  }) async {
    try {
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
      print('✓ Assigned to vehicle: $vehicle');
    } catch (e) {
      print('❌ Error assigning to vehicle: $e');
    }
  }

  /// Usuwa strażaka z wozu
  static Future<void> usunZWozu({
    required String woz,
    required String userId,
  }) async {
    try {
      await _bazaDanych
          .collection('alarmy')
          .doc('aktywny')
          .collection('pojazdy')
          .doc(woz)
          .collection('zaloga')
          .doc(userId)
          .delete();
      print('✓ Usunięto z wozu: $woz');
    } catch (e) {
      print('❌ Błąd usuwania z wozu: $e');
    }
  }

  /// Gets vehicle crew stream
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
}
