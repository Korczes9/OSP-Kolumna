import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/ekran_alarmu_fullscreen.dart';

/// Serwis obsługujący powiadomienia push Firebase Cloud Messaging
class SerwisPowiadomien {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static BuildContext? _context;
  static String? _fcmToken;
  static bool _localNotificationsReady = false;
  static const String _pushBackendUrl =
      String.fromEnvironment('PUSH_BACKEND_URL', defaultValue: '');
  static const String _pushBackendToken =
      String.fromEnvironment('PUSH_BACKEND_TOKEN', defaultValue: '');

  /// Inicjalizacja serwisu powiadomień
  static Future<void> inicjalizuj(BuildContext context) async {
    _context = context;

    // Poproś o uprawnienia
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: true,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ Uprawnienia do powiadomień przyznane');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      debugPrint('⚠️ Tymczasowe uprawnienia do powiadomień');
    } else {
      debugPrint('❌ Uprawnienia do powiadomień odrzucone');
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      await _skonfigurujKanalyAndroid();
    }

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // Pobierz FCM token
    String? token;
    if (kIsWeb) {
      const webVapidKey = String.fromEnvironment('WEB_VAPID_KEY');
      if (webVapidKey.isNotEmpty) {
        token = await _messaging.getToken(vapidKey: webVapidKey);
      } else {
        debugPrint(
            '⚠️ Brak WEB_VAPID_KEY - token web może się nie wygenerować');
        token = await _messaging.getToken();
      }
    } else {
      token = await _messaging.getToken();
    }
    _fcmToken = token;
    debugPrint('📱 FCM Token: $token');

    // Zapisz token w Firestore dla użytkownika
    if (token != null) {
      await zapiszTokenWBazie(token);
    }

    if (!kIsWeb) {
      await _messaging.subscribeToTopic('all');
      debugPrint('✅ Subskrypcja tematu FCM: all');
    }

    // Nasłuchuj na zmiany tokenu
    _messaging.onTokenRefresh.listen((newToken) async {
      _fcmToken = newToken;
      debugPrint('🔄 FCM Token odświeżony: $newToken');
      await zapiszTokenWBazie(newToken);
    });

    // Obsługa powiadomień w foreground (aplikacja otwarta)
    FirebaseMessaging.onMessage.listen(_obsluzPowiadomienieWForeground);

    // Obsługa kliknięcia w powiadomienie gdy app jest w tle
    FirebaseMessaging.onMessageOpenedApp.listen(_obsluzKliknieciePowiadomienia);

