import 'package:cloud_firestore/cloud_firestore.dart';

/// Model wiadomości w czacie grupowym
class WiadomoscCzatu {
  final String id;
  final String uzytkownikId;
  final String uzytkownikImie;
  final String tresc;
  final DateTime dataNadania;

  WiadomoscCzatu({
    required this.id,
    required this.uzytkownikId,
    required this.uzytkownikImie,
    required this.tresc,
    required this.dataNadania,
  });

  factory WiadomoscCzatu.fromMap(Map<String, dynamic> map, String id) {
    return WiadomoscCzatu(
      id: id,
      uzytkownikId: map['uzytkownikId'] ?? '',
      uzytkownikImie: map['uzytkownikImie'] ?? 'Nieznany',
      tresc: map['tresc'] ?? '',
      dataNadania: (map['dataNadania'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uzytkownikId': uzytkownikId,
      'uzytkownikImie': uzytkownikImie,
      'tresc': tresc,
      'dataNadania': Timestamp.fromDate(dataNadania),
    };
  }
}
