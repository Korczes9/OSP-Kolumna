import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/pdf_service.dart';

class ReportScreen extends StatelessWidget {
  final String reportId;

  const ReportScreen({super.key, required this.reportId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Karta wyjazdu')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .doc(reportId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nr wyjazdu: ${data['number']}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Typ: ${data['type']}'),
                Text('Adres: ${data['address']}'),
                Text('Start: ${data['startTime']}'),
                Text('Koniec: ${data['endTime'] ?? 'w trakcie'}'),
                ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('EKSPORT PDF'),
                  onPressed: () {
                    PdfService.generateReportPdf(
                      number: data['number'],
                      type: data['type'],
                      address: data['address'],
                      start: data['startTime'].toString(),
                      end: data['endTime']?.toString() ?? 'w trakcie',
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
