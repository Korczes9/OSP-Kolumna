import 'package:cloud_firestore/cloud_firestore.dart';

/// Model zgłoszenia problemu w aplikacji
class ZgloszeniProblemu {
  final String id;
  final String uzytkownikId;
  final String uzytkownikImie;
  final String opis;
  final String? screenshotUrl;
  final DateTime dataZgloszenia;
  final String status; // 'nowe', 'w_trakcie', 'rozwiazane'

  ZgloszeniProblemu({
    required this.id,
    required this.uzytkownikId,
    required this.uzytkownikImie,
    required this.opis,
    this.screenshotUrl,
    required this.dataZgloszenia,
    this.status = 'nowe',
  });

  factory ZgloszeniProblemu.fromMap(Map<String, dynamic> map, String id) {
    return ZgloszeniProblemu(
      id: id,
      uzytkownikId: map['uzytkownikId'] ?? '',
      uzytkownikImie: map['uzytkownikImie'] ?? '',
      opis: map['opis'] ?? '',
      screenshotUrl: map['screenshotUrl'],
      dataZgloszenia: (map['dataZgloszenia'] as Timestamp).toDate(),
      status: map['status'] ?? 'nowe',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uzytkownikId': uzytkownikId,
      'uzytkownikImie': uzytkownikImie,
      'opis': opis,
      'screenshotUrl': screenshotUrl,
      'dataZgloszenia': Timestamp.fromDate(dataZgloszenia),
      'status': status,
    };
  }
}
