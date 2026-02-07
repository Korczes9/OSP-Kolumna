import 'package:cloud_firestore/cloud_firestore.dart';

/// Model reprezentujący potwierdzenie uczestnictwa w wyjeździe
class PotwierdzeniePrzybycia {
  final String id;
  final String wyjazdId;
  final String strazakId;
  final DateTime czasPotwierdzenia;
  final bool przybycie; // true = jadę, false = nie mogę
  final String? powod; // Powód jeśli nie może jechać

  PotwierdzeniePrzybycia({
    required this.id,
    required this.wyjazdId,
    required this.strazakId,
    required this.czasPotwierdzenia,
    this.przybycie = true,
    this.powod,
  });

  factory PotwierdzeniePrzybycia.fromMap(Map<String, dynamic> map, String id) {
    return PotwierdzeniePrzybycia(
      id: id,
      wyjazdId: map['wyjazdId'] ?? '',
      strazakId: map['strazakId'] ?? '',
      czasPotwierdzenia: (map['czasPotwierdzenia'] as Timestamp).toDate(),
      przybycie: map['przybycie'] ?? true,
      powod: map['powod'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'wyjazdId': wyjazdId,
      'strazakId': strazakId,
      'czasPotwierdzenia': Timestamp.fromDate(czasPotwierdzenia),
      'przybycie': przybycie,
      'powod': powod,
    };
  }
}

/// Model reprezentujący zdjęcie z wyjazdu
class ZdjecieWyjazdu {
  final String id;
  final String wyjazdId;
  final String urlZdjecia;
  final String? opis;
  final DateTime dataZdjecia;
  final String? dodanePrzez; // ID strażaka

  ZdjecieWyjazdu({
    required this.id,
    required this.wyjazdId,
    required this.urlZdjecia,
    this.opis,
    required this.dataZdjecia,
    this.dodanePrzez,
  });

  factory ZdjecieWyjazdu.fromMap(Map<String, dynamic> map, String id) {
    return ZdjecieWyjazdu(
      id: id,
      wyjazdId: map['wyjazdId'] ?? '',
      urlZdjecia: map['urlZdjecia'] ?? '',
      opis: map['opis'],
      dataZdjecia: (map['dataZdjecia'] as Timestamp).toDate(),
      dodanePrzez: map['dodanePrzez'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'wyjazdId': wyjazdId,
      'urlZdjecia': urlZdjecia,
      'opis': opis,
      'dataZdjecia': Timestamp.fromDate(dataZdjecia),
      'dodanePrzez': dodanePrzez,
    };
  }
}

/// Model reprezentujący statystyki strażaka
class StatystykiStrazaka {
  final String strazakId;
  final int liczbaWyjazdow;
  final int sumaGodzin;
  final int sumaEkwiwalentu;
  final DateTime okresOd;
  final DateTime okresDo;
  final Map<String, int> wyjazdyPoKategorii; // kategoria -> liczba

  StatystykiStrazaka({
    required this.strazakId,
    required this.liczbaWyjazdow,
    required this.sumaGodzin,
    required this.sumaEkwiwalentu,
    required this.okresOd,
    required this.okresDo,
    required this.wyjazdyPoKategorii,
  });

  /// Średnia liczba godzin na wyjazd
  double get sredniaGodzinNaWyjazd =>
      liczbaWyjazdow > 0 ? sumaGodzin / liczbaWyjazdow : 0.0;

  /// Średni ekwiwalent na wyjazd
  double get sredniEkwiwalentNaWyjazd =>
      liczbaWyjazdow > 0 ? sumaEkwiwalentu / liczbaWyjazdow : 0.0;
}
