import 'package:cloud_firestore/cloud_firestore.dart';

enum TypCBRN {
  chemiczny,
  biologiczny,
  radiologiczny,
  nuklearny,
}

extension TypCBRNExt on TypCBRN {
  String get nazwa {
    switch (this) {
      case TypCBRN.chemiczny:
        return 'Chemiczny (C)';
      case TypCBRN.biologiczny:
        return 'Biologiczny (B)';
      case TypCBRN.radiologiczny:
        return 'Radiologiczny (R)';
      case TypCBRN.nuklearny:
        return 'Nuklearny (N)';
    }
  }

  String get skrot {
    switch (this) {
      case TypCBRN.chemiczny:
        return 'C';
      case TypCBRN.biologiczny:
        return 'B';
      case TypCBRN.radiologiczny:
        return 'R';
      case TypCBRN.nuklearny:
        return 'N';
    }
  }
}

class KartaCBRN {
  final String id;
  final String nazwaSubstancji;
  final TypCBRN typ;
  final String numerUN; // Numer UN substancji
  final String wzorChemiczny;
  final String wlasciwosciFizyczne;
  final String zagrozenia; // Opis zagrożeń
  final String objawy; // Objawy zatrucia/skażenia
  final String srodkiOchrony; // Środki ochrony indywidualnej
  final String pierwszaPomoc;
  final String neutralizacja; // Metody neutralizacji
  final String dekontaminacja;
  final String proceduraEwakuacji;
  final String strefaBezpieczenstwa; // Minimalna strefa bezpieczeństwa w metrach
  final String kontaktAwaryjny; // Numery alarmowe
  final DateTime dataAktualizacji;
  final String aktualizowalPrzez;

  KartaCBRN({
    required this.id,
    required this.nazwaSubstancji,
    required this.typ,
    this.numerUN = '',
    this.wzorChemiczny = '',
    this.wlasciwosciFizyczne = '',
    this.zagrozenia = '',
    this.objawy = '',
    this.srodkiOchrony = '',
    this.pierwszaPomoc = '',
    this.neutralizacja = '',
    this.dekontaminacja = '',
    this.proceduraEwakuacji = '',
    this.strefaBezpieczenstwa = '',
    this.kontaktAwaryjny = '',
    DateTime? dataAktualizacji,
    this.aktualizowalPrzez = '',
  }) : dataAktualizacji = dataAktualizacji ?? DateTime.now();

  factory KartaCBRN.fromMap(Map<String, dynamic> map, String id) {
    return KartaCBRN(
      id: id,
      nazwaSubstancji: map['nazwaSubstancji'] ?? '',
      typ: TypCBRN.values.firstWhere(
        (e) => e.toString() == map['typ'],
        orElse: () => TypCBRN.chemiczny,
      ),
      numerUN: map['numerUN'] ?? '',
      wzorChemiczny: map['wzorChemiczny'] ?? '',
      wlasciwosciFizyczne: map['wlasciwosciFizyczne'] ?? '',
      zagrozenia: map['zagrozenia'] ?? '',
      objawy: map['objawy'] ?? '',
      srodkiOchrony: map['srodkiOchrony'] ?? '',
      pierwszaPomoc: map['pierwszaPomoc'] ?? '',
      neutralizacja: map['neutralizacja'] ?? '',
      dekontaminacja: map['dekontaminacja'] ?? '',
      proceduraEwakuacji: map['proceduraEwakuacji'] ?? '',
      strefaBezpieczenstwa: map['strefaBezpieczenstwa'] ?? '',
      kontaktAwaryjny: map['kontaktAwaryjny'] ?? '',
      dataAktualizacji: (map['dataAktualizacji'] as Timestamp?)?.toDate() ?? DateTime.now(),
      aktualizowalPrzez: map['aktualizowalPrzez'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nazwaSubstancji': nazwaSubstancji,
      'typ': typ.toString(),
      'numerUN': numerUN,
      'wzorChemiczny': wzorChemiczny,
      'wlasciwosciFizyczne': wlasciwosciFizyczne,
      'zagrozenia': zagrozenia,
      'objawy': objawy,
      'srodkiOchrony': srodkiOchrony,
      'pierwszaPomoc': pierwszaPomoc,
      'neutralizacja': neutralizacja,
      'dekontaminacja': dekontaminacja,
      'proceduraEwakuacji': proceduraEwakuacji,
      'strefaBezpieczenstwa': strefaBezpieczenstwa,
      'kontaktAwaryjny': kontaktAwaryjny,
      'dataAktualizacji': Timestamp.fromDate(dataAktualizacji),
      'aktualizowalPrzez': aktualizowalPrzez,
    };
  }
}
