import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum PoziomOstrzezenia {
  brak,
  zolty, // 1 stopień
  pomaranczowy, // 2 stopień
  czerwony, // 3 stopień
}

enum PoziomZagrozeniaPozarowego {
  brak,       // Brak zagrożenia
  maly,       // 1 - małe zagrożenie
  sredni,     // 2 - średnie zagrożenie
  duzy,       // 3 - duże zagrożenie
  bardzo_duzy // 4 - bardzo duże zagrożenie
}

enum TypOstrzezenia {
  imgw,
  rcb,
}

class OstrzezenieIMGW {
  final String id;
  final String tytul;
  final String opis;
  final PoziomOstrzezenia poziom;
  final DateTime dataWydania;
  final DateTime dataOd;
  final DateTime dataDo;
  final String region;
  final TypOstrzezenia typ;

  OstrzezenieIMGW({
    required this.id,
    required this.tytul,
    required this.opis,
    required this.poziom,
    required this.dataWydania,
    required this.dataOd,
    required this.dataDo,
    required this.region,
    this.typ = TypOstrzezenia.imgw,
  });

  factory OstrzezenieIMGW.fromJson(Map<String, dynamic> json) {
    return OstrzezenieIMGW(
      id: json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      tytul: json['phenomenon'] ?? json['title'] ?? 'Ostrzeżenie',
      opis: json['description'] ?? json['desc'] ?? '',
      poziom: _parsujPoziom(json['level'] ?? json['severity'] ?? 0),
      dataWydania: _parsujDate(json['issue_date'] ?? json['published']),
      dataOd: _parsujDate(json['valid_from'] ?? json['start_date']),
      dataDo: _parsujDate(json['valid_to'] ?? json['end_date']),
      region: json['region'] ?? json['area'] ?? 'Łask',
    );
  }

  static PoziomOstrzezenia _parsujPoziom(dynamic poziom) {
    if (poziom is int) {
      switch (poziom) {
        case 1:
          return PoziomOstrzezenia.zolty;
        case 2:
          return PoziomOstrzezenia.pomaranczowy;
        case 3:
          return PoziomOstrzezenia.czerwony;
        default:
          return PoziomOstrzezenia.brak;
      }
    }
    return PoziomOstrzezenia.brak;
  }

  static DateTime _parsujDate(dynamic date) {
    if (date == null) return DateTime.now();
    if (date is DateTime) return date;
    try {
      return DateTime.parse(date.toString());
    } catch (e) {
      return DateTime.now();
    }
  }
}

class SerwisIMGW {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _prefsKeyNotifiedIds = 'imgw_notified_ids';
  // API IMGW dla ostrzeżeń meteorologicznych
  static const String _baseUrl = 'https://danepubliczne.imgw.pl/api/data';
  static const String _ostrzezeniaUrl =
      'https://danepubliczne.imgw.pl/api/data/warningsmeteo';

  // Kod terytorialny dla powiatu łaskiego (woj. łódzkie)
  static const String _kodTerytorialnyLask = '1005';

  // Cache dla ostrzeżeń
  static List<OstrzezenieIMGW>? _cacheOstrzezenia;
  static DateTime? _cacheTimestamp;
  static const _cacheDuration = Duration(minutes: 15);

