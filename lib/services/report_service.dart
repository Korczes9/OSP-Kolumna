import 'package:cloud_firestore/cloud_firestore.dart';

class ReportService {
  static final _db = FirebaseFirestore.instance;

  /// Wywołaj przy ALARMIE
  static Future<void> startReport() async {
    final number = await generateReportNumber();

    await _db.collection('reports').add({
      'number': number,
      'startTime': FieldValue.serverTimestamp(),
      'endTime': null,
      'type': 'Pożar',
      'address': 'Kolumna – przykład',
    });
  }

  /// Wywołaj po zakończeniu działań
  static Future<void> endReport(String reportId) async {
    await _db.collection('reports').doc(reportId).update({
      'endTime': FieldValue.serverTimestamp(),
    });
  }

  /// Generuje unikalny numer wyjazdu na podstawie roku i licznika
  static Future<String> generateReportNumber() async {
    final db = FirebaseFirestore.instance;
    final year = DateTime.now().year.toString();
    final ref = db.collection('counters').doc(year);

    return db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);

      int nextNumber = 1;
      if (snapshot.exists) {
        nextNumber = (snapshot['lastNumber'] as int) + 1;
      }

      transaction.set(ref, {'lastNumber': nextNumber});
      return '$nextNumber/$year';
    });
  }
}
