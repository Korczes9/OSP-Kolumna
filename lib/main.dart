import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'screens/ekran_logowania_nowy.dart';
import 'screens/ekran_domowy_osp.dart';
import 'screens/ekran_oczekiwania_na_zatwierdzenie.dart';
import 'services/serwis_cache_lokalnego.dart';
import 'services/serwis_autentykacji_nowy.dart';
import 'services/eremiza_service.dart';
import 'services/serwis_motywu.dart';
import 'services/serwis_powiadomien.dart';
import 'services/realtime_service_manager.dart';
import 'services/serwis_ekwiwalentow.dart';
import 'models/strazak.dart';

/// Handler dla powiadomień w tle (musi być top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('📨 Powiadomienie w tle: ${message.notification?.title}');
  try {
    // Log do pliku na potrzeby debugowania działania w tle
    final file = File('/storage/emulated/0/osp_alarm_log.txt');
    final now = DateTime.now();
    await file.writeAsString('[${now.toIso8601String()}] Powiadomienie w tle: ${message.notification?.title}\n', mode: FileMode.append);
  } catch (e) {
    debugPrint('Błąd zapisu logu w tle: ${e.toString()}');
  }
  await SerwisPowiadomien.obsluzPowiadomienieWTle(message);
}

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      // Inicjalizacja Hive dla lokalnego cache
      debugPrint('[INIT] Uruchamianie Hive...');
      await Hive.initFlutter();
      await SerwisCacheLokalne.init();
      debugPrint('[INIT] ✓ Hive gotowy');

      // Inicjalizacja Firebase
      debugPrint('[INIT] Uruchamianie Firebase...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('[INIT] ✓ Firebase gotowy');

      // UWAGA: Firestore persistence jest domyślnie włączone na Android/iOS
      // Nie ustawiamy settings ręcznie, bo background handler może już użyć Firestore
      debugPrint('[INIT] ✓ Firestore (persistence: domyślne ustawienia)');

      // Inicjalizacja stawek ekwiwalentu z Firestore
      debugPrint('[INIT] Ładowanie stawek ekwiwalentu...');
      await SerwisEkwiwalentow.init();
      debugPrint('[INIT] ✓ Stawki ekwiwalentu załadowane');

      // Inicjalizacja Firebase Cloud Messaging dla powiadomień w tle
      debugPrint('[INIT] Konfiguracja FCM...');
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
      debugPrint('[INIT] ✓ FCM gotowy');

      // Uruchomienie auto-sync eRemiza (jeśli skonfigurowane)
      debugPrint('[INIT] Sprawdzanie konfiguracji eRemiza...');
      final eremizaService = EremizaService();
      final hasCredentials = await eremizaService.loadCredentials();
      if (hasCredentials) {
        eremizaService.startAutoSync();
        debugPrint('[INIT] ✓ Auto-sync eRemiza uruchomiony');
      } else {
        debugPrint('[INIT] ⏭️ eRemiza nie skonfigurowana');
      }

      // Uruchomienie Foreground Service (tylko Android)
      if (Platform.isAndroid) {
        debugPrint('[INIT] Uruchamianie Foreground Service...');
        final serviceLaunched = await RealtimeServiceManager.startService();
        if (serviceLaunched) {
          debugPrint('[INIT] ✓ Foreground Service uruchomiony');
        } else {
          debugPrint('[INIT] ⚠️ Nie udało się uruchomić Foreground Service');
        }
      }

      debugPrint('[INIT] ✓ Uruchamianie aplikacji...');
      runApp(const AplikacjaLogowania());
    } catch (e, stack) {
      debugPrint('[ERROR] Błąd inicjalizacji: $e');
      debugPrint('[ERROR] Stack trace: $stack');
      runApp(MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 80, color: Colors.red),
                  const SizedBox(height: 20),
                  const Text(
                    'Błąd uruchamiania aplikacji',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Szczegóły: $e',
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
    }
  }, (error, stack) {
    debugPrint('[FATAL] Nieobsłużony błąd: $error');
    debugPrint('[FATAL] Stack: $stack');
  });
}

class AplikacjaLogowania extends StatelessWidget {
  const AplikacjaLogowania({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SerwisMotywu(),
      child: const _AplikacjaZMotywem(),
    );
  }
}

class _AplikacjaZMotywem extends StatelessWidget {
  const _AplikacjaZMotywem();

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final serwisMotywu = Provider.of<SerwisMotywu>(context);

    return MaterialApp(
      title: 'OSP Kolumna',
      theme: TematDane.lightTheme(),
      darkTheme: TematDane.darkTheme(),
      themeMode: serwisMotywu.themeMode,
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<User?>(
        stream: authService.authStateChanges,
        builder: (context, snapshot) {
          // Ładowanie
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // Zalogowany
          if (snapshot.hasData && snapshot.data != null) {
            final uid = snapshot.data!.uid;

            return FutureBuilder<Strazak?>(
              future: authService.pobierzStrazaka(uid),
              builder: (context, strazakSnapshot) {
                if (strazakSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                if (strazakSnapshot.hasData && strazakSnapshot.data != null) {
                  final strazak = strazakSnapshot.data!;

                  // Sprawdź czy konto jest zatwierdzone
                  if (!strazak.aktywny) {
                    return EkranOczekiwaniaNaZatwierdzenie(strazak: strazak);
                  }

                  return EkranDomowyOSP(strazak: strazak);
                }

                // Jeśli nie znaleziono danych strażaka, wyloguj
                authService.logout();
                return const EkranLogowania();
              },
            );
          }

          // Niezalogowany
          return const EkranLogowania();
        },
      ),
    );
  }
}

class TematDane {
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.red,
        brightness: Brightness.light,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.red,
        brightness: Brightness.dark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.red[900],
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        elevation: 2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: const BorderSide(color: Color(0xFF404040)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: const BorderSide(color: Color(0xFF404040)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
        ),
        hintStyle: const TextStyle(color: Color(0xFF808080)),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: Colors.blue[400],
        selectionColor: Colors.blue[700]!.withOpacity(0.4),
        selectionHandleColor: Colors.blue[400],
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          color: Color(0xFFD0D0D0), // Jaśniejszy szary dla lepszej widoczności
          fontSize: 12,
        ),
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
      iconTheme: const IconThemeData(
        color: Color(0xFFE0E0E0), // Jaśniejsze ikony dla lepszej widoczności
      ),
      listTileTheme: ListTileThemeData(
        textColor: Colors.white,
        iconColor: const Color(0xFFE0E0E0),
        selectedTileColor: Colors.blue[900]!.withOpacity(0.3),
        selectedColor: Colors.blue[200],
        subtitleTextStyle: const TextStyle(
          color: Color(0xFFD0D0D0), // Jaśniejszy kolor dla napisów podrzędnych
        ),
      ),
    );
  }
}
