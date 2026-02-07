import 'package:cloud_firestore/cloud_firestore.dart';

enum StatusDrogi {
  zamknieta,
  ograniczenia,
  objazd,
  otwarta,
}

extension StatusDrogiExt on StatusDrogi {
  String get nazwa {
    switch (this) {
      case StatusDrogi.zamknieta:
        return 'Zamknięta';
      case StatusDrogi.ograniczenia:
        return 'Ograniczenia';
      case StatusDrogi.objazd:
        return 'Objazd';
      case StatusDrogi.otwarta:
        return 'Otwarta';
    }
  }
}

class DrogaZamknieta {
  final String id;
  final String nazwa; // Nazwa drogi/ulicy
  final String odcinek; // np. "od ul. Kościuszki do ul. Mickiewicza"
  final StatusDrogi status;
  final String powod; // Powód zamknięcia
  final String objazd; // Opis trasy objazdu
  final DateTime dataZamkniecia;
  final DateTime? dataPlanowanegoOtwarcia;
  final String kontakt; // Kontakt do zarządcy drogi
  final String uwagi;
  final DateTime dataAktualizacji;
  final String aktualizowalPrzez;

  DrogaZamknieta({
    required this.id,
    required this.nazwa,
    required this.odcinek,
    required this.status,
    this.powod = '',
    this.objazd = '',
    DateTime? dataZamkniecia,
    this.dataPlanowanegoOtwarcia,
    this.kontakt = '',
    this.uwagi = '',
    DateTime? dataAktualizacji,
    this.aktualizowalPrzez = '',
  })  : dataZamkniecia = dataZamkniecia ?? DateTime.now(),
        dataAktualizacji = dataAktualizacji ?? DateTime.now();

  factory DrogaZamknieta.fromMap(Map<String, dynamic> map, String id) {
    return DrogaZamknieta(
      id: id,
      nazwa: map['nazwa'] ?? '',
      odcinek: map['odcinek'] ?? '',
      status: StatusDrogi.values.firstWhere(
        (e) => e.toString() == map['status'],
        orElse: () => StatusDrogi.zamknieta,
      ),
      powod: map['powod'] ?? '',
      objazd: map['objazd'] ?? '',
      dataZamkniecia: (map['dataZamkniecia'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dataPlanowanegoOtwarcia: (map['dataPlanowanegoOtwarcia'] as Timestamp?)?.toDate(),
      kontakt: map['kontakt'] ?? '',
      uwagi: map['uwagi'] ?? '',
      dataAktualizacji: (map['dataAktualizacji'] as Timestamp?)?.toDate() ?? DateTime.now(),
      aktualizowalPrzez: map['aktualizowalPrzez'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nazwa': nazwa,
      'odcinek': odcinek,
      'status': status.toString(),
      'powod': powod,
      'objazd': objazd,
      'dataZamkniecia': Timestamp.fromDate(dataZamkniecia),
      'dataPlanowanegoOtwarcia': dataPlanowanegoOtwarcia != null
          ? Timestamp.fromDate(dataPlanowanegoOtwarcia!)
          : null,
      'kontakt': kontakt,
      'uwagi': uwagi,
      'dataAktualizacji': Timestamp.fromDate(dataAktualizacji),
      'aktualizowalPrzez': aktualizowalPrzez,
    };
  }
}
