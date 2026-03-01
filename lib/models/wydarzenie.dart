import 'package:cloud_firestore/cloud_firestore.dart';

/// Typy wydarzeń w terminarzu
enum TypWydarzenia {
  szkolenie('Szkolenie', 'training'),
  cwiczenia('Ćwiczenia', 'exercise'),
  zebranie('Zebranie', 'meeting'),
  swieto('Święto OSP', 'celebration'),
  rezerwacjaSali('Rezerwacja sali', 'room'),
  inne('Inne', 'other');

  final String nazwa;
  final String ikona;
  const TypWydarzenia(this.nazwa, this.ikona);

  static TypWydarzenia fromString(String str) {
    return TypWydarzenia.values.firstWhere(
      (e) => e.name == str,
      orElse: () => TypWydarzenia.inne,
    );
  }
}

/// Model wydarzenia w terminarzu
class Wydarzenie {
  final String id;
  final String tytul;
  final String? opis;
  final DateTime dataRozpoczecia;
  final DateTime? dataZakonczenia;
  final TypWydarzenia typ;
  final String? lokalizacja;
  final String utworzonePrzez; // ID strażaka
  final DateTime dataUtworzenia;
  final List<String> uczestnicyIds; // Lista ID strażaków zapisanych na wydarzenie
  final List<String> nieBedzieIds; // Lista ID strażaków, którzy oznaczyli, że ich nie będzie
  final List<String> jeszczeNieWiemIds; // Lista ID strażaków, którzy jeszcze nie wiedzą
  final bool widoczneDlaWszystkich; // true = wszyscy, false = tylko gospodarz+

  Wydarzenie({
    required this.id,
    required this.tytul,
    this.opis,
    required this.dataRozpoczecia,
    this.dataZakonczenia,
    required this.typ,
    this.lokalizacja,
    required this.utworzonePrzez,
    required this.dataUtworzenia,
    this.uczestnicyIds = const [],
    this.nieBedzieIds = const [],
    this.jeszczeNieWiemIds = const [],
    this.widoczneDlaWszystkich = true,
  });

  factory Wydarzenie.fromMap(Map<String, dynamic> map, String id) {
    return Wydarzenie(
      id: id,
      tytul: map['tytul'] ?? '',
      opis: map['opis'],
      dataRozpoczecia: (map['dataRozpoczecia'] as Timestamp).toDate(),
      dataZakonczenia: map['dataZakonczenia'] != null
          ? (map['dataZakonczenia'] as Timestamp).toDate()
          : null,
      typ: TypWydarzenia.fromString(map['typ'] ?? 'inne'),
      lokalizacja: map['lokalizacja'],
      utworzonePrzez: map['utworzonePrzez'] ?? '',
      dataUtworzenia: (map['dataUtworzenia'] as Timestamp).toDate(),
      uczestnicyIds: List<String>.from(map['uczestnicyIds'] ?? []),
      nieBedzieIds: List<String>.from(map['nieBedzieIds'] ?? []),
      jeszczeNieWiemIds: List<String>.from(map['jeszczeNieWiemIds'] ?? []),
      widoczneDlaWszystkich: map['widoczneDlaWszystkich'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tytul': tytul,
      'opis': opis,
      'dataRozpoczecia': Timestamp.fromDate(dataRozpoczecia),
      'dataZakonczenia': dataZakonczenia != null
          ? Timestamp.fromDate(dataZakonczenia!)
          : null,
      'typ': typ.name,
      'lokalizacja': lokalizacja,
      'utworzonePrzez': utworzonePrzez,
      'dataUtworzenia': Timestamp.fromDate(dataUtworzenia),
      'uczestnicyIds': uczestnicyIds,
      'nieBedzieIds': nieBedzieIds,
      'jeszczeNieWiemIds': jeszczeNieWiemIds,
      'widoczneDlaWszystkich': widoczneDlaWszystkich,
    };
  }
}
