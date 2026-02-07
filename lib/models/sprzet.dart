import 'package:cloud_firestore/cloud_firestore.dart';

/// Kategoria sprzętu
enum KategoriaSprzetu {
  ochrone('Odzież ochronna', 'clothing'),
  respiratory('Respiratory i maski', 'respiratory'),
  weze('Węże i prądownice', 'hoses'),
  narzedzia('Narzędzia', 'tools'),
  elektronika('Elektronika', 'electronics'),
  medyczne('Sprzęt medyczny', 'medical'),
  inne('Inne', 'other');

  final String nazwa;
  final String kod;
  const KategoriaSprzetu(this.nazwa, this.kod);

  static KategoriaSprzetu fromString(String str) {
    return KategoriaSprzetu.values.firstWhere(
      (e) => e.name == str || e.kod == str,
      orElse: () => KategoriaSprzetu.inne,
    );
  }
}

/// Status sprzętu
enum StatusSprzetu {
  sprawny('Sprawny', 'operational'),
  niesprawny('Niesprawny', 'broken'),
  wPrzeglad('W przeglądzie', 'maintenance'),
  wycofany('Wycofany', 'retired');

  final String nazwa;
  final String kod;
  const StatusSprzetu(this.nazwa, this.kod);

  static StatusSprzetu fromString(String str) {
    return StatusSprzetu.values.firstWhere(
      (e) => e.name == str || e.kod == str,
      orElse: () => StatusSprzetu.sprawny,
    );
  }
}

/// Model reprezentujący sprzęt
class Sprzet {
  final String id;
  final String nazwa;
  final KategoriaSprzetu kategoria;
  final StatusSprzetu status;
  final String? numerSeryjny;
  final String? numerInwentarzowy;
  final DateTime? dataZakupu;
  final DateTime? dataOstatniegoPrzegladu;
  final DateTime? dataNastepnegoPrzegladu;
  final String? przypisanyDoStrazaka; // ID strażaka
  final String? lokalizacja;
  final String? producent;
  final String? uwagi;

  Sprzet({
    required this.id,
    required this.nazwa,
    required this.kategoria,
    this.status = StatusSprzetu.sprawny,
    this.numerSeryjny,
    this.numerInwentarzowy,
    this.dataZakupu,
    this.dataOstatniegoPrzegladu,
    this.dataNastepnegoPrzegladu,
    this.przypisanyDoStrazaka,
    this.lokalizacja,
    this.producent,
    this.uwagi,
  });

  /// Czy przegląd jest aktualny
  bool get przegladJestAktualny {
    if (dataNastepnegoPrzegladu == null) return true;
    return dataNastepnegoPrzegladu!.isAfter(DateTime.now());
  }

  /// Ile dni do przeglądu
  int? get dniDoPrzegladu {
    if (dataNastepnegoPrzegladu == null) return null;
    return dataNastepnegoPrzegladu!.difference(DateTime.now()).inDays;
  }

  /// Czy wymaga przeglądu wkrótce (mniej niż 14 dni)
  bool get wymagaPrzegladu {
    final dni = dniDoPrzegladu;
    return dni != null && dni <= 14 && dni >= 0;
  }

  factory Sprzet.fromMap(Map<String, dynamic> map, String id) {
    return Sprzet(
      id: id,
      nazwa: map['nazwa'] ?? '',
      kategoria: KategoriaSprzetu.fromString(map['kategoria'] ?? 'inne'),
      status: StatusSprzetu.fromString(map['status'] ?? 'sprawny'),
      numerSeryjny: map['numerSeryjny'],
      numerInwentarzowy: map['numerInwentarzowy'],
      dataZakupu: map['dataZakupu'] != null
          ? (map['dataZakupu'] as Timestamp).toDate()
          : null,
      dataOstatniegoPrzegladu: map['dataOstatniegoPrzegladu'] != null
          ? (map['dataOstatniegoPrzegladu'] as Timestamp).toDate()
          : null,
      dataNastepnegoPrzegladu: map['dataNastepnegoPrzegladu'] != null
          ? (map['dataNastepnegoPrzegladu'] as Timestamp).toDate()
          : null,
      przypisanyDoStrazaka: map['przypisanyDoStrazaka'],
      lokalizacja: map['lokalizacja'],
      producent: map['producent'],
      uwagi: map['uwagi'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nazwa': nazwa,
      'kategoria': kategoria.name,
      'status': status.name,
      'numerSeryjny': numerSeryjny,
      'numerInwentarzowy': numerInwentarzowy,
      'dataZakupu': dataZakupu != null ? Timestamp.fromDate(dataZakupu!) : null,
      'dataOstatniegoPrzegladu': dataOstatniegoPrzegladu != null
          ? Timestamp.fromDate(dataOstatniegoPrzegladu!)
          : null,
      'dataNastepnegoPrzegladu': dataNastepnegoPrzegladu != null
          ? Timestamp.fromDate(dataNastepnegoPrzegladu!)
          : null,
      'przypisanyDoStrazaka': przypisanyDoStrazaka,
      'lokalizacja': lokalizacja,
      'producent': producent,
      'uwagi': uwagi,
    };
  }
}
