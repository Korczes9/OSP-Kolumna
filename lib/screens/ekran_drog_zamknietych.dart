import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/strazak.dart';
import '../models/droga_zamknieta.dart';

class EkranDrogZamknietych extends StatefulWidget {
  final Strazak strazak;

  const EkranDrogZamknietych({super.key, required this.strazak});

  @override
  State<EkranDrogZamknietych> createState() => _EkranDrogZamknietychState();
}

class _EkranDrogZamknietychState extends State<EkranDrogZamknietych> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drogi zamknięte'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('drogi_zamkniete')
            .orderBy('dataZamkniecia', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Błąd: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final drogi = snapshot.data!.docs.map((doc) {
            return DrogaZamknieta.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList();

          if (drogi.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 80, color: Colors.green[400]),
                  const SizedBox(height: 16),
                  const Text('Brak zamkniętych dróg'),
                  const SizedBox(height: 8),
                  Text(
                    'Wszystkie drogi są przejezdne',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: drogi.length,
            itemBuilder: (context, index) {
              final droga = drogi[index];
              return _buildKartaDrogi(droga);
            },
          );
        },
      ),
      floatingActionButton: widget.strazak.rola.poziom >= 3
          ? FloatingActionButton(
              onPressed: _dodajDroge,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildKartaDrogi(DrogaZamknieta droga) {
    Color kolorStatusu = _kolorStatusu(droga.status);
    IconData ikonaStatusu = _ikonaStatusu(droga.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _pokazSzczegoly(droga),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kolorStatusu.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(ikonaStatusu, color: kolorStatusu, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          droga.nazwa,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          droga.status.nazwa,
                          style: TextStyle(
                            fontSize: 12,
                            color: kolorStatusu,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (droga.odcinek.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.straighten, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        droga.odcinek,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (droga.powod.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        droga.powod,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ],
              if (droga.dataPlanowanegoOtwarcia != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule, size: 14, color: Colors.blue[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Planowane otwarcie: ${_formatujDate(droga.dataPlanowanegoOtwarcia!)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _pokazSzczegoly(DrogaZamknieta droga) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _kolorStatusu(droga.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _ikonaStatusu(droga.status),
                      color: _kolorStatusu(droga.status),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          droga.nazwa,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          droga.status.nazwa,
                          style: TextStyle(
                            fontSize: 14,
                            color: _kolorStatusu(droga.status),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              if (droga.odcinek.isNotEmpty)
                _buildSekcja('Odcinek', droga.odcinek, Icons.straighten),
              if (droga.powod.isNotEmpty)
                _buildSekcja('Powód zamknięcia', droga.powod, Icons.info),
              if (droga.objazd.isNotEmpty)
                _buildSekcja('Objazd', droga.objazd, Icons.directions, Colors.blue),
              _buildSekcja(
                'Data zamknięcia',
                _formatujDate(droga.dataZamkniecia),
                Icons.event,
              ),
              if (droga.dataPlanowanegoOtwarcia != null)
                _buildSekcja(
                  'Planowane otwarcie',
                  _formatujDate(droga.dataPlanowanegoOtwarcia!),
                  Icons.event_available,
                  Colors.green,
                ),
              if (droga.kontakt.isNotEmpty)
                _buildSekcja('Kontakt', droga.kontakt, Icons.phone),
              if (droga.uwagi.isNotEmpty)
                _buildSekcja('Uwagi', droga.uwagi, Icons.note),
              const SizedBox(height: 16),
              if (widget.strazak.rola.poziom >= 3)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _edytujDroge(droga);
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Edytuj'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _usunDroge(droga);
                        },
                        icon: const Icon(Icons.delete),
                        label: const Text('Usuń'),
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
      ),
    );
  }

  Widget _buildSekcja(String tytul, String tresc, IconData ikona, [Color? kolor]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ikona, size: 18, color: kolor ?? Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                tytul,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: kolor ?? Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            tresc,
            style: const TextStyle(fontSize: 15),
          ),
        ],
      ),
    );
  }

  Color _kolorStatusu(StatusDrogi status) {
    switch (status) {
      case StatusDrogi.zamknieta:
        return Colors.red;
      case StatusDrogi.ograniczenia:
        return Colors.orange;
      case StatusDrogi.objazd:
        return Colors.blue;
      case StatusDrogi.otwarta:
        return Colors.green;
    }
  }

  IconData _ikonaStatusu(StatusDrogi status) {
    switch (status) {
      case StatusDrogi.zamknieta:
        return Icons.block;
      case StatusDrogi.ograniczenia:
        return Icons.warning;
      case StatusDrogi.objazd:
        return Icons.alt_route;
      case StatusDrogi.otwarta:
        return Icons.check_circle;
    }
  }

  String _formatujDate(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}.${data.month.toString().padLeft(2, '0')}.${data.year}';
  }

  Future<void> _dodajDroge() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funkcja w budowie - dodawanie drogi')),
    );
  }

  Future<void> _edytujDroge(DrogaZamknieta droga) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funkcja w budowie - edycja drogi')),
    );
  }

  Future<void> _usunDroge(DrogaZamknieta droga) async {
    final potwierdz = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usuń informację'),
        content: Text('Czy na pewno usunąć "${droga.nazwa}"?'),
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

    if (potwierdz == true) {
      await _firestore.collection('drogi_zamkniete').doc(droga.id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informacja usunięta')),
        );
      }
    }
  }
}
