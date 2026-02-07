import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sprzet.dart';
import '../models/strazak.dart';

/// Ekran inwentaryzacji sprzętu
class EkranSprzetu extends StatefulWidget {
  final Strazak aktualnyStrazak;

  const EkranSprzetu({super.key, required this.aktualnyStrazak});

  @override
  State<EkranSprzetu> createState() => _EkranSprzetuState();
}

class _EkranSprzetuState extends State<EkranSprzetu> {
  final _firestore = FirebaseFirestore.instance;
  KategoriaSprzetu? _wybranaKategoria;
  StatusSprzetu? _wybranyStatus;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inwentaryzacja sprzętu'),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _pokazFiltry,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _pobierzSprzet(),
        initialData: null,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Błąd: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final sprzet = snapshot.data!.docs
              .map((doc) =>
                  Sprzet.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();

          if (sprzet.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Brak sprzętu',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          // Grupowanie po kategorii
          final poKategorii = <KategoriaSprzetu, List<Sprzet>>{};
          for (var s in sprzet) {
            poKategorii[s.kategoria] = (poKategorii[s.kategoria] ?? [])..add(s);
          }

          // Statystyki
          final sprawny =
              sprzet.where((s) => s.status == StatusSprzetu.sprawny).length;
          final niesprawny =
              sprzet.where((s) => s.status == StatusSprzetu.niesprawny).length;
          final wPrzeglad =
              sprzet.where((s) => s.status == StatusSprzetu.wPrzeglad).length;
          final wymagaPrzegladu = sprzet.where((s) => s.wymagaPrzegladu).length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Podsumowanie
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Sprawny',
                      sprawny.toString(),
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryCard(
                      'Niesprawny',
                      niesprawny.toString(),
                      Icons.error,
                      Colors.red,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryCard(
                      'W przeglądzie',
                      wPrzeglad.toString(),
                      Icons.build,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryCard(
                      'Wymaga przeglądu',
                      wymagaPrzegladu.toString(),
                      Icons.warning,
                      Colors.amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Ostrzeżenia o przeglądach
              if (wymagaPrzegladu > 0) ...[
                Card(
                  color: Colors.amber[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$wymagaPrzegladu przedmiotów wymaga przeglądu w ciągu 14 dni',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Listy po kategoriach
              ...poKategorii.entries.map((entry) {
                return _buildKategoriaSection(entry.key, entry.value);
              }),
            ],
          );
        },
      ),
      floatingActionButton: widget.aktualnyStrazak.czyMozeDodawacWyjazdy
          ? FloatingActionButton(
              onPressed: _dodajSprzet,
              backgroundColor: Colors.teal[700],
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildSummaryCard(
      String label, String wartosc, IconData ikona, Color kolor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(ikona, color: kolor, size: 24),
            const SizedBox(height: 4),
            Text(
              wartosc,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: kolor,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKategoriaSection(
      KategoriaSprzetu kategoria, List<Sprzet> sprzet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(_ikonaKategorii(kategoria), color: Colors.teal[700]),
              const SizedBox(width: 8),
              Text(
                '${kategoria.nazwa} (${sprzet.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        ...sprzet.map((s) => _buildSprzetCard(s)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSprzetCard(Sprzet sprzet) {
    final kolor = _kolorStatusu(sprzet.status);
    final wymagaPrzegladu = sprzet.wymagaPrzegladu;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: wymagaPrzegladu ? 3 : 1,
      color: wymagaPrzegladu ? Colors.amber[50] : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: kolor,
          child: Icon(
            _ikonaStatusu(sprzet.status),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          sprzet.nazwa,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${sprzet.status.nazwa}'),
            if (sprzet.numerInwentarzowy != null)
              Text('Nr inwentarzowy: ${sprzet.numerInwentarzowy}'),
            if (sprzet.lokalizacja != null)
              Text('Lokalizacja: ${sprzet.lokalizacja}'),
            if (sprzet.przypisanyDoStrazaka != null)
              FutureBuilder<DocumentSnapshot>(
                future: _firestore
                    .collection('strazacy')
                    .doc(sprzet.przypisanyDoStrazaka)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final strazak = Strazak.fromMap(
                      snapshot.data!.data() as Map<String, dynamic>,
                      snapshot.data!.id,
                    );
                    return Text(
                      'Przypisany: ${strazak.pelneImie}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            if (sprzet.dataNastepnegoPrzegladu != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  if (wymagaPrzegladu)
                    const Icon(Icons.warning, size: 16, color: Colors.amber),
                  if (wymagaPrzegladu) const SizedBox(width: 4),
                  Text(
                    'Przegląd: ${_formatujDate(sprzet.dataNastepnegoPrzegladu!)}',
                    style: TextStyle(
                      color: wymagaPrzegladu
                          ? Colors.amber[900]
                          : Colors.grey[700],
                      fontWeight:
                          wymagaPrzegladu ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (sprzet.dniDoPrzegladu != null)
                    Text(
                      ' (${sprzet.dniDoPrzegladu} dni)',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            wymagaPrzegladu ? Colors.amber[900] : Colors.grey,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
        trailing: widget.aktualnyStrazak.jestAdministratorem
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    _usunSprzet(sprzet.id);
                  } else if (value == 'status') {
                    _zmienStatus(sprzet);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'status',
                    child: Row(
                      children: [
                        Icon(Icons.swap_horiz, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Zmień status'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Usuń'),
                      ],
                    ),
                  ),
                ],
              )
            : null,
        isThreeLine: true,
      ),
    );
  }

  IconData _ikonaKategorii(KategoriaSprzetu kategoria) {
    switch (kategoria) {
      case KategoriaSprzetu.ochrone:
        return Icons.checkroom;
      case KategoriaSprzetu.respiratory:
        return Icons.air;
      case KategoriaSprzetu.weze:
        return Icons.water;
      case KategoriaSprzetu.narzedzia:
        return Icons.handyman;
      case KategoriaSprzetu.elektronika:
        return Icons.electrical_services;
      case KategoriaSprzetu.medyczne:
        return Icons.medical_services;
      case KategoriaSprzetu.inne:
        return Icons.more_horiz;
    }
  }

  IconData _ikonaStatusu(StatusSprzetu status) {
    switch (status) {
      case StatusSprzetu.sprawny:
        return Icons.check_circle;
      case StatusSprzetu.niesprawny:
        return Icons.error;
      case StatusSprzetu.wPrzeglad:
        return Icons.build;
      case StatusSprzetu.wycofany:
        return Icons.archive;
    }
  }

  Color _kolorStatusu(StatusSprzetu status) {
    switch (status) {
      case StatusSprzetu.sprawny:
        return Colors.green;
      case StatusSprzetu.niesprawny:
        return Colors.red;
      case StatusSprzetu.wPrzeglad:
        return Colors.orange;
      case StatusSprzetu.wycofany:
        return Colors.grey;
    }
  }

  Stream<QuerySnapshot> _pobierzSprzet() {
    Query query = _firestore.collection('sprzet');

    if (_wybranaKategoria != null) {
      query = query.where('kategoria', isEqualTo: _wybranaKategoria!.name);
    }

    if (_wybranyStatus != null) {
      query = query.where('status', isEqualTo: _wybranyStatus!.name);
    }

    return query.orderBy('nazwa').snapshots();
  }

  void _pokazFiltry() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtry'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kategoria:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...KategoriaSprzetu.values.map((kat) {
                return RadioListTile<KategoriaSprzetu?>(
                  title: Text(kat.nazwa),
                  value: kat,
                  groupValue: _wybranaKategoria,
                  onChanged: (value) {
                    setState(() => _wybranaKategoria = value);
                    Navigator.pop(context);
                  },
                );
              }),
              RadioListTile<KategoriaSprzetu?>(
                title: const Text('Wszystkie'),
                value: null,
                groupValue: _wybranaKategoria,
                onChanged: (value) {
                  setState(() => _wybranaKategoria = null);
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              const Text('Status:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...StatusSprzetu.values.map((stat) {
                return RadioListTile<StatusSprzetu?>(
                  title: Text(stat.nazwa),
                  value: stat,
                  groupValue: _wybranyStatus,
                  onChanged: (value) {
                    setState(() => _wybranyStatus = value);
                    Navigator.pop(context);
                  },
                );
              }),
              RadioListTile<StatusSprzetu?>(
                title: const Text('Wszystkie'),
                value: null,
                groupValue: _wybranyStatus,
                onChanged: (value) {
                  setState(() => _wybranyStatus = null);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zamknij'),
          ),
        ],
      ),
    );
  }

  Future<void> _dodajSprzet() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Formularz dodawania sprzętu - w przygotowaniu'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _zmienStatus(Sprzet sprzet) async {
    final nowyStatus = await showDialog<StatusSprzetu>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zmień status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: StatusSprzetu.values.map((status) {
            return RadioListTile<StatusSprzetu>(
              title: Text(status.nazwa),
              value: status,
              groupValue: sprzet.status,
              onChanged: (value) => Navigator.pop(context, value),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
        ],
      ),
    );

    if (nowyStatus != null && nowyStatus != sprzet.status) {
      await _firestore.collection('sprzet').doc(sprzet.id).update({
        'status': nowyStatus.name,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status zmieniony'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _usunSprzet(String id) async {
    final potwierdz = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potwierdzenie'),
        content: const Text('Czy na pewno chcesz usunąć ten przedmiot?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );

    if (potwierdz == true) {
      await _firestore.collection('sprzet').doc(id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sprzęt usunięty'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  String _formatujDate(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}.${data.month.toString().padLeft(2, '0')}.${data.year}';
  }
}
