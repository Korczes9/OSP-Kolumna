import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serwis monitorujący nowe wiadomości Discord i wysyłający powiadomienia
class SerwisMonitoringuDiscord {
    static const String _discordBotToken =
      String.fromEnvironment('DISCORD_BOT_TOKEN', defaultValue: '');
  static const String _discordChannelId = '1193142209470533733';
  static const String _prefKeyLastMessageId = 'discord_last_message_id';
  static const String _prefKeyInterwalSprawdzania = 'discord_interwal_sprawdzania';
  static const Duration _minOdstepAlarmu = Duration(minutes: 4);
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _monitoringTimer;
  String? _ostatniaWiadomoscId;
  int _interwalSprawdzania = 1; // domyślnie 1 sekunda
  DateTime? _ostatniAlarmKolumnaAt;
  
  /// Singleton
  static final SerwisMonitoringuDiscord _instance = SerwisMonitoringuDiscord._internal();
  factory SerwisMonitoringuDiscord() => _instance;
  SerwisMonitoringuDiscord._internal();

  /// Uruchom monitoring Discord (sprawdza co X sekund według ustawień)
  Future<void> startMonitoring() async {
    stopMonitoring(); // Zatrzymaj poprzedni timer jeśli istnieje
    
    // Wczytaj ostatnią znaną wiadomość i interwał sprawdzania
    final prefs = await SharedPreferences.getInstance();
    _ostatniaWiadomoscId = prefs.getString(_prefKeyLastMessageId);
    _interwalSprawdzania = prefs.getInt(_prefKeyInterwalSprawdzania) ?? 1;
    
    debugPrint('🔄 Rozpoczynam monitoring Discord...');
    debugPrint('📝 Ostatnia znana wiadomość: $_ostatniaWiadomoscId');
    debugPrint('⏱️ Interwał sprawdzania: $_interwalSprawdzania sekund');
    
    // Sprawdź natychmiast
    _sprawdzNoweWiadomosci();
    
    // Uruchom timer
    _monitoringTimer = Timer.periodic(Duration(seconds: _interwalSprawdzania), (timer) {
      _sprawdzNoweWiadomosci();
    });
    
    debugPrint('✅ Monitoring Discord uruchomiony (sprawdzanie co ${_interwalSprawdzania}s)');
  }

