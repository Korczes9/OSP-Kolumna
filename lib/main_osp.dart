import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'services/serwis_cache_lokalnego.dart';
import 'dart:async';

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
      
      // Włączenie offline persistence dla Firestore
      debugPrint('[INIT] Konfiguracja Firestore...');
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      debugPrint('[INIT] ✓ Firestore gotowy');
      
      debugPrint('[INIT] ✓ Uruchamianie aplikacji...');
      runApp(const AplikacjaOSPKolumna());
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

class AplikacjaOSPKolumna extends StatelessWidget {
  const AplikacjaOSPKolumna({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OSP Kolumna',
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      home: const LoginScreen(),
    );
  }
}
