import 'package:cloud_firestore/cloud_firestore.dart';

/// Kategorie wyjazdów
enum KategoriaWyjazdu {
  miejscoweZagrozenie('Miejscowe zagrożenie'),
  pozar('Pożar'),
  alarmFalszywy('Alarm Fałszywy'),
  zabezpieczenieRejonu('Zabezpieczenie rejonu'),
  cwiczenia('Ćwiczenia'),
  zPoleceniaBurmistrza('Z polecenia Burmistrza');

  final String nazwa;
  const KategoriaWyjazdu(this.nazwa);

  static KategoriaWyjazdu fromString(String str) {
    return KategoriaWyjazdu.values.firstWhere(
      (e) => e.name == str,
      orElse: () => KategoriaWyjazdu.miejscoweZagrozenie,
    );
  }
}

/// Status wyjazdu
enum StatusWyjazdu {
  oczekujacy('Oczekujący'),
  wTrakcie('W trakcie'),
  zakonczony('Zakończony'),
  anulowany('Anulowany');

  final String nazwa;
  const StatusWyjazdu(this.nazwa);

  static StatusWyjazdu fromString(String str) {
    return StatusWyjazdu.values.firstWhere(
      (e) => e.name == str,
      orElse: () => StatusWyjazdu.oczekujacy,
    );
  }
}

/// Model reprezentujący wyjazd strażacki
class Wyjazd {
  final String id;
  final KategoriaWyjazdu kategoria;
  final StatusWyjazdu status;
  final String lokalizacja;
  final String opis;
  final DateTime dataWyjazdu;
  final DateTime? dataZakonczenia;
  final DateTime? godzinaRozpoczecia; // Nowe
  final DateTime? godzinaZakonczenia; // Nowe
  final String utworzonePrzez; // ID strażaka
  final String? dowodcaId; // ID dowódcy wyjazdu
  final List<String> strazacyIds; // Lista ID strażaków (dla wstecznej kompatybilności)
  final String? wozId; // ID wozu (dla wstecznej kompatybilności)
  
  // NOWE: Obsługa dwóch wozów
  final String? woz1Id; // ID pierwszego wozu
  final String? woz2Id; // ID drugiego wozu
  final List<String> woz1StrazacyIds; // Strażacy przydzieleni do wozu 1
  final List<String> woz2StrazacyIds; // Strażacy przydzieleni do wozu 2
  
  final String? uwagi;
  final bool potwierdzony; // Potwierdzony przez Administratora
  final String? potwierdzonyPrzez; // ID potwierdzającego
  final DateTime? dataPotwierdzenia;

  Wyjazd({
    required this.id,
    required this.kategoria,
    required this.status,
    required this.lokalizacja,
    required this.opis,
    required this.dataWyjazdu,
    this.dataZakonczenia,
    this.godzinaRozpoczecia,
    this.godzinaZakonczenia,
    required this.utworzonePrzez,
    this.dowodcaId,
    this.strazacyIds = const [],
    this.wozId,
    this.woz1Id,
    this.woz2Id,
    this.woz1StrazacyIds = const [],
    this.woz2StrazacyIds = const [],
    this.uwagi,
    this.potwierdzony = false,
    this.potwierdzonyPrzez,
    this.dataPotwierdzenia,
  });
  
  /// Oblicza czas trwania w minutach
  int get czasTrwaniaMinuty {
    if (godzinaRozpoczecia == null || godzinaZakonczenia == null) return 0;
    return godzinaZakonczenia!.difference(godzinaRozpoczecia!).inMinutes;
  }
  
  /// Oblicza czas trwania zaokrąglony do pełnej godziny w górę
  int get czasTrwaniaGodzinyZaokraglone {
    final minuty = czasTrwaniaMinuty;
    if (minuty == 0) return 0;
    return (minuty / 60).ceil(); // Zaokrąglenie w górę
  }
  
  /// Zwraca sformatowany czas trwania jako "X godz. Y min"
  String get czasTrwaniaSformatowany {
    final minuty = czasTrwaniaMinuty;
    if (minuty == 0) return '0 min';
    
    final godziny = minuty ~/ 60;
    final pozostaleMinuty = minuty % 60;
    
    if (godziny == 0) {
      return '$pozostaleMinuty min';
    } else if (pozostaleMinuty == 0) {
      return '$godziny godz.';
    } else {
      return '$godziny godz. $pozostaleMinuty min';
    }
  }
  
  /// Oblicza ekwiwalent na podstawie kategorii
  double get ekwiwalent {
    final godziny = czasTrwaniaGodzinyZaokraglone;
    if (godziny == 0) return 0.0;
    
    double stawka = 0.0;
    switch (kategoria) {
      case KategoriaWyjazdu.pozar:
      case KategoriaWyjazdu.miejscoweZagrozenie:
      case KategoriaWyjazdu.alarmFalszywy:
        stawka = 19.0;
        break;
      case KategoriaWyjazdu.zabezpieczenieRejonu:
      case KategoriaWyjazdu.zPoleceniaBurmistrza:
        stawka = 9.0;
        break;
      case KategoriaWyjazdu.cwiczenia:
        stawka = 6.0;
        break;
    }
    
    return godziny * stawka;
  }

