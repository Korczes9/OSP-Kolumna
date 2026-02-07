import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Klient API eRemiza - synchronizacja alarmów
/// Działa w darmowym planie Firebase (bez Cloud Functions)
class EremizaService {
  static const String apiUrl = 'https://e-remiza.pl/Terminal';
  static const String prefKeyEmail = 'eremiza_email';
  static const String prefKeyPassword = 'eremiza_password';
  static const String prefKeyLastSync = 'eremiza_last_sync';
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _email;
  String? _password;
  Map<String, dynamic>? _user;
  Timer? _syncTimer;

  /// Singleton
  static final EremizaService _instance = EremizaService._internal();
  factory EremizaService() => _instance;
  EremizaService._internal();

  /// Generuje JWT token dla eRemiza (base64url, algorithm: 'none')
  String _generateJWT(String email, String password) {
    // Base64 URL-safe encoding (bez padding '=')
    String base64UrlEncode(String input) {
      final bytes = utf8.encode(input);
      final base64 = base64Encode(bytes);
      // Zamień na URL-safe i usuń padding
      return base64
          .replaceAll('+', '-')
          .replaceAll('/', '_')
          .replaceAll('=', '');
    }

    final headerMap = {
      'alg': 'none',
      'typ': 'JWT'
    };
    
    final payloadMap = {
      'email': email,
      'password': password,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000
    };

    print('🔐 JWT Header: ${json.encode(headerMap)}');
    print('🔐 JWT Payload email: ${email.substring(0, 3)}***');
    print('🔐 JWT Payload iat: ${payloadMap['iat']}');

    final header = base64UrlEncode(json.encode(headerMap));
    final payload = base64UrlEncode(json.encode(payloadMap));
    final jwtToken = '$header.$payload.';  // Z KROPKĄ na końcu dla algorithm: none

    print('🔑 JWT Token length: ${jwtToken.length}');
    print('🔑 JWT parts: header=${header.length} payload=${payload.length}');
    print('🔑 JWT format: header.payload. (z kropką na końcu)');

    // JWT bez sygnatury (eRemiza wymaga algorithm: none z kropką na końcu)
    return jwtToken;
  }

  /// Wywołanie API eRemiza
  Future<dynamic> _request(String method, String endpoint, [Map<String, String>? params]) async {
    if (_email == null || _password == null) {
      throw Exception('Brak danych logowania do eRemiza. Skonfiguruj w Menu → Konfiguracja eRemiza');
    }

    final jwtToken = _generateJWT(_email!, _password!);
    var url = Uri.parse('$apiUrl$endpoint');
    
    if (params != null && params.isNotEmpty) {
      url = url.replace(queryParameters: params);
    }

    print('🌐 eRemiza request: $method $url');
    print('� Email używany: $_email');
    print('📋 JWT Header będzie wysłany w nagłówku HTTP');

    try {
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'JWT': jwtToken,
          'User-Agent': 'OSP-Kolumna-App/1.0',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Timeout - eRemiza nie odpowiada. Sprawdź połączenie internetowe.');
        },
      );

      print('📡 eRemiza response: ${response.statusCode}');
      print('📄 Response headers: ${response.headers}');

