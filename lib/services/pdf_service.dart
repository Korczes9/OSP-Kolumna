import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  static Future<void> generateReportPdf({
    required String type,
    required String address,
    required String start,
    required String end,
    required String number,
  }) async {
    final pdf = pw.Document();

    final responders = await getResponders();
    final vehicles = await getVehicles();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'KARTA WYJAZDU OSP KOLUMNA',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Rodzaj zdarzenia: $type'),
            pw.Text('Adres: $address'),
            pw.Text('Czas alarmu: $start'),
            pw.Text('Czas zakończenia: $end'),
            pw.Text('Strażak: ${responders[0]}'),
            pw.Text('Woz: ${vehicles[0]}'),
            pw.Text('Numer: $number'),
            pw.Text('Nr wyjazdu: $number'),
            pw.SizedBox(height: 10),
            pw.Text('STRAŻACY:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ...responders.map((name) => pw.Text('- $name')),

            pw.SizedBox(height: 20),
            pw.Text('OBSADA WOZÓW:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ...vehicles.entries.map(
              (entry) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(entry.key, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ...entry.value.map((name) => pw.Text('  - $name')),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  static Future<List<String>> getResponders() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('alarms')
        .doc('active')
        .collection('responses')
        .get();
    return snapshot.docs
        .map((doc) => doc['name'] as String)
        .toList();
  }

  static Future<Map<String, List<String>>> getVehicles() async {
    final vehicles = <String, List<String>>{};
    final db = FirebaseFirestore.instance;
    final vehicleDocs = await db
        .collection('alarms')
        .doc('active')
        .collection('vehicles')
        .get();
    for (final vehicle in vehicleDocs.docs) {
      final crewSnapshot = await vehicle.reference
          .collection('crew')
          .get();
      vehicles[vehicle.id] = crewSnapshot.docs
          .map((doc) => doc['name'] as String)
          .toList();
    }
    return vehicles;
  }
}
