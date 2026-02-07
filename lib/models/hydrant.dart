import 'package:cloud_firestore/cloud_firestore.dart';

enum TypZrodlaWody {
  hydrantPodziemny,
  hydrantNadziemny,
  zbiornikOtwarty,
  zbiornikZamkniety,
  rzeka,
  staw,
  inny,
}

enum StatusHydranta {
  sprawny,
  uszkodzony,
  nieczynny,
  wymagaPrzegladu,
}

extension TypZrodlaWodyExt on TypZrodlaWody {
  String get nazwa {
    switch (this) {
      case TypZrodlaWody.hydrantPodziemny:
        return 'Hydrant podziemny';
      case TypZrodlaWody.hydrantNadziemny:
        return 'Hydrant nadziemny';
      case TypZrodlaWody.zbiornikOtwarty:
        return 'Zbiornik otwarty';
      case TypZrodlaWody.zbiornikZamkniety:
        return 'Zbiornik zamknięty';
      case TypZrodlaWody.rzeka:
        return 'Rzeka/strumień';
      case TypZrodlaWody.staw:
        return 'Staw/jezioro';
      case TypZrodlaWody.inny:
        return 'Inne';
    }
  }
}

extension StatusHydrantaExt on StatusHydranta {
  String get nazwa {
    switch (this) {
      case StatusHydranta.sprawny:
        return 'Sprawny';
      case StatusHydranta.uszkodzony:
        return 'Uszkodzony';
      case StatusHydranta.nieczynny:
        return 'Nieczynny';
      case StatusHydranta.wymagaPrzegladu:
        return 'Wymaga przeglądu';
    }
  }
}

class Hydrant {
  final String id;
  final String numer; // Numer identyfikacyjny
  final String lokalizacja;
  final double szerokosc;
  final double dlugosc;
  final TypZrodlaWody typ;
  final StatusHydranta status;
  final double? cisnienie; // w barach (tylko dla hydrantów)
  final int? pojemnosc; // w litrach (tylko dla zbiorników)
  final String uwagi;
  final DateTime dataOstatniegoPrzegladu;
  final DateTime? dataKolejnegoPrzegladu;
  final String? przeprowadzilPrzeglad;

  Hydrant({
    required this.id,
    required this.numer,
    required this.lokalizacja,
    required this.szerokosc,
    required this.dlugosc,
    required this.typ,
    this.status = StatusHydranta.sprawny,
    this.cisnienie,
    this.pojemnosc,
    this.uwagi = '',
    DateTime? dataOstatniegoPrzegladu,
    this.dataKolejnegoPrzegladu,
    this.przeprowadzilPrzeglad,
  }) : dataOstatniegoPrzegladu = dataOstatniegoPrzegladu ?? DateTime.now();

  factory Hydrant.fromMap(Map<String, dynamic> map, String id) {
    return Hydrant(
      id: id,
      numer: map['numer'] ?? '',
      lokalizacja: map['lokalizacja'] ?? '',
      szerokosc: (map['szerokosc'] ?? 0.0).toDouble(),
      dlugosc: (map['dlugosc'] ?? 0.0).toDouble(),
      typ: TypZrodlaWody.values.firstWhere(
        (e) => e.toString() == map['typ'],
        orElse: () => TypZrodlaWody.hydrantPodziemny,
      ),
      status: StatusHydranta.values.firstWhere(
        (e) => e.toString() == map['status'],
        orElse: () => StatusHydranta.sprawny,
      ),
      cisnienie: map['cisnienie']?.toDouble(),
      pojemnosc: map['pojemnosc']?.toInt(),
      uwagi: map['uwagi'] ?? '',
      dataOstatniegoPrzegladu: (map['dataOstatniegoPrzegladu'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dataKolejnegoPrzegladu: (map['dataKolejnegoPrzegladu'] as Timestamp?)?.toDate(),
      przeprowadzilPrzeglad: map['przeprowadzilPrzeglad'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'numer': numer,
      'lokalizacja': lokalizacja,
      'szerokosc': szerokosc,
      'dlugosc': dlugosc,
      'typ': typ.toString(),
      'status': status.toString(),
      'cisnienie': cisnienie,
      'pojemnosc': pojemnosc,
      'uwagi': uwagi,
      'dataOstatniegoPrzegladu': Timestamp.fromDate(dataOstatniegoPrzegladu),
      'dataKolejnegoPrzegladu': dataKolejnegoPrzegladu != null 
          ? Timestamp.fromDate(dataKolejnegoPrzegladu!) 
          : null,
      'przeprowadzilPrzeglad': przeprowadzilPrzeglad,
    };
  }

  bool get wymagaPrzegladu {
    if (dataKolejnegoPrzegladu == null) return false;
    return DateTime.now().isAfter(dataKolejnegoPrzegladu!);
  }
}
