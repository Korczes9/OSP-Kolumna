import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/strazak.dart';

/// Ekran pokazujący dostępność strażaków
class EkranDostepnosciStrazakow extends StatefulWidget {
  final Strazak aktualnyStrazak;

  const EkranDostepnosciStrazakow({super.key, required this.aktualnyStrazak});

  @override
  State<EkranDostepnosciStrazakow> createState() =>
      _EkranDostepnosciStrazakowState();
}

class _EkranDostepnosciStrazakowState extends State<EkranDostepnosciStrazakow> {
  final _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dostępność Strażaków'),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('strazacy')
            .where('aktywny', isEqualTo: true)
            .orderBy('dostepny', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Błąd: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final strazacy = snapshot.data!.docs
              .map((doc) =>
                  Strazak.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();

          final dostepni = strazacy.where((s) => s.dostepny).toList();
          final niedostepni = strazacy.where((s) => !s.dostepny).toList();
          
          // Znajdź aktualnego strażaka w liście (aktualna wartość z bazy)
          final mojaAktualnaDostepnosc = strazacy
              .firstWhere(
                (s) => s.id == widget.aktualnyStrazak.id,
                orElse: () => widget.aktualnyStrazak,
              )
              .dostepny;
          final mojaOstatniaZmiana = strazacy
              .firstWhere(
                (s) => s.id == widget.aktualnyStrazak.id,
                orElse: () => widget.aktualnyStrazak,
              )
              .ostatniaZmianaStatusu;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Podsumowanie
              Card(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.green[900]
                    : Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSumaCard(
                        'Dostępni',
                        dostepni.length.toString(),
                        Icons.check_circle,
                        Colors.green,
                      ),
                      _buildSumaCard(
                        'Niedostępni',
                        niedostepni.length.toString(),
                        Icons.cancel,
                        Colors.red,
                      ),
                      _buildSumaCard(
                        'Razem',
                        strazacy.length.toString(),
                        Icons.people,
                        Colors.blue,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Mój status
                Card(
                color: mojaAktualnaDostepnosc
                  ? (Theme.of(context).brightness == Brightness.dark
                    ? Colors.green[900]
                    : Colors.green[50])
                  : (Theme.of(context).brightness == Brightness.dark
                    ? Colors.orange[900]
                    : Colors.orange[50]),
                child: ListTile(
                  leading: Icon(
                    mojaAktualnaDostepnosc
                        ? Icons.check_circle
                        : Icons.cancel,
                    color: mojaAktualnaDostepnosc
                        ? Colors.green
                        : Colors.orange,
                    size: 40,
                  ),
                  title: Text(
                    'Twój status: ${mojaAktualnaDostepnosc ? "DOSTĘPNY" : "NIEDOSTĘPNY"}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: mojaOstatniaZmiana != null
                      ? Text(
                          'Zmieniono: ${_formatujDate(mojaOstatniaZmiana)}',
                        )
                      : null,
                  trailing: Switch(
                    value: mojaAktualnaDostepnosc,
                    onChanged: (value) => _zmienStatus(value),
                    activeThumbColor: Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Lista dostępnych
              if (dostepni.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Dostępni (${dostepni.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...dostepni.map((s) => _buildStrazakCard(s, true)),
                const SizedBox(height: 24),
              ],

              // Lista niedostępnych
              if (niedostepni.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.cancel, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      'Niedostępni (${niedostepni.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...niedostepni.map((s) => _buildStrazakCard(s, false)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSumaCard(
      String label, String wartosc, IconData ikona, Color kolor) {
    return Column(
      children: [
        Icon(ikona, color: kolor, size: 32),
        const SizedBox(height: 4),
        Text(
          wartosc,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: kolor,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildStrazakCard(Strazak strazak, bool dostepny) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: dostepny ? Colors.green : Colors.grey,
          child: Text(
            strazak.imie[0] + strazak.nazwisko[0],
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          strazak.pelneImie,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strazak.rola.nazwa),
            if (strazak.ostatniaZmianaStatusu != null)
              Text(
                'Zmiana: ${_formatujDate(strazak.ostatniaZmianaStatusu!)}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        trailing: Icon(
          dostepny ? Icons.check_circle : Icons.cancel,
          color: dostepny ? Colors.green : Colors.red,
        ),
      ),
    );
  }

  String _formatujDate(DateTime data) {
    final now = DateTime.now();
    final diff = now.difference(data);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min temu';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} godz. temu';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} dni temu';
    } else {
      return '${data.day}.${data.month}.${data.year}';
    }
  }

  Future<void> _zmienStatus(bool nowyStatus) async {
    try {
      await _firestore
          .collection('strazacy')
          .doc(widget.aktualnyStrazak.id)
          .update({
        'dostepny': nowyStatus,
        'ostatniaZmianaStatusu': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nowyStatus
                  ? 'Ustawiono status: DOSTĘPNY'
                  : 'Ustawiono status: NIEDOSTĘPNY',
            ),
            backgroundColor: nowyStatus ? Colors.green : Colors.orange,
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
}
