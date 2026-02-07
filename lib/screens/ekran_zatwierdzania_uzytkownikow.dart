import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/strazak.dart';

/// Ekran dla administratora - zatwierdzanie nowych użytkowników
class EkranZatwierdzaniaUzytkownikow extends StatefulWidget {
  final Strazak aktualnyStrazak;

  const EkranZatwierdzaniaUzytkownikow({
    super.key,
    required this.aktualnyStrazak,
  });

  @override
  State<EkranZatwierdzaniaUzytkownikow> createState() =>
      _EkranZatwierdzaniaUzytkownikowState();
}

class _EkranZatwierdzaniaUzytkownikowState
    extends State<EkranZatwierdzaniaUzytkownikow> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zatwierdzanie użytkowników'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('strazacy')
            .where('aktywny', isEqualTo: false)
            .orderBy('dataRejestracji', descending: true)
            .snapshots(),
        initialData: null,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Błąd: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final oczekujacy = snapshot.data!.docs;

          if (oczekujacy.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 80,
                    color: Colors.green[300],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Brak oczekujących użytkowników',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Wszyscy użytkownicy zostali zatwierdzeni',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: oczekujacy.length,
            itemBuilder: (context, index) {
              final doc = oczekujacy[index];
              final strazak = Strazak.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              );

              return _buildUzytkownikCard(strazak);
            },
          );
        },
      ),
    );
  }

  Widget _buildUzytkownikCard(Strazak strazak) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange[100],
                  child: Text(
                    strazak.imie[0] + strazak.nazwisko[0],
                    style: TextStyle(
                      color: Colors.orange[900],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strazak.pelneImie,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        strazak.email,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(Icons.phone, 'Telefon', strazak.numerTelefonu),
            _buildInfoRow(
              Icons.calendar_today,
              'Rejestracja',
              _formatujDate(strazak.dataRejestracji),
            ),
            _buildInfoRow(
              Icons.badge,
              'Rola',
              strazak.rola.nazwa,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _zatwierdzUzytkownika(strazak),
                    icon: const Icon(Icons.check),
                    label: const Text('Zatwierdź'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _odrzucUzytkownika(strazak),
                    icon: const Icon(Icons.close),
                    label: const Text('Odrzuć'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Future<void> _zatwierdzUzytkownika(Strazak strazak) async {
    final potwierdz = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zatwierdzenie użytkownika'),
        content: Text(
          'Czy na pewno chcesz zatwierdzić konto użytkownika ${strazak.pelneImie}?\n\n'
          'Użytkownik otrzyma pełny dostęp do aplikacji.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Zatwierdź'),
          ),
        ],
      ),
    );

    if (potwierdz != true) return;

    try {
      await _firestore.collection('strazacy').doc(strazak.id).update({
        'aktywny': true,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Użytkownik ${strazak.pelneImie} został zatwierdzony'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Błąd: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _odrzucUzytkownika(Strazak strazak) async {
    final potwierdz = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Odrzucenie użytkownika'),
        content: Text(
          'Czy na pewno chcesz odrzucić konto użytkownika ${strazak.pelneImie}?\n\n'
          'Konto zostanie usunięte z systemu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );

    if (potwierdz != true) return;

    try {
      // Usuń z Firestore
      await _firestore.collection('strazacy').doc(strazak.id).delete();

      // Tutaj możesz dodać usunięcie z Firebase Auth jeśli potrzeba

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Użytkownik ${strazak.pelneImie} został odrzucony'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Błąd: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatujDate(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}.${data.month.toString().padLeft(2, '0')}.${data.year} ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }
}