  /// Pobiera ostrzeżenia meteorologiczne dla gminy Łask
  Future<List<OstrzezenieIMGW>> pobierzOstrzezenia(
      {bool forceRefresh = false}) async {
    // Sprawdź cache jeśli nie wymuszono odświeżenia
    if (!forceRefresh && _cacheOstrzezenia != null && _cacheTimestamp != null) {
      final age = DateTime.now().difference(_cacheTimestamp!);
      if (age < _cacheDuration) {
        debugPrint(
            '📦 Zwracam ostrzeżenia z cache (wiek: ${age.inMinutes} min)');
        return _cacheOstrzezenia!;
      }
    }

    try {
      debugPrint(
          '🔍 Pobieranie ostrzeżeń IMGW dla powiatu łaskiego (kod: $_kodTerytorialnyLask)...');

      final url = Uri.parse(_ostrzezeniaUrl);
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        debugPrint('📥 Pobrano ${data.length} ostrzeżeń z API IMGW');

        final List<OstrzezenieIMGW> ostrzezenia = [];

        // Filtruj ostrzeżenia dla powiatu łaskiego
        for (var item in data) {
          final teryt = item['teryt'] as List<dynamic>?;

          // Sprawdź czy ostrzeżenie dotyczy powiatu łaskiego
          if (teryt != null && teryt.contains(_kodTerytorialnyLask)) {
            final id = item['id']?.toString() ?? '';
            final nazwaZdarzenia = item['nazwa_zdarzenia']?.toString() ??
                'Ostrzeżenie meteorologiczne';
            final stopien = item['stopien']?.toString() ?? '0';
            final tresc = item['tresc']?.toString() ?? '';
            final obowiazujeOd = item['obowiazuje_od']?.toString();
            final obowiazujeDo = item['obowiazuje_do']?.toString();
            final opublikowano = item['opublikowano']?.toString();
            final prawdopodobienstwo =
                item['prawdopodobienstwo']?.toString() ?? '';
            final biuro = item['biuro']?.toString() ?? 'IMGW';

            // Określ poziom ostrzeżenia na podstawie stopnia
            PoziomOstrzezenia poziom;
            String emoji;
            switch (stopien) {
              case '1':
                poziom = PoziomOstrzezenia.zolty;
                emoji = '⚠️';
                break;
              case '2':
                poziom = PoziomOstrzezenia.pomaranczowy;
                emoji = '⚠️';
                break;
              case '3':
                poziom = PoziomOstrzezenia.czerwony;
                emoji = '🚨';
                break;
              default:
                poziom = PoziomOstrzezenia.brak;
                emoji = 'ℹ️';
            }

            // Dodaj emoji zależnie od typu zdarzenia
            if (nazwaZdarzenia.toLowerCase().contains('mróz') ||
                nazwaZdarzenia.toLowerCase().contains('mroz')) {
              emoji = '❄️';
            } else if (nazwaZdarzenia.toLowerCase().contains('upał') ||
                nazwaZdarzenia.toLowerCase().contains('upal')) {
              emoji = '☀️';
            } else if (nazwaZdarzenia.toLowerCase().contains('wiatr')) {
              emoji = '💨';
            } else if (nazwaZdarzenia.toLowerCase().contains('deszcz') ||
                nazwaZdarzenia.toLowerCase().contains('opady')) {
              emoji = '🌧️';
            } else if (nazwaZdarzenia.toLowerCase().contains('burza')) {
              emoji = '⛈️';
            } else if (nazwaZdarzenia.toLowerCase().contains('śnieg') ||
                nazwaZdarzenia.toLowerCase().contains('snieg')) {
              emoji = '🌨️';
            }

            // Stwórz opis z dodatkowymi informacjami
            String opis = tresc;
            if (prawdopodobienstwo.isNotEmpty) {
              opis += '\n\n📊 Prawdopodobieństwo: $prawdopodobienstwo%';
            }
            opis += '\n\n🏢 Źródło: $biuro';

            ostrzezenia.add(OstrzezenieIMGW(
              id: id,
              tytul: '$emoji $nazwaZdarzenia (stopień $stopien)',
              opis: opis,
              poziom: poziom,
              dataWydania: opublikowano != null
                  ? _parsujDate(opublikowano)
                  : DateTime.now(),
              dataOd: obowiazujeOd != null
                  ? _parsujDate(obowiazujeOd)
                  : DateTime.now(),
              dataDo: obowiazujeDo != null
                  ? _parsujDate(obowiazujeDo)
                  : DateTime.now().add(const Duration(hours: 24)),
              region: 'Powiat łaski (woj. łódzkie)',
            ));
          }
        }

        debugPrint(
            '✅ Znaleziono ${ostrzezenia.length} ostrzeżeń dla powiatu łaskiego');

        // Zapisz wyniki do cache
        _cacheOstrzezenia = ostrzezenia.isEmpty ? [] : ostrzezenia;
        _cacheTimestamp = DateTime.now();
        debugPrint('💾 Zapisano ostrzeżenia do cache');

        if (ostrzezenia.isEmpty) {
          debugPrint('ℹ️ Brak aktywnych ostrzeżeń dla powiatu łaskiego');
          final wynikBrak = [
            OstrzezenieIMGW(
              id: 'brak_${DateTime.now().millisecondsSinceEpoch}',
              tytul: '✅ Brak aktywnych ostrzeżeń',
              opis:
                  'Obecnie nie ma aktywnych ostrzeżeń meteorologicznych dla powiatu łaskiego. Warunki pogodowe są normalne.',
              poziom: PoziomOstrzezenia.brak,
              dataWydania: DateTime.now(),
              dataOd: DateTime.now(),
              dataDo: DateTime.now().add(const Duration(hours: 24)),
              region: 'Powiat łaski (woj. łódzkie)',
            ),
          ];
          _cacheOstrzezenia = wynikBrak;
          return wynikBrak;
        }

        return ostrzezenia;
      } else {
        debugPrint('❌ Błąd HTTP: ${response.statusCode}');
        return _generateMockOstrzezenia();
      }
    } catch (e) {
      print('❌ Błąd pobierania ostrzeżeń IMGW: $e');
      return _generateMockOstrzezenia();
    }
  }

  static DateTime _parsujDate(String dateStr) {
    try {
      // Format: "2026-02-02 11:59:00"
      return DateTime.parse(dateStr.replaceAll(' ', 'T'));
    } catch (e) {
      return DateTime.now();
    }
  }

  /// Generuje przykładowe ostrzeżenia gdy API nie działa
  List<OstrzezenieIMGW> _generateMockOstrzezenia() {
    return [
      OstrzezenieIMGW(
        id: 'offline_${DateTime.now().millisecondsSinceEpoch}',
        tytul: '⚠️ Brak połączenia z IMGW',
        opis:
            'Nie można pobrać aktualnych ostrzeżeń meteorologicznych z serwera IMGW. Sprawdź połączenie internetowe lub spróbuj ponownie później.',
        poziom: PoziomOstrzezenia.brak,
        dataWydania: DateTime.now(),
        dataOd: DateTime.now(),
        dataDo: DateTime.now().add(const Duration(hours: 1)),
        region: 'System',
      ),
    ];
  }

  /// Pobiera alerty RCB (Rządowe Centrum Bezpieczeństwa)
  Future<List<OstrzezenieIMGW>> pobierzAlertyRCB() async {
    try {
      debugPrint('🔍 Pobieranie alertów RCB...');

      // API RCB - publiczne alerty
      // UWAGA: Endpoint może się zmieniać lub być niedostępny
      final url = Uri.parse('https://rcb-api.gov.pl/api/v1.1/alerts');
      debugPrint('📡 URL RCB: $url');
      
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      debugPrint('📊 RCB Response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        debugPrint('📥 Pobrano ${data.length} alertów RCB z API');

        final List<OstrzezenieIMGW> alerty = [];

        for (var item in data) {
          debugPrint('🔎 Alert RCB: ${item['title']}');
          debugPrint('  Województwa: ${item['voivodeships']}');
          debugPrint('  Ważne od: ${item['effective']} do ${item['expires']}');
          
          // Filtruj dla województwa łódzkiego lub całej Polski
          final wojewodztwa = item['voivodeships'] as List<dynamic>?;
          
          // Zaakceptuj alert jeśli:
          // 1. Brak informacji o województwach (dotyczy całej Polski)
          // 2. Lista województw zawiera '10' (łódzkie)
          // 3. Lista zawiera 'all'
          if (wojewodztwa == null || 
              wojewodztwa.isEmpty || 
              wojewodztwa.contains('10') || // łódzkie
              wojewodztwa.contains('all')) {
            
            final tytul = item['title']?.toString() ?? 'Alert RCB';
            final tresc = item['content']?.toString() ?? '';
            final poziomStr = item['severity']?.toString() ?? 'moderate';
            
            debugPrint('✅ Alert RCB dla regionu: $tytul');
            
            // Mapuj poziom alertu RCB na poziom ostrzeżenia
            PoziomOstrzezenia poziom;
            switch (poziomStr.toLowerCase()) {
              case 'minor':
                poziom = PoziomOstrzezenia.zolty;
                break;
              case 'moderate':
                poziom = PoziomOstrzezenia.pomaranczowy;
                break;
              case 'severe':
              case 'extreme':
                poziom = PoziomOstrzezenia.czerwony;
                break;
              default:
                poziom = PoziomOstrzezenia.zolty;
            }

            alerty.add(OstrzezenieIMGW(
              id: 'rcb_${item['id'] ?? DateTime.now().millisecondsSinceEpoch}',
              tytul: '🚨 RCB: $tytul',
              opis: tresc,
              poziom: poziom,
              dataWydania: _parsujDate(item['sent']?.toString() ?? ''),
              dataOd: _parsujDate(item['effective']?.toString() ?? ''),
              dataDo: _parsujDate(item['expires']?.toString() ?? ''),
              region: 'Województwo łódzkie',
              typ: TypOstrzezenia.rcb,
            ));
          } else {
            debugPrint('⏭️ Pomijam alert dla innych województw');
          }
        }

        debugPrint('✅ Znaleziono ${alerty.length} alertów RCB dla regionu');
        return alerty;
      } else {
        debugPrint('❌ Błąd HTTP RCB: ${response.statusCode}');
        debugPrint('   Response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
        return [];
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Błąd pobierania alertów RCB: $e');
      debugPrint('   StackTrace: $stackTrace');
      return [];
    }
  }

  /// Pobiera wszystkie ostrzeżenia (IMGW + RCB)
  Future<List<OstrzezenieIMGW>> pobierzWszystkieOstrzezenia({bool forceRefresh = false}) async {
    final imgw = await pobierzOstrzezenia(forceRefresh: forceRefresh);
    final rcb = await pobierzAlertyRCB();
    
    // Połącz i posortuj po dacie (najnowsze pierwsze)
    final wszystkie = [...imgw, ...rcb];
    wszystkie.sort((a, b) => b.dataWydania.compareTo(a.dataWydania));
    
    return wszystkie;
  }

  Future<void> powiadomONowychOstrzezeniach(List<OstrzezenieIMGW> ostrzezenia) async {
    if (ostrzezenia.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final zapisaneIds = prefs.getStringList(_prefsKeyNotifiedIds) ?? <String>[];

    final noweOstrzezenia = ostrzezenia.where((ostrzezenie) {
      if (ostrzezenie.poziom == PoziomOstrzezenia.brak) return false;
      return !zapisaneIds.contains(ostrzezenie.id);
    }).toList();

    if (noweOstrzezenia.isEmpty) return;

    final usersSnapshot = await _firestore
        .collection('strazacy')
        .where('aktywny', isEqualTo: true)
        .get();

    final tokens = <String>[];
    for (var doc in usersSnapshot.docs) {
      final data = doc.data();
      final token = data['fcmToken'] as String?;
      if (token != null && token.isNotEmpty) {
        tokens.add(token);
      }
    }

    if (tokens.isEmpty) {
      debugPrint('⚠️ Brak tokenów FCM - nie wysyłam ostrzeżeń IMGW');
      return;
    }

    for (final ostrzezenie in noweOstrzezenia) {
      await _firestore.collection('notifications').add({
        'type': 'IMGW',
        'title': '⚠️ Ostrzeżenie IMGW',
        'body': ostrzezenie.tytul,
        'data': {
          'type': 'IMGW',
          'id': ostrzezenie.id,
          'tytul': ostrzezenie.tytul,
          'opis': ostrzezenie.opis,
          'poziom': ostrzezenie.poziom.name,
          'dataOd': ostrzezenie.dataOd.toIso8601String(),
          'dataDo': ostrzezenie.dataDo.toIso8601String(),
          'region': ostrzezenie.region,
          'typ': ostrzezenie.typ.name,
        },
        'tokens': tokens,
        'timestamp': FieldValue.serverTimestamp(),
        'wyslane': false,
      });

      zapisaneIds.add(ostrzezenie.id);
    }

    final unikatowe = <String>[];
    for (final id in zapisaneIds) {
      if (!unikatowe.contains(id)) {
        unikatowe.add(id);
      }
    }

    final zachowane = unikatowe.length > 50
        ? unikatowe.sublist(unikatowe.length - 50)
        : unikatowe;

    await prefs.setStringList(_prefsKeyNotifiedIds, zachowane);
  }

  /// Pobiera dane meteorologiczne dla Łasku
  Future<Map<String, dynamic>?> pobierzPogode() async {
    try {
      final url = Uri.parse('$_baseUrl/synop');

      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        // Znajdź najbliższą stację (Łódź lub Sieradz)
        final stacja = data.firstWhere(
          (item) {
            final nazwa = item['stacja']?.toString().toLowerCase() ?? '';
            return nazwa.contains('łódź') || nazwa.contains('sieradz');
          },
          orElse: () => data.isNotEmpty ? data.first : null,
        );

        return stacja as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('Błąd pobierania pogody: $e');
      return null;
    }
  }

  /// Pobiera poziom zagrożenia pożarowego lasów
  /// Zwraca PoziomZagrozeniaPozarowego oraz datę ważności
  Future<Map<String, dynamic>> pobierzZagrozeniePozaroweIPN() async {
    try {
      debugPrint('🔥 Pobieranie poziomu zagrożenia pożarowego lasów...');
      
      // API IMGW - zagrożenie pożarowe
      final url = Uri.parse('https://danepubliczne.imgw.pl/api/data/warningsfire');
      
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        debugPrint('📥 Pobrano ${data.length} ostrzeżeń pożarowych');

        // Znajdź ostrzeżenie dla powiatu łaskiego
        for (var item in data) {
          final teryt = item['teryt'] as List<dynamic>?;
          
          if (teryt != null && teryt.contains(_kodTerytorialnyLask)) {
            final stopien = int.tryParse(item['stopien']?.toString() ?? '0') ?? 0;
            final obowiazujeDo = item['obowiazuje_do']?.toString();
            
            PoziomZagrozeniaPozarowego poziom;
            String opis;
            String emoji;
            
            switch (stopien) {
              case 1:
                poziom = PoziomZagrozeniaPozarowego.maly;
                opis = 'Małe zagrożenie pożarowe';
                emoji = '🟢';
                break;
              case 2:
                poziom = PoziomZagrozeniaPozarowego.sredni;
                opis = 'Średnie zagrożenie pożarowe - zachowaj ostrożność';
                emoji = '🟡';
                break;
              case 3:
                poziom = PoziomZagrozeniaPozarowego.duzy;
                opis = 'Duże zagrożenie pożarowe - unikaj rozpalania ognisk';
                emoji = '🟠';
                break;
              case 4:
                poziom = PoziomZagrozeniaPozarowego.bardzo_duzy;
                opis = 'Bardzo duże zagrożenie pożarowe - zakaz używania otwartego ognia w lasach!';
                emoji = '🔴';
                break;
              default:
                poziom = PoziomZagrozeniaPozarowego.brak;
                opis = 'Brak danych o zagrożeniu pożarowym';
                emoji = '⚪';
            }
            
            debugPrint('🔥 Zagrożenie pożarowe: stopień $stopien - $opis');
            
            return {
              'poziom': poziom,
              'stopien': stopien,
              'opis': opis,
              'emoji': emoji,
              'wazne_do': obowiazujeDo != null ? _parsujDate(obowiazujeDo) : null,
            };
          }
        }
        
        // Brak ostrzeżenia dla regionu
        debugPrint('ℹ️ Brak ostrzeżenia pożarowego dla powiatu łaskiego');
        return {
          'poziom': PoziomZagrozeniaPozarowego.brak,
          'stopien': 0,
          'opis': 'Brak danych o zagrożeniu pożarowym',
          'emoji': '⚪',
          'wazne_do': null,
        };
      } else {
        debugPrint('❌ Błąd HTTP zagrożenie pożarowe: ${response.statusCode}');
        return _defaultZagrozeniePozarowe();
      }
    } catch (e) {
      debugPrint('❌ Błąd pobierania zagrożenia pożarowego: $e');
      return _defaultZagrozeniePozarowe();
    }
  }

  Map<String, dynamic> _defaultZagrozeniePozarowe() {
    return {
      'poziom': PoziomZagrozeniaPozarowego.brak,
      'stopien': 0,
      'opis': 'Brak połączenia - nie można pobrać danych',
      'emoji': '⚪',
      'wazne_do': null,
    };
  }

  /// Sprawdza czy jest alert silnego wiatru (zagrożenie dla drzew)
  Future<Map<String, dynamic>?> sprawdzSilnyWiatr() async {
    try {
      final ostrzezenia = await pobierzOstrzezenia();
      
      for (var ostrzezenie in ostrzezenia) {
        final tytul = ostrzezenie.tytul.toLowerCase();
        final opis = ostrzezenie.opis.toLowerCase();
        
        // Sprawdź czy dotyczy wiatru
        if (tytul.contains('wiatr') || opis.contains('wiatr')) {
          // Wyciągnij prędkość wiatru z opisu
          final predkoscRegex = RegExp(r'(\d+)\s*km/h');
          final match = predkoscRegex.firstMatch(opis);
          final predkosc = match != null ? int.tryParse(match.group(1) ?? '0') ?? 0 : 0;
          
          // Silny wiatr to >60 km/h
          if (predkosc >= 60 || ostrzezenie.poziom == PoziomOstrzezenia.pomaranczowy || 
              ostrzezenie.poziom == PoziomOstrzezenia.czerwony) {
            
            String zagroz = '';
            if (predkosc >= 90) {
              zagroz = '🚨 BARDZO SILNY WIATR! Zagrożenie dla ludzi i mienia. Możliwe połamane drzewa, zerwane dachy, przerwy w dostawie prądu.';
            } else if (predkosc >= 75) {
              zagroz = '⚠️ SILNY WIATR! Duże zagrożenie połamania gałęzi i drzew. Unikaj przebywania w lesie i pod drzewami.';
            } else if (predkosc >= 60) {
              zagroz = '⚠️ Silny wiatr. Możliwe połamane gałęzie. Zachowaj ostrożność podczas przebywania w lesie.';
            }
            
            return {
              'aktywny': true,
              'predkosc': predkosc,
              'poziom': ostrzezenie.poziom,
              'tytul': ostrzezenie.tytul,
              'ostrzezenie': zagroz,
              'opis': ostrzezenie.opis,
              'wazne_do': ostrzezenie.dataDo,
            };
          }
        }
      }
      
      return {'aktywny': false};
    } catch (e) {
      debugPrint('❌ Błąd sprawdzania silnego wiatru: $e');
      return {'aktywny': false};
    }
  }
}

