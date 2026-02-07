/// Role strażaków
enum RolaStrazaka {
  administrator('Administrator', 5), // Najwyższa rola - może wszystko
  pro('Pro', 4), // Dostęp do wyjazdów w powiecie i zaawansowanych funkcji
  gospodarz('Gospodarz', 3), // Może rezerwować salę, zarządzać wydarzeniami
  moderator('Moderator', 2), // Może edytować wyjazdy, kalendarz, strażaków, samochody
  dowodca('Dowódca', 2), // Może tworzyć i edytować wyjazdy
  strazak('Strażak', 1); // Podstawowa rola - tylko podgląd

  final String nazwa;
  final int poziom;
  const RolaStrazaka(this.nazwa, this.poziom);

  static RolaStrazaka fromString(String str) {
    return RolaStrazaka.values.firstWhere(
      (e) => e.name == str,
      orElse: () => RolaStrazaka.strazak,
    );
  }
}

/// Model reprezentujący strażaka
class Strazak {
  final String id;
  final String imie;
  final String nazwisko;
  final String email;
  final String numerTelefonu;
  final List<RolaStrazaka> role; // ZMIANA: lista ról zamiast pojedynczej
  final bool aktywny;
  final DateTime dataRejestracji;
  final bool dostepny; // Czy strażak jest dostępny do wyjazdu
  final DateTime? ostatniaZmianaStatusu; // Kiedy zmieniono dostępność
  final DateTime? ostatnioAktywny; // Kiedy ostatnio był online

  Strazak({
    required this.id,
    required this.imie,
    required this.nazwisko,
    required this.email,
    required this.numerTelefonu,
    List<RolaStrazaka>? role,
    this.aktywny = true,
    DateTime? dataRejestracji,
    this.dostepny = false,
    this.ostatniaZmianaStatusu,
    this.ostatnioAktywny,
  })  : role = role ?? [RolaStrazaka.strazak],
        dataRejestracji = dataRejestracji ?? DateTime.now();

  /// Tworzy obiekt Strazak z mapy (np. z Firestore)
  factory Strazak.fromMap(Map<String, dynamic> map, String id) {
    // Obsługa starych danych (pojedyncza rola) i nowych (lista ról)
    List<RolaStrazaka> parsedRoles = [];
    
    if (map['role'] != null && map['role'] is List) {
      // Nowy format - lista ról
      parsedRoles = (map['role'] as List)
          .map((r) => RolaStrazaka.fromString(r.toString()))
          .toList();
    } else if (map['rola'] != null) {
      // Stary format - pojedyncza rola (backward compatibility)
      parsedRoles = [RolaStrazaka.fromString(map['rola'])];
    } else {
      parsedRoles = [RolaStrazaka.strazak];
    }
    
    return Strazak(
      id: id,
      imie: map['imie'] ?? '',
      nazwisko: map['nazwisko'] ?? '',
      email: map['email'] ?? '',
      numerTelefonu: map['numerTelefonu'] ?? '',
      role: parsedRoles,
      aktywny: map['aktywny'] ?? true,
      dataRejestracji: map['dataRejestracji'] != null
          ? DateTime.parse(map['dataRejestracji'])
          : DateTime.now(),
      dostepny: map['dostepny'] ?? false,
      ostatniaZmianaStatusu: map['ostatniaZmianaStatusu'] != null
          ? DateTime.parse(map['ostatniaZmianaStatusu'])
          : null,
      ostatnioAktywny: map['ostatnioAktywny'] != null
          ? DateTime.parse(map['ostatnioAktywny'])
          : null,
    );
  }

  /// Konwertuje obiekt Strazak do mapy (do zapisu w Firestore)
  Map<String, dynamic> toMap() {
    return {
      'imie': imie,
      'nazwisko': nazwisko,
      'email': email,
      'numerTelefonu': numerTelefonu,
      'role': role.map((r) => r.name).toList(), // Zapisz jako listę
      'aktywny': aktywny,
      'dataRejestracji': dataRejestracji.toIso8601String(),
      'dostepny': dostepny,
      'ostatniaZmianaStatusu': ostatniaZmianaStatusu?.toIso8601String(),
      'ostatnioAktywny': ostatnioAktywny?.toIso8601String(),
    };
  }

  /// Pełne imię i nazwisko
  String get pelneImie => '$imie $nazwisko';

  /// Główna rola (najwyższa w hierarchii)
  RolaStrazaka get rola => role.reduce((a, b) => a.poziom > b.poziom ? a : b);

  /// Czy ma daną rolę
  bool maRole(RolaStrazaka rola) => role.contains(rola);

  /// Czy strażak jest Administratorem (najwyższa rola)
  bool get jestAdministratorem => maRole(RolaStrazaka.administrator);

  /// Czy strażak jest Gospodarzem
  bool get jestGospodarzem => maRole(RolaStrazaka.gospodarz) || jestAdministratorem;

  /// Czy strażak jest Moderatorem
  bool get jestModeratorem =>
      maRole(RolaStrazaka.moderator) || jestGospodarzem || jestAdministratorem;

  /// Czy strażak jest Dowódcą
  bool get jestDowodca => maRole(RolaStrazaka.dowodca);

  /// Czy ma uprawnienia do edycji wszystkiego (Administrator)
  bool get czyMozeEdytowac => jestAdministratorem;

  /// Czy ma rolę Pro (dostęp do wyjazdów w powiecie)
  bool get jestPro => maRole(RolaStrazaka.pro) || jestAdministratorem;

  /// Czy może edytować wyjazdy, kalendarz, strażaków, samochody (Moderator+)
  bool get czyMozeDodawacWyjazdy => jestModeratorem || jestDowodca;

  /// Czy może edytować strażaków (Moderator+)
  bool get czyMozeEdytowacStrazakow => jestModeratorem;

  /// Czy może rezerwować salę (Gospodarz+)
  bool get czyMozeRezerwowacSale => jestGospodarzem;

  /// Czy może edytować samochody (Moderator+)
  bool get czyMozeEdytowacSamochody => jestModeratorem;

  /// Czy użytkownik jest obecnie online (aktywny w ostatnich 5 minutach)
  bool get jestOnline {
    if (ostatnioAktywny == null) return false;
    final roznica = DateTime.now().difference(ostatnioAktywny!);
    return roznica.inMinutes < 5;
  }

  /// Opis statusu online/offline
  String get statusOnline {
    if (jestOnline) return 'Online';
    if (ostatnioAktywny == null) return 'Nigdy nie był online';
    
    final roznica = DateTime.now().difference(ostatnioAktywny!);
    if (roznica.inMinutes < 60) {
      return '${roznica.inMinutes} min temu';
    } else if (roznica.inHours < 24) {
      return '${roznica.inHours} godz. temu';
    } else if (roznica.inDays < 7) {
      return '${roznica.inDays} dni temu';
    } else {
      return '${ostatnioAktywny!.day}.${ostatnioAktywny!.month}.${ostatnioAktywny!.year}';
    }
  }

  /// Czy może edytować kalendarz (Moderator+)
  bool get czyMozeEdytowacKalendarz => jestModeratorem;
}
