import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Ekran do automatycznego importu użytkowników OSP Kolumna
class EkranImportuUzytkownikow extends StatefulWidget {
  const EkranImportuUzytkownikow({super.key});

  @override
  State<EkranImportuUzytkownikow> createState() =>
      _EkranImportuUzytkownikowState();
}

class _EkranImportuUzytkownikowState extends State<EkranImportuUzytkownikow> {
  final _firestore = FirebaseFirestore.instance;
  bool _importowanie = false;
  final List<String> _logi = [];

  // Dane użytkowników do zaimportowania
  final Map<String, Map<String, dynamic>> _uzytkownicyDoImportu = {
    'korczes9@gmail.com': {
      'imie': 'Sebastian',
      'nazwisko': 'Grochulski',
      'rola': 'administrator',
    },
    'osp_kolumna@straz.edu.pl': {
      'imie': 'OSP',
      'nazwisko': 'Kolumna',
      'rola': 'moderator',
    },
    '2bora@wp.pl': {
      'imie': 'Dariusz',
      'nazwisko': 'Borkiewicz',
      'rola': 'strazak',
    },
    'patrykborzecki11@gmail.com': {
      'imie': 'Patryk',
      'nazwisko': 'Borzęcki',
      'rola': 'strazak',
    },
    'krystianof12@interia.pl': {
      'imie': 'Krystian',
      'nazwisko': 'Felcenloben',
      'rola': 'strazak',
    },
    'kamil1703@o2.pl': {
      'imie': 'Kamil',
      'nazwisko': 'Grzelak',
      'rola': 'strazak',
    },
    'domio123dko@gmail.com': {
      'imie': 'Dominik',
      'nazwisko': 'Kłos',
      'rola': 'strazak',
    },
    'kacper.knop4@wp.pl': {
      'imie': 'Kacper',
      'nazwisko': 'Knop',
      'rola': 'strazak',
    },
    'hubert.469b@gmail.com': {
      'imie': 'Hubert',
      'nazwisko': 'Kowalski',
      'rola': 'strazak',
    },
    'korkihard9@wp.pl': {
      'imie': 'Jerzy',
      'nazwisko': 'Kowalski',
      'rola': 'strazak',
    },
    'kamil.kubsz@o2.pl': {
      'imie': 'Kamil',
      'nazwisko': 'Kubsz',
      'rola': 'strazak',
    },
    'robertkujawa3108@gmail.com': {
      'imie': 'Robert',
      'nazwisko': 'Kujawa',
      'rola': 'strazak',
    },
    'kubamarki@gmail.com': {
      'imie': 'Jakub',
      'nazwisko': 'Markiewicz',
      'rola': 'strazak',
    },
    'michalmataska201@go2.pl': {
      'imie': 'Michał',
      'nazwisko': 'Mataśka',
      'rola': 'strazak',
    },
    'bartek1292001@wp.pl': {
      'imie': 'Bartłomiej',
      'nazwisko': 'Nowicki',
      'rola': 'strazak',
    },
    'palmateusz641@gmail.com': {
      'imie': 'Mateusz',
      'nazwisko': 'Paliwoda',
      'rola': 'strazak',
    },
    'dpawlak@autograf.pl': {
      'imie': 'Damian',
      'nazwisko': 'Pawlak',
      'rola': 'strazak',
    },
    'ppiecyk@onet.pl': {
      'imie': 'Piotr',
      'nazwisko': 'Piecyk',
      'rola': 'strazak',
    },
  };

  void _dodajLog(String wiadomosc) {
    setState(() {
      _logi.add(wiadomosc);
    });
  }

  Future<void> _importujUzytkownikow() async {
    setState(() {
      _importowanie = true;
      _logi.clear();
    });

    _dodajLog('🚀 Rozpoczynam import użytkowników...\n');

    try {
      // Pobierz wszystkich użytkowników z Authentication
      // UWAGA: To wymaga uprawnień admin - możemy to zrobić inaczej
      _dodajLog(
          '📋 Znaleziono ${_uzytkownicyDoImportu.length} użytkowników do zaimportowania\n');

      int dodanych = 0;
      int pominieto = 0;
      int bledow = 0;

      // Próbuj dopasować użytkowników po email
      for (var entry in _uzytkownicyDoImportu.entries) {
        final email = entry.key;
        final dane = entry.value;

        try {
          // Spróbuj znaleźć użytkownika w Firestore
          final querySnapshot = await _firestore
              .collection('strazacy')
              .where('email', isEqualTo: email)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            _dodajLog('⚠️  Pominięto: $email (już istnieje)');
            pominieto++;
            continue;
          }

          // Utwórz dokument używając losowego ID
          // UWAGA: Najlepiej byłoby użyć User UID z Authentication
          final docRef = _firestore.collection('strazacy').doc();

          await docRef.set({
            'imie': dane['imie'],
            'nazwisko': dane['nazwisko'],
            'email': email,
            'numerTelefonu': '000000000',
            'rola': dane['rola'],
            'aktywny': true,
            'dataRejestracji': DateTime.now().toIso8601String(),
          });

          _dodajLog('✅ Dodano: ${dane['imie']} ${dane['nazwisko']} ($email)');
          dodanych++;
        } catch (e) {
          _dodajLog('❌ Błąd dla $email: $e');
          bledow++;
        }
      }

      _dodajLog('\n${'=' * 50}');
      _dodajLog('✅ Dodanych: $dodanych');
      _dodajLog('⚠️  Pominiętych: $pominieto');
      _dodajLog('❌ Błędów: $bledow');
      _dodajLog('=' * 50);

      if (dodanych > 0) {
        _dodajLog('\n🎉 Import zakończony!');

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Zaimportowano $dodanych użytkowników!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _dodajLog('\n❌ Krytyczny błąd: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Błąd importu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _importowanie = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import użytkowników OSP'),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange[700]),
                        const SizedBox(width: 8),
                        const Text(
                          'Automatyczny import',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ten ekran automatycznie zaimportuje ${_uzytkownicyDoImportu.length} użytkowników OSP Kolumna do bazy Firestore.',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• 1 Administrator (Sebastian Grochulski)\n'
                      '• 1 Moderator (OSP Kolumna)\n'
                      '• 16 Strażaków',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.yellow[100],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: const Text(
                        'UWAGA: Użytkownicy muszą być najpierw utworzeni w Firebase Authentication z hasłem: ospkolumna123',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _importowanie ? null : _importujUzytkownikow,
              icon: _importowanie
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload),
              label: Text(
                  _importowanie ? 'Importowanie...' : 'Importuj użytkowników'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Logi importu:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ListView.builder(
                  itemCount: _logi.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        _logi[index],
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
