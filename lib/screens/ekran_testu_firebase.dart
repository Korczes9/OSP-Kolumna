import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Ekran testowy do diagnostyki połączenia Firebase
class EkranTestuFirebase extends StatefulWidget {
  const EkranTestuFirebase({super.key});

  @override
  State<EkranTestuFirebase> createState() => _EkranTestuFirebaseState();
}

class _EkranTestuFirebaseState extends State<EkranTestuFirebase> {
  final _emailController = TextEditingController(text: 'test@ospkolumna.pl');
  final _hasloController = TextEditingController(text: 'test123456');
  
  bool _testowanie = false;
  final List<String> _logi = [];

  void _dodajLog(String log) {
    if (mounted) {
      setState(() {
        _logi.add('[${DateTime.now().toLocal().toString().substring(11, 19)}] $log');
      });
    }
    debugPrint(log);
  }

  Future<void> _testujPolaczenie() async {
    setState(() {
      _testowanie = true;
      _logi.clear();
    });

    try {
      _dodajLog('🔍 START TESTU FIREBASE');
      _dodajLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // Test 1: Czy Firebase jest zainicjalizowany
      _dodajLog('📊 Test 1: Inicjalizacja Firebase');
      try {
        final auth = FirebaseAuth.instance;
        final firestore = FirebaseFirestore.instance;
        _dodajLog('✅ Firebase zainicjalizowany');
        _dodajLog('   Auth: ${auth.app.name}');
        _dodajLog('   Firestore: ${firestore.app.name}');
      } catch (e) {
        _dodajLog('❌ Firebase NIE zainicjalizowany: $e');
        return;
      }

      await Future.delayed(const Duration(milliseconds: 500));

      // Test 2: Próba odczytu kolekcji strazacy
      _dodajLog('');
      _dodajLog('📁 Test 2: Odczyt Firestore (kolekcja strazacy)');
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('strazacy')
            .limit(5)
            .get(const GetOptions(source: Source.server)); // Wymuszamy serwer, nie cache
        
        _dodajLog('✅ Połączono z Firestore');
        _dodajLog('   Znaleziono dokumentów: ${snapshot.size}');
        
        if (snapshot.docs.isNotEmpty) {
          _dodajLog('   Przykładowe dokumenty:');
          for (var doc in snapshot.docs.take(3)) {
            final data = doc.data();
            _dodajLog('      - ${data['email']} (${data['imie']} ${data['nazwisko']})');
          }
        } else {
          _dodajLog('   ⚠️  Kolekcja strazacy jest PUSTA!');
        }
      } catch (e) {
        _dodajLog('❌ Błąd odczytu Firestore: $e');
      }

      await Future.delayed(const Duration(milliseconds: 500));

      // Test 3: Próba logowania (tylko jeśli podano email i hasło)
      if (_emailController.text.isNotEmpty && _hasloController.text.isNotEmpty) {
        _dodajLog('');
        _dodajLog('🔐 Test 3: Logowanie Firebase Authentication');
        _dodajLog('   Email: ${_emailController.text}');
        
        try {
          final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _hasloController.text,
          );
          
          _dodajLog('✅ Zalogowano do Authentication');
          _dodajLog('   UID: ${userCredential.user!.uid}');
          _dodajLog('   Email: ${userCredential.user!.email}');

          await Future.delayed(const Duration(milliseconds: 500));

          // Test 4: Pobierz dokument użytkownika z Firestore
          _dodajLog('');
          _dodajLog('📄 Test 4: Pobranie dokumentu użytkownika z Firestore');
          try {
            final doc = await FirebaseFirestore.instance
                .collection('strazacy')
                .doc(userCredential.user!.uid)
                .get(const GetOptions(source: Source.server));
            
            if (doc.exists) {
              final data = doc.data()!;
              _dodajLog('✅ Dokument użytkownika istnieje');
              _dodajLog('   Imię: ${data['imie']}');
              _dodajLog('   Nazwisko: ${data['nazwisko']}');
              _dodajLog('   Aktywny: ${data['aktywny']}');
              _dodajLog('   Role: ${data['role']}');
              
              if (data['aktywny'] == true) {
                _dodajLog('✅ KONTO AKTYWNE - logowanie powinno działać!');
              } else {
                _dodajLog('❌ KONTO NIEAKTYWNE - logowanie zablokowane');
              }
            } else {
              _dodajLog('❌ Dokument użytkownika NIE ISTNIEJE w Firestore!');
              _dodajLog('   To jest PROBLEM - konto w Auth, but brak w Firestore');
            }
          } catch (e) {
            _dodajLog('❌ Błąd pobierania dokumentu: $e');
          }

          // Wyloguj po teście
          await FirebaseAuth.instance.signOut();
          _dodajLog('📤 Wylogowano');
          
        } on FirebaseAuthException catch (e) {
          _dodajLog('❌ Błąd logowania Authentication');
          _dodajLog('   Kod: ${e.code}');
          _dodajLog('   Komunikat: ${e.message}');
          
          if (e.code == 'user-not-found') {
            _dodajLog('   💡 Użytkownik nie istnieje w Authentication');
          } else if (e.code == 'wrong-password') {
            _dodajLog('   💡 Nieprawidłowe hasło');
          }
        } catch (e) {
          _dodajLog('❌ Nieoczekiwany błąd logowania: $e');
        }
      }

      _dodajLog('');
      _dodajLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _dodajLog('✅ TEST ZAKOŃCZONY');

    } catch (e) {
      _dodajLog('❌ KRYTYCZNY BŁĄD: $e');
    } finally {
      setState(() {
        _testowanie = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧪 Test Firebase'),
        backgroundColor: Colors.blue[700],
      ),
      body: Column(
        children: [
          // Info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Diagnostyka Firebase',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ten ekran sprawdzi czy aplikacja może się połączyć z Firebase.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),

          // Pola logowania
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email testowy',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _hasloController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Hasło testowe',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _testowanie ? null : _testujPolaczenie,
                  icon: _testowanie
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(_testowanie ? 'Testowanie...' : 'Uruchom test'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // Logi
          Expanded(
            child: _logi.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.science_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Kliknij "Uruchom test" aby sprawdzić Firebase',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _logi.length,
                    itemBuilder: (context, index) {
                      final log = _logi[index];
                      Color color = Colors.black87;
                      
                      if (log.contains('✅')) {
                        color = Colors.green[700]!;
                      } else if (log.contains('❌')) {
                        color = Colors.red[700]!;
                      } else if (log.contains('⚠️') || log.contains('💡')) {
                        color = Colors.orange[700]!;
                      }
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: color,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _hasloController.dispose();
    super.dispose();
  }
}
