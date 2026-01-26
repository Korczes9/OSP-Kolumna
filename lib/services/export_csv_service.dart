import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';

class ExportCsvService {
  static Future<void> exportReportsCsv() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('reports').get();

    final rows = <List<String>>[
      ['Nr', 'Typ', 'Adres', 'Start', 'Koniec'],
    ];

    for (final doc in snapshot.docs) {
      final d = doc.data();
      rows.add([
        d['number'] ?? '',
        d['type'] ?? '',
        d['address'] ?? '',
        d['startTime']?.toString() ?? '',
        d['endTime']?.toString() ?? '',
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);

    await Printing.sharePdf(
      bytes: Uint8List.fromList(csv.codeUnits),
      filename: 'osp_kolumna_wyjazdy.csv',
    );
  }
}