      if (response.statusCode == 400) {
        print('❌ BAD REQUEST 400');
        print('📄 Response body: ${response.body}');
        print('📋 Request URL: $url');
        print('� Email w JWT: $_email');
        print('🔑 Sent headers:');
        print('   Accept: application/json');
        print('   Content-Type: application/json');
        print('   JWT: ${jwtToken.substring(0, 50)}...');
        
        // Sprawdź czy response zawiera szczegóły błędu
        try {
          final errorData = json.decode(response.body);
          print('🔍 Parsed error: $errorData');
        } catch (_) {
          print('🔍 Raw error (not JSON): ${response.body}');
        }
        
        throw Exception(
          'eRemiza odrzuciło zapytanie (400) - BRAK DOSTĘPU DO API\n\n'
          '⚠️ TWOJE KONTO NIE MA WŁĄCZONEGO DOSTĘPU API!\n\n'
          'Co zrobić:\n'
          '1. Skontaktuj się z administratorem systemu eRemiza\n'
          '2. Poproś o włączenie dostępu API dla konta: $_email\n'
          '3. Sprawdź czy konto nie wymaga weryfikacji 2FA (API nie obsługuje 2FA)\n'
          '4. Upewnij się że hasło nie zawiera znaków specjalnych\n\n'
          'ALTERNATYWA:\n'
          '→ Wyłącz integrację eRemiza w Menu → Konfiguracja\n'
          '→ Dodawaj wyjazdy ręcznie w aplikacji\n\n'
          'Szczegóły techniczne: ${response.body}'
        );
      }

      if (response.statusCode == 401) {
        throw Exception(
          'Błędne dane logowania do eRemiza.\n\n'
          'Sprawdź:\n'
          '1. Email: $_email (czy jest poprawny?)\n'
          '2. Hasło (czy na pewno to samo co na stronie e-remiza.pl?)\n'
          '3. Wielkość liter w haśle\n'
          '4. Czy konto nie jest zablokowane\n\n'
          'Test: Zaloguj się na https://e-remiza.pl/ tym samym emailem i hasłem.\n'
          'Jeśli tam nie działa - hasło jest nieprawidłowe.'
        );
      }

      if (response.statusCode == 403) {
        throw Exception('Brak dostępu. Sprawdź uprawnienia konta eRemiza.');
      }

      if (response.statusCode == 404) {
        throw Exception('Endpoint nie istnieje. eRemiza API może być niedostępne.');
      }

      if (response.statusCode != 200) {
        print('❌ Błąd eRemiza: ${response.statusCode}');
        print('📄 Body: ${response.body}');
        throw Exception('eRemiza API error ${response.statusCode}: ${response.reasonPhrase}');
      }

