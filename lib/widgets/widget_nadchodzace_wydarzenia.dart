import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wydarzenie.dart';
import '../models/strazak.dart';
import '../screens/ekran_terminarza.dart';

/// Widget pokazujący 5 najbliższych wydarzeń
class WidgetNadchodzaceWydarzenia extends StatelessWidget {
  final Strazak aktualnyStrazak;

  const WidgetNadchodzaceWydarzenia({
    super.key,
    required this.aktualnyStrazak,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.event, color: Colors.orange[700]),
                const SizedBox(width: 8),
                const Text(
                  'Nadchodzące wydarzenia',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          StreamBuilder<QuerySnapshot>(
            stream: _pobierzNadchodzaceWydarzenia(),
            initialData: null,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Błąd: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Brak nadchodzących wydarzeń',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              final wydarzenia = snapshot.data!.docs
                  .map((doc) => Wydarzenie.fromMap(
                        doc.data() as Map<String, dynamic>,
                        doc.id,
                      ))
                  .where((wydarzenie) {
                // Filtruj rezerwacje sali - widoczne tylko dla gospodarza+
                if (wydarzenie.typ == TypWydarzenia.rezerwacjaSali) {
                  return aktualnyStrazak.czyMozeRezerwowacSale;
                }
                
                // Pozostałe wydarzenia widoczne dla wszystkich lub według flagi
                return wydarzenie.widoczneDlaWszystkich || 
                       aktualnyStrazak.jestModeratorem;
              })
                  .take(5)
                  .toList();

              if (wydarzenia.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Brak nadchodzących wydarzeń',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return Column(
                children: wydarzenia.map((wydarzenie) {
                  return _buildWydarzenieListTile(wydarzenie, context);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWydarzenieListTile(Wydarzenie wydarzenie, BuildContext context) {
    final czyJestZapisany = wydarzenie.uczestnicyIds.contains(aktualnyStrazak.id);

    return ListTile(
      dense: true,
      onTap: () {
        // Przejdź do sekcji terminarz
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EkranTerminarza(aktualnyStrazak: aktualnyStrazak),
          ),
        );
      },
      leading: CircleAvatar(
        backgroundColor: _kolorTypu(wydarzenie.typ),
        radius: 20,
        child: Icon(
          _ikonaTypu(wydarzenie.typ),
          color: Colors.white,
          size: 18,
        ),
      ),
      title: Text(
        wydarzenie.tytul,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatujDate(wydarzenie.dataRozpoczecia),
            style: const TextStyle(fontSize: 12),
          ),
          Row(
            children: [
              Icon(
                czyJestZapisany ? Icons.check_circle : Icons.people,
                size: 12,
                color: czyJestZapisany ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                czyJestZapisany
                    ? 'Zapisany • ${wydarzenie.uczestnicyIds.length} osób'
                    : '${wydarzenie.uczestnicyIds.length} osób',
                style: TextStyle(
                  fontSize: 11,
                  color: czyJestZapisany ? Colors.green : Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.grey[400],
        size: 20,
      ),
      isThreeLine: true,
    );
  }

  Stream<QuerySnapshot> _pobierzNadchodzaceWydarzenia() {
    return FirebaseFirestore.instance
        .collection('wydarzenia')
        .where('dataRozpoczecia', isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .orderBy('dataRozpoczecia')
        .limit(10) // Pobierz 10, potem przefiltruj do 5
        .snapshots();
  }

  Color _kolorTypu(TypWydarzenia typ) {
    switch (typ) {
      case TypWydarzenia.szkolenie:
        return Colors.blue;
      case TypWydarzenia.cwiczenia:
        return Colors.green;
      case TypWydarzenia.zebranie:
        return Colors.orange;
      case TypWydarzenia.swieto:
        return Colors.red;
      case TypWydarzenia.rezerwacjaSali:
        return Colors.purple;
      case TypWydarzenia.inne:
        return Colors.grey;
    }
  }

  IconData _ikonaTypu(TypWydarzenia typ) {
    switch (typ) {
      case TypWydarzenia.szkolenie:
        return Icons.school;
      case TypWydarzenia.cwiczenia:
        return Icons.fitness_center;
      case TypWydarzenia.zebranie:
        return Icons.groups;
      case TypWydarzenia.swieto:
        return Icons.celebration;
      case TypWydarzenia.rezerwacjaSali:
        return Icons.meeting_room;
      case TypWydarzenia.inne:
        return Icons.event;
    }
  }

  String _formatujDate(DateTime data) {
    final teraz = DateTime.now();
    final dzisiaj = DateTime(teraz.year, teraz.month, teraz.day);
    final jutro = dzisiaj.add(const Duration(days: 1));
    final dataWydarzenia = DateTime(data.year, data.month, data.day);

    String relativeText;
    if (dataWydarzenia == dzisiaj) {
      relativeText = 'Dziś';
    } else if (dataWydarzenia == jutro) {
      relativeText = 'Jutro';
    } else if (data.difference(teraz).inDays < 7) {
      relativeText = 'Za ${data.difference(teraz).inDays} dni';
    } else {
      relativeText = '${data.day}.${data.month}.${data.year}';
    }

    final czas = '${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
    return '$relativeText, $czas';
  }
}
