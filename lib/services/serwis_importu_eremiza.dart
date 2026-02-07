import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Prosty serwis do importu alarmów z eRemiza (web scraping)
class SerwisImportuEremiza {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _urlAlarmy = 'https://e-remiza.pl/OSP.UI.EREMIZA/alarmy';
  static const String _urlLogin = 'https://e-remiza.pl/OSP.UI.SSO/logowanie';
  
  String? _sessionCookie;

  List<String> _wyciagnijCookies(String? rawCookieHeader) {
    if (rawCookieHeader == null || rawCookieHeader.isEmpty) {
      return [];
    }

    final cookies = <String>[];
    final parts = rawCookieHeader.split(RegExp(r',(?=[^;]+?=)'));
    for (final part in parts) {
      final cookie = part.split(';').first.trim();
      if (cookie.isNotEmpty) {
        cookies.add(cookie);
      }
    }

    return cookies;
  }

  Map<String, String> _zbudujDaneLogowania(String email, String haslo, String html) {
    final document = html_parser.parse(html);
    final inputs = document.querySelectorAll('form input');

    String? loginFieldName;
    String? passwordFieldName;

    final payload = <String, String>{};

    for (final input in inputs) {
      final name = input.attributes['name'];
      if (name == null || name.isEmpty) continue;

      final type = (input.attributes['type'] ?? '').toLowerCase();
      final value = input.attributes['value'] ?? '';

      if (type == 'hidden') {
        payload[name] = value;
        continue;
      }

      final lowerName = name.toLowerCase();
      if (type == 'email' || lowerName.contains('email') || lowerName.contains('login') || lowerName.contains('user')) {
        loginFieldName ??= name;
      }
      if (type == 'password' || lowerName.contains('pass')) {
        passwordFieldName ??= name;
      }
    }

    payload[loginFieldName ?? 'email'] = email;
    payload[passwordFieldName ?? 'password'] = haslo;

    return payload;
  }

  /// Logowanie do eRemiza i pobranie session cookie
  Future<bool> zaloguj(String email, String haslo) async {
    try {
      debugPrint('🔐 Logowanie do eRemiza: $email');

      final client = http.Client();
      try {
        final loginPage = await client.get(Uri.parse(_urlLogin));
        final initialCookies = _wyciagnijCookies(loginPage.headers['set-cookie']);
        final payload = _zbudujDaneLogowania(email, haslo, loginPage.body);

        final response = await client.post(
          Uri.parse(_urlLogin),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            if (initialCookies.isNotEmpty) 'Cookie': initialCookies.join('; '),
            'Referer': _urlLogin,
          },
          body: payload,
        );

        if (response.statusCode == 200 || response.statusCode == 302) {
          final cookies = _wyciagnijCookies(response.headers['set-cookie']);
          if (cookies.isNotEmpty) {
            _sessionCookie = cookies.join('; ');
            debugPrint('✅ Zalogowano pomyślnie');

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('eremiza_email', email);
            await prefs.setString('eremiza_password', haslo);

            return true;
          }
        }

        debugPrint('❌ Błąd logowania: ${response.statusCode}');
        return false;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('❌ Wyjątek podczas logowania: $e');
      return false;
    }
  }

