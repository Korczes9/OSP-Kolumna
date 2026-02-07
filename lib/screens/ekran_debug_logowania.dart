import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Ekran diagnostyczny do debugowania problemów z logowaniem
class EkranDebugLogowania extends StatefulWidget {
  const EkranDebugLogowania({super.key});

  @override
  State<EkranDebugLogowania> createState() => _EkranDebugLogowaniaState();
}

class _EkranDebugLogowaniaState extends State<EkranDebugLogowania> {
  final _emailController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _sprawdzanie = false;
  Map<String, dynamic>? _wyniki;

  Future<void> _sprawdzKonto() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wprowadź adres email')),
      );
      return;
    }

    setState(() {
      _sprawdzanie = true;
      _wyniki = null;
    });

    final email = _emailController.text.trim();
    Map<String, dynamic> wyniki = {
      'email': email,
      'timestamp': DateTime.now().toString(),
    };

    try {
      // 1. Sprawdź czy użytkownik istnieje w Authentication
      // UWAGA: fetchSignInMethodsForEmail została usunięta w nowej wersji Firebase
      // Sprawdź tylko Firestore - konto musi istnieć w obu miejscach
      wyniki['auth_note'] = 'Sprawdź Firebase Console → Authentication → Users ręcznie';
      wyniki['auth_exists'] = 'Sprawdzane tylko w Firestore';

      // 2. Sprawdź czy istnieje dokument w Firestore
      try {
        final query = await _firestore
            .collection('strazacy')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          final doc = query.docs.first;
          wyniki['firestore_exists'] = true;
          wyniki['firestore_id'] = doc.id;
          wyniki['firestore_data'] = doc.data();
          
          // Wyciągnij kluczowe pola
          final dane = doc.data();
          wyniki['aktywny'] = dane['aktywny'] ?? false;
          wyniki['imie'] = dane['imie'] ?? 'brak';
          wyniki['nazwisko'] = dane['nazwisko'] ?? 'brak';
          wyniki['role'] = dane['role'] ?? [];
        } else {
          wyniki['firestore_exists'] = false;
          wyniki['firestore_error'] = 'Brak dokumentu w kolekcji strazacy';
        }
      } catch (e) {
        wyniki['firestore_exists'] = false;
        wyniki['firestore_error'] = e.toString();
      }

      // 3. Diagnoza problemu
      final List<String> problemy = [];
      final List<String> rozwiazania = [];

      if (wyniki['auth_exists'] == false) {
        problemy.add('❌ Konto nie istnieje w Firebase Authentication');
        rozwiazania.add('Zarejestruj się ponownie w aplikacji');
      }

      if (wyniki['firestore_exists'] == false) {
        problemy.add('❌ Brak dokumentu w Firestore (kolekcja: strazacy)');
        rozwiazania.add('Administrator musi utworzyć dokument ręcznie lub użytkownik ponownie się zarejestrować');
      }

      if (wyniki['aktywny'] == false) {
        problemy.add('❌ Konto nieaktywne (aktywny: false)');
        rozwiazania.add('Administrator musi zatwierdzić konto w: Zarządzanie strażakami');
      }

      if (problemy.isEmpty) {
        problemy.add('✅ Konto wygląda poprawnie!');
        rozwiazania.add('Spróbuj zalogować się ponownie. Jeśli problem się powtarza, sprawdź hasło.');
      }

      wyniki['problemy'] = problemy;
      wyniki['rozwiazania'] = rozwiazania;

    } catch (e) {
      wyniki['global_error'] = e.toString();
    }

    setState(() {
      _wyniki = wyniki;
      _sprawdzanie = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔍 Debug Logowania'),
        backgroundColor: Colors.orange[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Ekran diagnostyczny',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[900],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Wprowadź adres email, aby sprawdzić stan konta i zdiagnozować problemy z logowaniem.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Pole email
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'np. strazak@ospkolumna.pl',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            // Przycisk sprawdzania
            ElevatedButton.icon(
              onPressed: _sprawdzanie ? null : _sprawdzKonto,
              icon: _sprawdzanie
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.search),
              label: Text(_sprawdzanie ? 'Sprawdzam...' : 'Sprawdź konto'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 24),

            // Wyniki
            if (_wyniki != null) ...[
              _buildWynikiCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWynikiCard() {
    final wyniki = _wyniki!;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nagłówek
            Row(
              children: [
                Icon(Icons.analytics_outlined, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Wyniki diagnozy',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Email
            _buildInfoRow('Email', wyniki['email']),
            const SizedBox(height: 8),

            // Firebase Authentication
            _buildInfoRow(
              'Firebase Authentication',
              wyniki['auth_exists'] == true ? '✅ Istnieje' : '❌ Nie istnieje',
            ),
            const SizedBox(height: 8),

            // Firestore
            _buildInfoRow(
              'Firestore (strazacy)',
              wyniki['firestore_exists'] == true ? '✅ Istnieje' : '❌ Nie istnieje',
            ),
            
            if (wyniki['firestore_exists'] == true) ...[
              const SizedBox(height: 8),
              _buildInfoRow('ID dokumentu', wyniki['firestore_id']),
              const SizedBox(height: 8),
              _buildInfoRow(
                'Status aktywacji',
                wyniki['aktywny'] == true ? '✅ Aktywne' : '❌ Nieaktywne',
              ),
              const SizedBox(height: 8),
              _buildInfoRow('Imię i nazwisko', '${wyniki['imie']} ${wyniki['nazwisko']}'),
              const SizedBox(height: 8),
              _buildInfoRow('Role', wyniki['role'].toString()),
            ],

            const Divider(height: 24),

            // Problemy
            if (wyniki['problemy'] != null) ...[
              const Text(
                'Zdiagnozowane problemy:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...((wyniki['problemy'] as List).map((problem) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      problem,
                      style: TextStyle(
                        color: problem.startsWith('✅') ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                  ))),
              const SizedBox(height: 16),

              // Rozwiązania
              const Text(
                'Zalecane działania:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...((wyniki['rozwiazania'] as List).map((rozwiazanie) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(child: Text(rozwiazanie)),
                      ],
                    ),
                  ))),
            ],

            // Błędy
            if (wyniki['global_error'] != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Błąd',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      wyniki['global_error'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[900],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 160,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}