  /// Zatrzymaj monitoring
  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    debugPrint('⏹️ Monitoring Discord zatrzymany');
  }

  /// Sprawdź czy są nowe wiadomości na Discord
  Future<void> _sprawdzNoweWiadomosci() async {
    try {
      debugPrint('🔍 Sprawdzam nowe wiadomości Discord...');
      
      final response = await http.get(
        Uri.parse('https://discord.com/api/v10/channels/$_discordChannelId/messages?limit=10'),
        headers: {
          'Authorization': 'Bot $_discordBotToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('⚠️ Discord API błąd: ${response.statusCode}');
        return;
      }

      final List<dynamic> wiadomosci = json.decode(response.body);
      
      if (wiadomosci.isEmpty) {
        debugPrint('📭 Brak wiadomości na Discord');
        return;
      }

      // Najnowsza wiadomość jest na pozycji 0
      final najnowsza = wiadomosci.first as Map<String, dynamic>;
      final najnowszaId = najnowsza['id'] as String;
      
      // Jeśli to pierwsza synchronizacja, tylko zapisz ID
      if (_ostatniaWiadomoscId == null) {
        debugPrint('📝 Pierwsza synchronizacja - zapisuję ID: $najnowszaId');
        _ostatniaWiadomoscId = najnowszaId;
        await _zapiszOstatniaWiadomoscId(najnowszaId);
        return;
      }

      // Sprawdź czy są nowe wiadomości
      if (najnowszaId == _ostatniaWiadomoscId) {
        debugPrint('✅ Brak nowych wiadomości');
        return;
      }

      // Znajdź wszystkie nowe wiadomości (od ostatniej znanej do najnowszej)
      final noweWiadomosci = <Map<String, dynamic>>[];
      for (var wiadomosc in wiadomosci) {
        final id = wiadomosc['id'] as String;
        if (id == _ostatniaWiadomoscId) break;
        noweWiadomosci.add(wiadomosc as Map<String, dynamic>);
      }

      debugPrint('🆕 Znaleziono ${noweWiadomosci.length} nowych wiadomości');

      // Wyślij powiadomienia dla nowych wiadomości (od najstarszej do najnowszej)
      for (var wiadomosc in noweWiadomosci.reversed) {
        await _wyslijPowiadomienieONoweWiadomosci(wiadomosc);
      }

      // Zaktualizuj ostatnią wiadomość
      _ostatniaWiadomoscId = najnowszaId;
      await _zapiszOstatniaWiadomoscId(najnowszaId);

    } catch (e) {
      debugPrint('❌ Błąd sprawdzania Discord: $e');
    }
  }

  /// Wyślij powiadomienie push o nowej wiadomości Discord
  Future<void> _wyslijPowiadomienieONoweWiadomosci(Map<String, dynamic> wiadomosc) async {
    try {
      final author = wiadomosc['author'] as Map<String, dynamic>;
      final authorName = author['username'] ?? 'Discord';
      final content = wiadomosc['content'] as String? ?? '';
      
      // Wyciągnij tytuł z embedów jeśli istnieją
      String title = 'Nowa wiadomość Discord';
      String body = content.isNotEmpty ? content : '(wiadomość z załącznikiem)';
      
      final embeds = wiadomosc['embeds'] as List<dynamic>?;
      if (embeds != null && embeds.isNotEmpty) {
        final firstEmbed = embeds.first as Map<String, dynamic>;
        final embedTitle = firstEmbed['title'] as String?;
        final embedDesc = firstEmbed['description'] as String?;
        
        if (embedTitle != null && embedTitle.isNotEmpty) {
          title = embedTitle;
          body = embedDesc ?? content;
        }
      }

      // SPRAWDŹ CZY WIADOMOŚĆ ZAWIERA "KOLUMNA" - JEŚLI TAK, URUCHOM ALARM
      final pelnyTekst = '$title $body $content'.toUpperCase();
        final czyAlarm = pelnyTekst.contains('KOLUMNA');
        final teraz = DateTime.now();
        final czyAlarmZWyhamowaniem = !czyAlarm
          ? false
          : _ostatniAlarmKolumnaAt == null
            ? true
            : teraz.difference(_ostatniAlarmKolumnaAt!) >= _minOdstepAlarmu;
      
      if (czyAlarmZWyhamowaniem) {
        debugPrint('🚨 WYKRYTO SŁOWO "KOLUMNA" - WYSYŁAM ALARM!');
        _ostatniAlarmKolumnaAt = teraz;
      } else if (czyAlarm) {
        debugPrint('⏱️ WYKRYTO "KOLUMNA", ale alarm został wyciszony (4 minuty)');
      } else {
        debugPrint('📤 Wysyłam powiadomienie: $title');
      }

      // Pobierz wszystkie FCM tokeny użytkowników
      final usersSnapshot = await _firestore.collection('strazacy').get();
      final tokens = <String>[];
      
      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        final fcmToken = data['fcmToken'] as String?;
        if (fcmToken != null && fcmToken.isNotEmpty) {
          tokens.add(fcmToken);
        }
      }

      if (tokens.isEmpty) {
        debugPrint('⚠️ Brak tokenów FCM - nikt nie dostanie powiadomienia');
        return;
      }

      // Zapisz powiadomienie w Firestore (Cloud Function wyśle je)
      await _firestore.collection('powiadomienia').add({
        'tokens': tokens,
        'title': czyAlarmZWyhamowaniem ? '🚨 ALARM - Kolumna' : '💬 $title',
        'body': body.isNotEmpty ? body : content,
        'data': {
          'type': czyAlarmZWyhamowaniem ? 'ALARM' : 'discord',
          'messageId': wiadomosc['id'],
          'author': authorName,
          'channelId': _discordChannelId,
          'kategoria': czyAlarmZWyhamowaniem ? 'Discord - Kolumna' : 'Discord',
          'fullContent': content,
          'fullTitle': title,
          'fullBody': body,
        },
        'utworzonoO': FieldValue.serverTimestamp(),
        'wyslane': false,
      });

      debugPrint('✅ Powiadomienie zapisane w Firestore (${tokens.length} odbiorców)');

    } catch (e) {
      debugPrint('❌ Błąd wysyłania powiadomienia: $e');
    }
  }

  /// Zapisz ID ostatniej wiadomości
  Future<void> _zapiszOstatniaWiadomoscId(String messageId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyLastMessageId, messageId);
  }

  /// Resetuj monitoring (np. do testowania)
  Future<void> resetujMonitoring() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyLastMessageId);
    _ostatniaWiadomoscId = null;
    debugPrint('🔄 Monitoring Discord zresetowany');
  }
  /// Ustaw interwał sprawdzania (w sekundach)
  Future<void> ustawInterwalSprawdzania(int sekundy) async {
    if (sekundy < 1 || sekundy > 300) {
      throw Exception('Interwał musi być między 1 a 300 sekund');
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyInterwalSprawdzania, sekundy);
    _interwalSprawdzania = sekundy;
    
    debugPrint('⏱️ Nowy interwał sprawdzania: $sekundy sekund');
    
    // Restart monitoringu z nowym interwałem
    if (_monitoringTimer != null) {
      await startMonitoring();
    }
  }

  /// Pobierz aktualny interwał sprawdzania
  Future<int> pobierzInterwalSprawdzania() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefKeyInterwalSprawdzania) ?? 1;
  }}