  /// Pobierz i zaimportuj alarmy z SK KP
  Future<Map<String, int>> importujAlarmy() async {
    if (_sessionCookie == null) {
      // Spróbuj zalogować się używając zapisanych danych
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('eremiza_email');
      final haslo = prefs.getString('eremiza_password');
      
      if (email == null || haslo == null) {
        throw Exception('Brak danych logowania. Zaloguj się najpierw.');
      }
      
      final zalogowano = await zaloguj(email, haslo);
      if (!zalogowano) {
        throw Exception('Nie udało się zalogować do eRemiza');
      }
    }

    try {
      debugPrint('📥 Pobieranie alarmów z eRemiza...');
      
      final response = await http.get(
        Uri.parse(_urlAlarmy),
        headers: {
          'Cookie': _sessionCookie!,
          'User-Agent': 'Mozilla/5.0',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Błąd pobierania alarmów: ${response.statusCode}');
      }

      // Parsuj HTML
      final document = html_parser.parse(response.body);
      
      // Szukaj tabeli alarmów (dostosuj selektory do rzeczywistej struktury HTML)
      final rows = document.querySelectorAll('table tbody tr');
      
      int dodano = 0;
      int pominieto = 0;

      for (var row in rows) {
        try {
          final cells = row.querySelectorAll('td');
          if (cells.length < 4) continue;

          // Wyciągnij dane z komórek tabeli (dostosuj indeksy do rzeczywistej struktury)
          final dataText = cells[0].text.trim();
          final jednostka = cells[1].text.trim();
          final lokalizacja = cells[2].text.trim();
          final opis = cells[3].text.trim();

          // FILTR: Tylko alarmy z SK KP
          if (!jednostka.toUpperCase().contains('SK KP') && 
              !jednostka.toUpperCase().contains('SK_KP') &&
              !jednostka.toUpperCase().contains('SKKP')) {
            debugPrint('⏭️ Pominięto alarm spoza SK KP: $jednostka');
            pominieto++;
            continue;
          }

          // Sprawdź czy już istnieje (po lokalizacji i dacie)
          final existing = await _firestore
              .collection('wyjazdy')
              .where('lokalizacja', isEqualTo: lokalizacja)
              .where('opis', isEqualTo: opis)
              .limit(1)
              .get();

          if (existing.docs.isNotEmpty) {
            debugPrint('⏭️ Duplikat: $lokalizacja');
            pominieto++;
            continue;
          }

          // Parsuj datę
          DateTime dataWyjazdu;
          try {
            // Format przykładowy: "05.02.2026 14:30"
            final parts = dataText.split(' ');
            final dateParts = parts[0].split('.');
            final timeParts = parts.length > 1 ? parts[1].split(':') : ['0', '0'];
            
            dataWyjazdu = DateTime(
              int.parse(dateParts[2]), // rok
              int.parse(dateParts[1]), // miesiąc
              int.parse(dateParts[0]), // dzień
              timeParts.length > 0 ? int.parse(timeParts[0]) : 0, // godzina
              timeParts.length > 1 ? int.parse(timeParts[1]) : 0, // minuta
            );
          } catch (e) {
            debugPrint('⚠️ Błąd parsowania daty: $dataText');
            dataWyjazdu = DateTime.now();
          }

          // Określ kategorię na podstawie opisu
          String kategoria = 'miejscoweZagrozenie';
          final opisUpper = opis.toUpperCase();
          if (opisUpper.contains('POŻAR') || opisUpper.contains('POZAR')) {
            kategoria = 'pozar';
          } else if (opisUpper.contains('WYPADEK') || opisUpper.contains('KOLIZJA')) {
            kategoria = 'miejscoweZagrozenie';
          } else if (opisUpper.contains('ĆWICZENIA') || opisUpper.contains('CWICZENIA')) {
            kategoria = 'cwiczenia';
          } else if (opisUpper.contains('FAŁSZYWY') || opisUpper.contains('FALSZYWY')) {
            kategoria = 'alarmFalszywy';
          }

          // Dodaj do Firestore
          await _firestore.collection('wyjazdy').add({
            'lokalizacja': lokalizacja,
            'opis': opis,
            'kategoria': kategoria,
            'dataWyjazdu': Timestamp.fromDate(dataWyjazdu),
            'status': 'oczekujacy',
            'utworzonePrzez': 'IMPORT_EREMIZA',
            'strazacyIds': [],
            'zrodlo': 'eRemiza Web Import',
            'jednostka': jednostka,
            'utworzonoO': FieldValue.serverTimestamp(),
          });

          dodano++;
          debugPrint('✅ Dodano: $lokalizacja');
        } catch (e) {
          debugPrint('⚠️ Błąd przetwarzania wiersza: $e');
          pominieto++;
        }
      }

      debugPrint('📊 Import zakończony: $dodano dodano, $pominieto pominięto');
      return {'dodano': dodano, 'pominieto': pominieto};

    } catch (e) {
      debugPrint('❌ Błąd importu: $e');
      rethrow;
    }
  }

  /// Wyloguj
  Future<void> wyloguj() async {
    _sessionCookie = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('eremiza_email');
    await prefs.remove('eremiza_password');
    
    debugPrint('✅ Wylogowano z eRemiza');
  }

  /// Sprawdź czy jest zalogowany
  bool czyZalogowany() {
    return _sessionCookie != null;
  }
}