  /// Tworzy obiekt Wyjazd z mapy (Firestore)
  factory Wyjazd.fromMap(Map<String, dynamic> map, String id) {
    return Wyjazd(
      id: id,
      kategoria: KategoriaWyjazdu.fromString(map['kategoria'] ?? 'miejscoweZagrozenie'),
      status: StatusWyjazdu.fromString(map['status'] ?? 'oczekujacy'),
      lokalizacja: map['lokalizacja'] ?? '',
      opis: map['opis'] ?? '',
      dataWyjazdu: (map['dataWyjazdu'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dataZakonczenia: (map['dataZakonczenia'] as Timestamp?)?.toDate(),
      godzinaRozpoczecia: (map['godzinaRozpoczecia'] as Timestamp?)?.toDate(),
      godzinaZakonczenia: (map['godzinaZakonczenia'] as Timestamp?)?.toDate(),
      utworzonePrzez: map['utworzonePrzez'] ?? '',
      dowodcaId: map['dowodcaId'],
      strazacyIds: List<String>.from(map['strazacyIds'] ?? []),
      wozId: map['wozId'],
      woz1Id: map['woz1Id'],
      woz2Id: map['woz2Id'],
      woz1StrazacyIds: List<String>.from(map['woz1StrazacyIds'] ?? []),
      woz2StrazacyIds: List<String>.from(map['woz2StrazacyIds'] ?? []),
      uwagi: map['uwagi'],
      potwierdzony: map['potwierdzony'] ?? false,
      potwierdzonyPrzez: map['potwierdzonyPrzez'],
      dataPotwierdzenia: (map['dataPotwierdzenia'] as Timestamp?)?.toDate(),
    );
  }

  /// Konwertuje obiekt Wyjazd do mapy (Firestore)
  Map<String, dynamic> toMap() {
    return {
      'kategoria': kategoria.name,
      'status': status.name,
      'lokalizacja': lokalizacja,
      'opis': opis,
      'dataWyjazdu': Timestamp.fromDate(dataWyjazdu),
      'dataZakonczenia': dataZakonczenia != null ? Timestamp.fromDate(dataZakonczenia!) : null,
      'godzinaRozpoczecia': godzinaRozpoczecia != null ? Timestamp.fromDate(godzinaRozpoczecia!) : null,
      'godzinaZakonczenia': godzinaZakonczenia != null ? Timestamp.fromDate(godzinaZakonczenia!) : null,
      'utworzonePrzez': utworzonePrzez,
      'dowodcaId': dowodcaId,
      'strazacyIds': strazacyIds,
      'wozId': wozId,
      'woz1Id': woz1Id,
      'woz2Id': woz2Id,
      'woz1StrazacyIds': woz1StrazacyIds,
      'woz2StrazacyIds': woz2StrazacyIds,
      'uwagi': uwagi,
      'potwierdzony': potwierdzony,
      'potwierdzonyPrzez': potwierdzonyPrzez,
      'dataPotwierdzenia': dataPotwierdzenia != null ? Timestamp.fromDate(dataPotwierdzenia!) : null,
    };
  }

  /// Kopia z nowymi wartościami
  Wyjazd copyWith({
    String? id,
    KategoriaWyjazdu? kategoria,
    StatusWyjazdu? status,
    String? lokalizacja,
    String? opis,
    DateTime? dataWyjazdu,
    DateTime? dataZakonczenia,
    String? utworzonePrzez,
    String? dowodcaId,
    List<String>? strazacyIds,
    String? wozId,
    String? uwagi,
    bool? potwierdzony,
    String? potwierdzonyPrzez,
    DateTime? dataPotwierdzenia,
  }) {
    return Wyjazd(
      id: id ?? this.id,
      kategoria: kategoria ?? this.kategoria,
      status: status ?? this.status,
      lokalizacja: lokalizacja ?? this.lokalizacja,
      opis: opis ?? this.opis,
      dataWyjazdu: dataWyjazdu ?? this.dataWyjazdu,
      dataZakonczenia: dataZakonczenia ?? this.dataZakonczenia,
      utworzonePrzez: utworzonePrzez ?? this.utworzonePrzez,
      dowodcaId: dowodcaId ?? this.dowodcaId,
      strazacyIds: strazacyIds ?? this.strazacyIds,
      wozId: wozId ?? this.wozId,
      uwagi: uwagi ?? this.uwagi,
      potwierdzony: potwierdzony ?? this.potwierdzony,
      potwierdzonyPrzez: potwierdzonyPrzez ?? this.potwierdzonyPrzez,
      dataPotwierdzenia: dataPotwierdzenia ?? this.dataPotwierdzenia,
    );
  }

  /// Czy wyjazd jest aktywny
  bool get jestAktywny => status == StatusWyjazdu.wTrakcie || status == StatusWyjazdu.oczekujacy;
}
