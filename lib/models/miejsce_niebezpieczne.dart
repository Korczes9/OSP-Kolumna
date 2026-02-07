import 'package:cloud_firestore/cloud_firestore.dart';

enum TypZagrozenia {
  zbiornik,
  chemikalia,
  gaz,
  paliwo,
  wybuchowe,
  promieniotworcze,
  biologiczne,
  inne,
}

extension TypZagrozeniaExt on TypZagrozenia {
  String get nazwa {
    switch (this) {
      case TypZagrozenia.zbiornik:
        return 'Zbiornik';
      case TypZagrozenia.chemikalia:
        return 'Chemikalia';
      case TypZagrozenia.gaz:
        return 'Gaz';
      case TypZagrozenia.paliwo:
        return 'Paliwo';
      case TypZagrozenia.wybuchowe:
        return 'Materiały wybuchowe';
      case TypZagrozenia.promieniotworcze:
        return 'Materiały promieniotwórcze';
      case TypZagrozenia.biologiczne:
        return 'Zagrożenie biologiczne';
      case TypZagrozenia.inne:
        return 'Inne';
    }
  }
}

class MiejsceNiebezpieczne {
  final String id;
  final String nazwa;
  final String adres;
  final double szerokosc; // latitude
  final double dlugosc; // longitude
  final TypZagrozenia typ;
  final String opis;
  final String substancje; // Lista substancji niebezpiecznych
  final String procedury; // Procedury postępowania
  final String kontakt; // Numer kontaktowy do właściciela/zarządcy
  final DateTime dataAktualizacji;
  final String aktualizowalPrzez;

  MiejsceNiebezpieczne({
    required this.id,
    required this.nazwa,
    required this.adres,
    required this.szerokosc,
    required this.dlugosc,
    required this.typ,
    this.opis = '',
    this.substancje = '',
    this.procedury = '',
    this.kontakt = '',
    DateTime? dataAktualizacji,
    this.aktualizowalPrzez = '',
  }) : dataAktualizacji = dataAktualizacji ?? DateTime.now();

  factory MiejsceNiebezpieczne.fromMap(Map<String, dynamic> map, String id) {
    return MiejsceNiebezpieczne(
      id: id,
      nazwa: map['nazwa'] ?? '',
      adres: map['adres'] ?? '',
      szerokosc: (map['szerokosc'] ?? 0.0).toDouble(),
      dlugosc: (map['dlugosc'] ?? 0.0).toDouble(),
      typ: TypZagrozenia.values.firstWhere(
        (e) => e.toString() == map['typ'],
        orElse: () => TypZagrozenia.inne,
      ),
      opis: map['opis'] ?? '',
      substancje: map['substancje'] ?? '',
      procedury: map['procedury'] ?? '',
      kontakt: map['kontakt'] ?? '',
      dataAktualizacji: (map['dataAktualizacji'] as Timestamp?)?.toDate() ?? DateTime.now(),
      aktualizowalPrzez: map['aktualizowalPrzez'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nazwa': nazwa,
      'adres': adres,
      'szerokosc': szerokosc,
      'dlugosc': dlugosc,
      'typ': typ.toString(),
      'opis': opis,
      'substancje': substancje,
      'procedury': procedury,
      'kontakt': kontakt,
      'dataAktualizacji': Timestamp.fromDate(dataAktualizacji),
      'aktualizowalPrzez': aktualizowalPrzez,
    };
  }
}