      try {
        return json.decode(response.body);
      } catch (e) {
        throw Exception('Nieprawidłowa odpowiedź z eRemiza: $e');
      }

    } catch (e) {
      if (e.toString().contains('SocketException')) {
        throw Exception('Brak połączenia z internetem lub eRemiza jest niedostępne.');
      }
      rethrow;
    }
  }

  /// Logowanie do eRemiza
  Future<Map<String, dynamic>> login() async {
    try {
      print('🔐 Próba logowania do eRemiza...');
      print('📧 Email: ${_email?.substring(0, 3)}***');
      
      _user = await _request('GET', '/User/GetUser');
      
      if (_user == null) {
        throw Exception('Nie udało się pobrać danych użytkownika z eRemiza');
      }

      print('✅ Zalogowano pomyślnie');
      print('👤 Użytkownik: ${_user!['name'] ?? 'Nieznany'}');
      
      return _user!;
    } catch (e) {
      print('❌ Błąd logowania: $e');
      rethrow;
    }
  }

  /// Pobierz listę alarmów
  Future<List<dynamic>> getAlarms({int count = 20, int offset = 0}) async {
    if (_user == null) {
      await login();
    }

    final ouId = _user!['bsisOuId'];
    if (ouId == null) {
      throw Exception('Brak bsisOuId w danych użytkownika. Skontaktuj się z administratorem eRemiza.');
    }

    print('🔍 Pobieranie alarmów...');
    print('   OU ID: $ouId');
    print('   Count: $count');
    print('   Offset: $offset');

    final alarms = await _request('GET', '/Alarm/GetAlarmList', {
      'ouId': ouId.toString(),
      'count': count.toString(),
      'offset': offset.toString(),
    });

    if (alarms is! List) {
      throw Exception('eRemiza zwróciło nieprawidłowy format danych (oczekiwano listy)');
    }

    print('✅ Pobrano ${alarms.length} alarmów');
    return alarms;
  }

  /// Sprawdź czy alarm pochodzi z SK KP
  bool _isSKKPAlarm(String? bsisName) {
    if (bsisName == null) return false;
    final nameUpper = bsisName.toUpperCase();
    return nameUpper.contains('SK KP') || 
           nameUpper.contains('SK_KP') || 
           nameUpper.contains('SKKP');
  }

  /// Mapuj kategorie z eRemiza na KategoriaWyjazdu
  /// P → pożar
  /// Alarm (MZ) → miejscowe zagrożenie  
  /// Ć → ćwiczenia
  /// PNZR → zabezpieczenie (rejonu JRG Łask)
  String _mapCategory(String? subKind) {
    if (subKind == null) return 'miejscoweZagrozenie';
    
    final subKindUpper = subKind.toUpperCase().trim();
    
    // Dokładne mapowanie - używamy ENUM names z KategoriaWyjazdu
    if (subKindUpper == 'P') return 'pozar';
    if (subKindUpper == 'ALARM (MZ)' || subKindUpper == 'MZ') return 'miejscoweZagrozenie';
    if (subKindUpper == 'Ć' || subKindUpper == 'C') return 'cwiczenia';
    if (subKindUpper == 'PNZR') return 'zabezpieczenieRejonu';
    
    // Fallback - częściowe dopasowanie
    if (subKindUpper.contains('POŻAR') || subKindUpper.contains('POZAR')) return 'pozar';
    if (subKindUpper.contains('WYPADEK')) return 'miejscoweZagrozenie';
    if (subKindUpper.contains('MIEJSCOWE')) return 'miejscoweZagrozenie';
    if (subKindUpper.contains('ĆWICZENIA') || subKindUpper.contains('CWICZENIA')) return 'cwiczenia';
    if (subKindUpper.contains('ZABEZPIECZENIE')) return 'zabezpieczenieRejonu';
    if (subKindUpper.contains('FAŁSZYWY') || subKindUpper.contains('FALSZYWY')) return 'alarmFalszywy';
    
    return 'miejscoweZagrozenie';
  }

  /// Synchronizuj alarmy z eRemiza do Firestore
  Future<Map<String, int>> syncAlarms() async {
    print('🔄 Rozpoczynam synchronizację z eRemiza...');
    
    try {
      final alarms = await getAlarms(count: 20, offset: 0);
      print('📥 Pobrano ${alarms.length} alarmów z eRemiza');

      int addedCount = 0;
      int skippedCount = 0;

      for (var alarm in alarms) {
        // FILTR: Tylko alarmy z SK KP
        if (!_isSKKPAlarm(alarm['bsisName'])) {
          print('⏭️ Pomijam alarm spoza SK KP: ${alarm['bsisName']} (ID: ${alarm['id']})');
          skippedCount++;
          continue;
        }

        // Sprawdź duplikaty
        final existing = await _firestore
            .collection('wyjazdy')
            .where('eRemizaId', isEqualTo: alarm['id'])
            .limit(1)
            .get();

        if (existing.docs.isNotEmpty) {
          print('⏭️ Pomijam duplikat: ${alarm['id']}');
          skippedCount++;
          continue;
        }

        // Buduj adres
        String lokalizacja = '';
        if (alarm['locality'] != null) lokalizacja += alarm['locality'].toString().trim();
        if (alarm['street'] != null) {
          if (lokalizacja.isNotEmpty) lokalizacja += ', ';
          lokalizacja += alarm['street'].toString().trim();
        }
        if (alarm['addrPoint'] != null) {
          if (lokalizacja.isNotEmpty) lokalizacja += ' ';
          lokalizacja += alarm['addrPoint'].toString().trim();
        }
        if (alarm['apartment'] != null) {
          lokalizacja += '/${alarm['apartment']}';
        }

        // Przygotuj dane wyjazdu
        final wyjazdData = {
          'tytul': alarm['description'] ?? 'Alarm ${alarm['subKind'] ?? 'nieznany'}',
          'opis': alarm['description'] ?? '',
          'lokalizacja': lokalizacja.isNotEmpty ? lokalizacja : 'Brak lokalizacji',
          'kategoria': _mapCategory(alarm['subKind']),
          'dataWyjazdu': Timestamp.fromDate(DateTime.parse(alarm['aquired'])),
          'status': 'oczekujacy',
          'utworzonePrzez': 'SYSTEM_EREMIZA',
          'czasTrwaniaGodziny': 0,
          'zrodlo': 'eRemiza API',
          'strazacyIds': [],
          'eRemizaId': alarm['id'],
          'eRemizaData': {
            'subKind': alarm['subKind'],
            'bsisName': alarm['bsisName'],
            'kind': alarm['kind'],
            'notified': alarm['notified'] ?? 0,
            'confirmed': alarm['confirmed'] ?? 0,
            'declined': alarm['declined'] ?? 0,
            'commanders': alarm['commanders'] ?? 0,
            'drivers': alarm['drivers'] ?? 0,
          },
          'utworzonoO': FieldValue.serverTimestamp(),
        };

        // Dodaj współrzędne GPS
        if (alarm['latitude'] != null && alarm['longitude'] != null) {
          wyjazdData['wspolrzedne'] = {
            'lat': alarm['latitude'],
            'lng': alarm['longitude'],
          };
        }

        // Zapisz do Firestore
        await _firestore.collection('wyjazdy').add(wyjazdData);
        addedCount++;
        
        print('✅ Dodano alarm: ${alarm['id']} - ${alarm['description']?.toString().substring(0, 50) ?? 'Brak opisu'}');
      }

      // Zapisz czas ostatniej synchronizacji
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKeyLastSync, DateTime.now().toIso8601String());

      print('📊 Synchronizacja zakończona: $addedCount dodano, $skippedCount pominięto');
      return {'added': addedCount, 'skipped': skippedCount};

    } catch (e) {
      print('❌ Błąd synchronizacji z eRemiza: $e');
      rethrow;
    }
  }

  /// Konfiguruj dane logowania
  Future<void> setCredentials(String email, String password) async {
    _email = email;
    _password = password;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKeyEmail, email);
    await prefs.setString(prefKeyPassword, password);

    print('✅ Dane logowania eRemiza zapisane');
  }

  /// Wczytaj zapisane dane logowania
  Future<bool> loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    _email = prefs.getString(prefKeyEmail);
    _password = prefs.getString(prefKeyPassword);

    return _email != null && _password != null;
  }

  /// Pobierz czas ostatniej synchronizacji
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString(prefKeyLastSync);
    
    if (lastSyncStr == null) return null;
    return DateTime.parse(lastSyncStr);
  }

  /// Zatrzymaj automatyczną synchronizację
  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    print('⏹️ Auto-sync eRemiza zatrzymany');
  }

  /// Uruchom automatyczną synchronizację (co 5 minut)
  void startAutoSync() {
    stopAutoSync(); // Zatrzymaj poprzedni timer jeśli istnieje

    // Synchronizuj natychmiast
    syncAlarms().catchError((e) {
      print('❌ Błąd auto-sync: $e');
      return {'added': 0, 'skipped': 0};
    });

    // Uruchom timer (co 5 minut)
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      syncAlarms().catchError((e) {
        print('❌ Błąd auto-sync: $e');
        return {'added': 0, 'skipped': 0};
      });
    });

    print('🔄 Auto-sync eRemiza uruchomiony (co 5 minut)');
  }

  /// Wyloguj
  Future<void> logout() async {
    stopAutoSync();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefKeyEmail);
    await prefs.remove(prefKeyPassword);
    await prefs.remove(prefKeyLastSync);

    _email = null;
    _password = null;
    _user = null;

    print('✅ Wylogowano z eRemiza');
  }

  /// Sprawdź czy jest skonfigurowany
  bool isConfigured() {
    return _email != null && _password != null;
  }
}
