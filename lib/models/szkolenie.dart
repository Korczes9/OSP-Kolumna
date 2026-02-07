import 'package:cloud_firestore/cloud_firestore.dart';

/// Typ szkolenia
enum TypSzkolenia {
  podstawowe('Podstawowe', 'basic'),
  specjalistyczne('Specjalistyczne', 'specialist'),
  kierowca('Kierowca', 'driver'),
  ratownictwo('Ratownictwo', 'rescue'),
  medyczne('Medyczne', 'medical'),
  techniczne('Techniczne', 'technical'),
  inne('Inne', 'other');

  final String nazwa;
  final String kod;
  const TypSzkolenia(this.nazwa, this.kod);

  static TypSzkolenia fromString(String str) {
    return TypSzkolenia.values.firstWhere(
      (e) => e.name == str || e.kod == str,
      orElse: () => TypSzkolenia.inne,
    );
  }
}

/// Model reprezentujący szkolenie strażaka
class Szkolenie {
  final String id;
  final String strazakId;
  final String nazwa;
  final TypSzkolenia typ;
  final DateTime dataOdbycia;
  final DateTime? dataWaznosci; // null = bezterminowe
  final String? numerCertyfikatu;
  final String? instytucja;
  final String? uwagi;

  Szkolenie({
    required this.id,
    required this.strazakId,
    required this.nazwa,
    required this.typ,
    required this.dataOdbycia,
    this.dataWaznosci,
    this.numerCertyfikatu,
    this.instytucja,
    this.uwagi,
  });

  /// Czy certyfikat jest wciąż ważny
  bool get jestWazny {
    if (dataWaznosci == null) return true;
    return dataWaznosci!.isAfter(DateTime.now());
  }

  /// Ile dni zostało do wygaśnięcia
  int? get dniDoWygasniecia {
    if (dataWaznosci == null) return null;
    return dataWaznosci!.difference(DateTime.now()).inDays;
  }

  /// Czy wymaga odnowienia (mniej niż 30 dni)
  bool get wymagaOdnowienia {
    final dni = dniDoWygasniecia;
    return dni != null && dni <= 30 && dni >= 0;
  }

  factory Szkolenie.fromMap(Map<String, dynamic> map, String id) {
    return Szkolenie(
      id: id,
      strazakId: map['strazakId'] ?? '',
      nazwa: map['nazwa'] ?? '',
      typ: TypSzkolenia.fromString(map['typ'] ?? 'inne'),
      dataOdbycia: (map['dataOdbycia'] as Timestamp).toDate(),
      dataWaznosci: map['dataWaznosci'] != null
          ? (map['dataWaznosci'] as Timestamp).toDate()
          : null,
      numerCertyfikatu: map['numerCertyfikatu'],
      instytucja: map['instytucja'],
      uwagi: map['uwagi'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'strazakId': strazakId,
      'nazwa': nazwa,
      'typ': typ.name,
      'dataOdbycia': Timestamp.fromDate(dataOdbycia),
      'dataWaznosci':
          dataWaznosci != null ? Timestamp.fromDate(dataWaznosci!) : null,
      'numerCertyfikatu': numerCertyfikatu,
      'instytucja': instytucja,
      'uwagi': uwagi,
    };
  }
}