    // Sprawdź czy aplikacja została uruchomiona przez kliknięcie w powiadomienie
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _obsluzKliknieciePowiadomienia(initialMessage);
    }
  }

  /// Obsługa powiadomienia gdy aplikacja jest otwarta
  static Future<void> _obsluzPowiadomienieWForeground(
      RemoteMessage message) async {
    debugPrint(
        '📨 Otrzymano powiadomienie w foreground: ${message.notification?.title}');

    final data = message.data;
    final type = data['type'] ?? '';

    if (type == 'alarm' || type == 'ALARM') {
      final tytul = message.notification?.title ?? data['title'] ?? 'ALARM';
      final opis = message.notification?.body ?? data['body'] ?? '';
      // ALARM - pokaż pełnoekranowy ekran i włącz syrenę
      await _odtworzSyrene();
      _pokazEkranAlarmu(message, tytul: tytul, opis: opis);
    } else {
      // Zwykłe powiadomienie - pokaż SnackBar
      if (_context != null && _context!.mounted) {
        ScaffoldMessenger.of(_context!).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.notifications, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.notification?.title ?? 'Powiadomienie',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (message.notification?.body != null)
                        Text(message.notification!.body!),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.blue[700],
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Zobacz',
              textColor: Colors.white,
              onPressed: () => _obsluzKliknieciePowiadomienia(message),
            ),
          ),
        );
      }
    }
  }

  /// Obsługa kliknięcia w powiadomienie
  static void _obsluzKliknieciePowiadomienia(RemoteMessage message) {
    debugPrint('👆 Kliknięto w powiadomienie: ${message.notification?.title}');

    final data = message.data;
    final type = data['type'] ?? '';

    if (type == 'alarm' || type == 'ALARM') {
      final tytul = message.notification?.title ?? data['title'] ?? 'ALARM';
      final opis = message.notification?.body ?? data['body'] ?? '';
      _pokazEkranAlarmu(message, tytul: tytul, opis: opis);
    }
    // Tutaj można dodać obsługę innych typów powiadomień
  }

  /// Pokazuje pełnoekranowy ekran alarmu
  static void _pokazEkranAlarmu(RemoteMessage message,
      {String? tytul, String? opis}) {
    if (_context == null || !_context!.mounted) return;

    final data = message.data;

    Navigator.of(_context!).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => EkranAlarmufullscreen(
          tytul:
              tytul ?? message.notification?.title ?? data['title'] ?? 'ALARM',
          lokalizacja: data['lokalizacja'] ?? 'Brak lokalizacji',
          kategoria: data['kategoria'] ?? 'Alarm',
          opis: opis ??
              message.notification?.body ??
              data['body'] ??
              data['opis'] ??
              '',
          wyjazdId: data['wyjazdId'],
          godzina: data['godzina'] ?? DateTime.now().toString(),
        ),
      ),
    );
  }

  /// Odtwarza dźwięk syreny alarmowej
  static Future<void> _odtworzSyrene() async {
    try {
      // Zatrzymaj poprzednie odtwarzanie
      await _audioPlayer.stop();

      // Ustaw kontekst audio na ALARM (używa głośności budzika)
      await _audioPlayer.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {
              AVAudioSessionOptions.mixWithOthers,
              AVAudioSessionOptions.duckOthers,
            },
          ),
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm, // UŻYJ KANAŁU ALARMU
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );

      // Ustaw maksymalną głośność
      await _audioPlayer.setVolume(1.0);

      // Odtwórz syrenę w pętli
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);

      try {
        // Próbuj odtworzyć nowy plik syreny
        await _audioPlayer.play(AssetSource('sounds/syrena-2.mp3'));
      } catch (e) {
        debugPrint('Brak pliku syrena-2.mp3, próba alternatywnego pliku: $e');
        try {
          await _audioPlayer.play(AssetSource('sounds/siren.mp3'));
        } catch (e2) {
          debugPrint('Brak pliku siren.mp3: $e2');
        }
      }
    } catch (e) {
      debugPrint('Błąd odtwarzania syreny: $e');
    }
  }

  static Future<void> _skonfigurujKanalyAndroid() async {
    await _inicjalizujLocalNotifications();
    const alarmChannel = AndroidNotificationChannel(
      'alarm_channel',
      'Alarmy',
      description: 'Powiadomienia alarmowe OSP',
      importance: Importance.max,
      playSound: true,
    );

    const discordChannel = AndroidNotificationChannel(
      'discord_channel',
      'Discord',
      description: 'Powiadomienia z Discorda',
      importance: Importance.high,
    );

    const defaultChannel = AndroidNotificationChannel(
      'default_channel',
      'Powiadomienia',
      description: 'Ogólne powiadomienia aplikacji',
      importance: Importance.high,
    );

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    await androidPlugin.createNotificationChannel(alarmChannel);
    await androidPlugin.createNotificationChannel(discordChannel);
    await androidPlugin.createNotificationChannel(defaultChannel);
  }

  static Future<void> _inicjalizujLocalNotifications() async {
    if (_localNotificationsReady) return;
    const settings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: settings);
    await _localNotifications.initialize(initSettings);
    _localNotificationsReady = true;
  }

  static Future<void> obsluzPowiadomienieWTle(RemoteMessage message) async {
    final data = message.data;
    final type = data['type'] ?? '';

    if (defaultTargetPlatform != TargetPlatform.android) return;
    if (type != 'ALARM' && type != 'alarm') return;

    await _skonfigurujKanalyAndroid();

    final tytul = data['title'] ?? 'ALARM';
    final opis = data['body'] ?? data['opis'] ?? '';

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'alarm_channel',
        'Alarmy',
        channelDescription: 'Powiadomienia alarmowe OSP',
        importance: Importance.max,
        priority: Priority.max,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        playSound: true,
        ticker: 'ALARM',
      ),
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      tytul,
      opis,
      details,
    );
  }

  /// Zatrzymuje syrenę
  static Future<void> zatrzymajSyrene() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('Błąd zatrzymywania syreny: $e');
    }
  }

  /// Wysyła powiadomienie testowe (tylko dla testów)
  static Future<void> wyslijTestowyAlarm() async {
    if (_context == null) return;

    // Symuluj otrzymanie powiadomienia
    final testMessage = RemoteMessage(
      notification: const RemoteNotification(
        title: '🚨 ALARM TESTOWY',
        body: 'Pożar budynku mieszkalnego',
      ),
      data: {
        'type': 'ALARM',
        'kategoria': 'Pożar',
        'lokalizacja': 'Kolumna, ul. Główna 15',
        'opis':
            'Zgłoszenie pożaru budynku mieszkalnego. Dym widoczny z daleka.',
        'godzina': DateTime.now().toString(),
      },
    );

    await _obsluzPowiadomienieWForeground(testMessage);
  }

  /// Zapisuje FCM token użytkownika w Firestore
  static Future<void> zapiszTokenWBazie(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('strazacy')
          .doc(user.uid)
          .update({
        'fcmToken': token,
        'ostatniaAktualizacjaTokenu': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ FCM token zapisany w bazie');
    } catch (e) {
      debugPrint('❌ Błąd zapisu FCM tokenu: $e');
    }
  }

  /// Wysyła powiadomienie o nowym wyjeździe do wszystkich strażaków
  static Future<void> wyslijPowiadomienieOWyjezdzie({
    required String wyjazdId,
    required String kategoria,
    required String lokalizacja,
    String? opis,
  }) async {
    try {
      await _wyslijPushDoWszystkich(
        type: 'ALARM',
        title: '🚨 ALARM!',
        body: '$kategoria - $lokalizacja',
        data: {
          'wyjazdId': wyjazdId,
          'kategoria': kategoria,
          'lokalizacja': lokalizacja,
          'opis': opis ?? '',
        },
      );
    } catch (e) {
      debugPrint('❌ Błąd wysyłania powiadomienia: $e');
    }
  }

  /// Wysyła powiadomienie o nowym wydarzeniu (szkolenie, ćwiczenia, itp.)
  static Future<void> wyslijPowiadomienieOWydarzeniu({
    required String wydarzenieId,
    required String tytul,
    required String typWydarzenia,
    required DateTime dataRozpoczecia,
  }) async {
    try {
      await _wyslijPushDoWszystkich(
        type: 'WYDARZENIE',
        title: '📅 Nowe wydarzenie: $typWydarzenia',
        body: tytul,
        data: {
          'wydarzenieId': wydarzenieId,
          'typWydarzenia': typWydarzenia,
          'dataRozpoczecia': dataRozpoczecia.toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('❌ Błąd wysyłania powiadomienia o wydarzeniu: $e');
    }
  }

  /// Wysyła przypomnienie o nadchodzącym wydarzeniu (1 dzień wcześniej)
  static Future<void> wyslijPrzypomnienieOWydarzeniu({
    required String wydarzenieId,
    required String tytul,
    required DateTime dataRozpoczecia,
  }) async {
    try {
      await _wyslijPushDoWszystkich(
        type: 'PRZYPOMNIENIE',
        title: '⏰ Przypomnienie',
        body: 'Jutro: $tytul',
        data: {
          'wydarzenieId': wydarzenieId,
          'dataRozpoczecia': dataRozpoczecia.toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('❌ Błąd wysyłania przypomnienia: $e');
    }
  }

  static Future<void> _wyslijPushDoWszystkich({
    required String type,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    if (_pushBackendUrl.isEmpty || _pushBackendToken.isEmpty) {
      debugPrint('⚠️ Brak konfiguracji PUSH_BACKEND_URL/PUSH_BACKEND_TOKEN');
      return;
    }

    final uri = Uri.parse('$_pushBackendUrl/notify');
    final payload = <String, dynamic>{
      'type': type,
      'title': title,
      'body': body,
      'data': data ?? <String, String>{},
    };

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Admin-Token': _pushBackendToken,
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint('❌ Push backend error: ${response.statusCode}');
      return;
    }

    debugPrint('✅ Push wyslany do wszystkich');
  }

  /// Pobiera aktualny FCM token
  static String? get fcmToken => _fcmToken;
}

/// Obsługa powiadomień w tle (musi być funkcją top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📨 Otrzymano powiadomienie w tle: ${message.notification?.title}');

  // Tutaj możesz dodać logikę dla powiadomień w tle
  // Np. zapisanie do lokalnej bazy danych
}
