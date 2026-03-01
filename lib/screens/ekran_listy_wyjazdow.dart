import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/strazak.dart';
import '../models/wyjazd.dart';
import 'ekran_edycji_wyjazdu.dart';

/// Ekran z pełną listą wszystkich wyjazdów - widoczny dla każdego
class EkranListyWyjazdow extends StatefulWidget {
  final Strazak aktualnyStrazak;

  const EkranListyWyjazdow({super.key, required this.aktualnyStrazak});

  @override
  State<EkranListyWyjazdow> createState() => _EkranListyWyjazdowState();
}

class _EkranListyWyjazdowState extends State<EkranListyWyjazdow> {
  KategoriaWyjazdu? _wybranaKategoria;
  int? _wybranyRok;
  bool _filtrBiezacyKwartal = true;

  @override
  void initState() {
    super.initState();
    // Domyślnie filtruj po bieżącym roku (który jest zgodny z bieżącym kwartałem)
    _wybranyRok = DateTime.now().year;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wszystkie wyjazdy'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filtry
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                DropdownButtonFormField<KategoriaWyjazdu?>(
                  initialValue: _wybranaKategoria,
                  decoration: const InputDecoration(
                    labelText: 'Kategoria',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Wszystkie kategorie'),
                    ),
                    ...KategoriaWyjazdu.values.map((k) => DropdownMenuItem(
                          value: k,
                          child: Text(k.nazwa),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() => _wybranaKategoria = value);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  initialValue: _wybranyRok,
                  decoration: const InputDecoration(
                    labelText: 'Rok',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Wszystkie lata'),
                    ),
                    ..._dostepneLata().map((rok) => DropdownMenuItem(
                          value: rok,
                          child: Text(rok.toString()),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _wybranyRok = value;
                      if (value != null) {
                        _filtrBiezacyKwartal = false;
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilterChip(
                    label: const Text('Bieżący kwartał'),
                    selected: _filtrBiezacyKwartal,
                    onSelected: (selected) {
                      setState(() {
                        _filtrBiezacyKwartal = selected;
                        if (selected && _wybranyRok == null) {
                          _wybranyRok = DateTime.now().year;
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // Lista wyjazdów
          Expanded(
            child: StreamBuilder<List<Wyjazd>>(
              stream: _pobierzWyjazdy(),
              // Optymalizacja: użyj poprzednich danych podczas ładowania
              initialData: const [],
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilterChip(
                            label: const Text('Bieżący kwartał'),
                            selected: _filtrBiezacyKwartal,
                            onSelected: (selected) {
                              setState(() {
                                _filtrBiezacyKwartal = selected;
                                if (selected && _wybranyRok == null) {
                                  _wybranyRok = DateTime.now().year;
                                }
                              });
                            },
                          ),
                        ),
                        const Icon(Icons.error, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text('Błąd: ${snapshot.error}'),
                      ],
                    ),
                  );
                }

                final wyjazdy = snapshot.data ?? [];

            if (wyjazdy.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox, color: Colors.grey, size: 48),
                    SizedBox(height: 16),
                    Text('Brak wyjazdów do wyświetlenia'),
                  ],
                ),
              );
            }

                return ListView.builder(
                  itemCount: wyjazdy.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (context, index) {
                    final wyjazd = wyjazdy[index];
                    return _buildWyjazdCard(wyjazd);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWyjazdCard(Wyjazd wyjazd) {
    Color kategoriaColor;
    IconData kategoriaIcon;

    switch (wyjazd.kategoria) {
      case KategoriaWyjazdu.pozar:
        kategoriaColor = Colors.red;
        kategoriaIcon = Icons.local_fire_department;
        break;
      case KategoriaWyjazdu.miejscoweZagrozenie:
        kategoriaColor = Colors.orange;
        kategoriaIcon = Icons.warning;
        break;
      case KategoriaWyjazdu.cwiczenia:
        kategoriaColor = Colors.blue;
        kategoriaIcon = Icons.fitness_center;
        break;
      case KategoriaWyjazdu.zabezpieczenieRejonu:
        kategoriaColor = Colors.purple;
        kategoriaIcon = Icons.security;
        break;
      case KategoriaWyjazdu.alarmFalszywy:
        kategoriaColor = Colors.grey;
        kategoriaIcon = Icons.cancel;
        break;
      case KategoriaWyjazdu.zPoleceniaBurmistrza:
        kategoriaColor = Colors.green;
        kategoriaIcon = Icons.account_balance;
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: kategoriaColor,
          child: Icon(kategoriaIcon, color: Colors.white),
        ),
        title: Text(
          wyjazd.lokalizacja,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(wyjazd.kategoria.nazwa),
            const SizedBox(height: 4),
            Text(
              '${wyjazd.dataWyjazdu.day}.${wyjazd.dataWyjazdu.month}.${wyjazd.dataWyjazdu.year}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            if (wyjazd.godzinaRozpoczecia != null && wyjazd.godzinaZakonczenia != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${wyjazd.godzinaRozpoczecia!.hour.toString().padLeft(2, '0')}:${wyjazd.godzinaRozpoczecia!.minute.toString().padLeft(2, '0')} - ${wyjazd.godzinaZakonczenia!.hour.toString().padLeft(2, '0')}:${wyjazd.godzinaZakonczenia!.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${wyjazd.czasTrwaniaSformatowany})',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
            if (wyjazd.opis.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                wyjazd.opis,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[700], fontSize: 12),
              ),
            ],
            if (wyjazd.liczbaStrazakow > 0) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.people, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${wyjazd.liczbaStrazakow} osób',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: widget.aktualnyStrazak.czyMozeDodawacWyjazdy
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    _usunWyjazd(wyjazd.id);
                  } else if (value == 'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EkranEdycjiWyjazdu(
                          wyjazd: wyjazd,
                          aktualnyStrazak: widget.aktualnyStrazak,
                        ),
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Edytuj'),
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
            : const Icon(Icons.chevron_right),
        isThreeLine: wyjazd.opis.isNotEmpty,
        onTap: () => _pokazSzczegoly(wyjazd),
      ),
    );
  }

  Stream<List<Wyjazd>> _pobierzWyjazdy() {
    Query query = FirebaseFirestore.instance
        .collection('wyjazdy')
        .orderBy('dataWyjazdu', descending: true);

    // Filtruj po kategorii
    if (_wybranaKategoria != null) {
      query = query.where('kategoria', isEqualTo: _wybranaKategoria!.name);
    }

    // Filtruj po roku / bieżącym kwartale
    DateTime? start;
    DateTime? end;

    if (_filtrBiezacyKwartal) {
      final now = DateTime.now();
      final kwartal = ((now.month - 1) ~/ 3) + 1;
      final startMonth = (kwartal - 1) * 3 + 1;
      start = DateTime(now.year, startMonth, 1);
      final nextStartMonth = startMonth + 3;
      if (nextStartMonth > 12) {
        end = DateTime(now.year + 1, 1, 1);
      } else {
        end = DateTime(now.year, nextStartMonth, 1);
      }
    } else if (_wybranyRok != null) {
      start = DateTime(_wybranyRok!, 1, 1);
      end = DateTime(_wybranyRok! + 1, 1, 1);
    }

    if (start != null && end != null) {
      query = query
          .where('dataWyjazdu', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('dataWyjazdu', isLessThan: Timestamp.fromDate(end));
    }

    return query.limit(100).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Wyjazd.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  List<int> _dostepneLata() {
    final obecnyRok = DateTime.now().year;
    return List.generate(10, (i) => obecnyRok - i);
  }

  void _pokazSzczegoly(Wyjazd wyjazd) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(wyjazd.lokalizacja),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('Kategoria', wyjazd.kategoria.nazwa),
              _buildInfoRow(
                'Data',
                '${wyjazd.dataWyjazdu.day}.${wyjazd.dataWyjazdu.month}.${wyjazd.dataWyjazdu.year}',
              ),
              if (wyjazd.opis.isNotEmpty) _buildInfoRow('Opis', wyjazd.opis),
              if (wyjazd.liczbaStrazakow > 0)
                _buildInfoRow('Liczba strażaków', '${wyjazd.liczbaStrazakow}'),
              if (wyjazd.czasTrwaniaMinuty > 0)
                _buildInfoRow(
                  'Czas trwania',
                  wyjazd.czasTrwaniaSformatowany,
                ),
              if (wyjazd.ekwiwalent > 0)
                _buildInfoRow(
                  'Ekwiwalent',
                  '${wyjazd.ekwiwalent.toStringAsFixed(2)} PLN',
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Future<void> _usunWyjazd(String wyjazdId) async {
    final potwierdz = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potwierdzenie'),
        content: const Text('Czy na pewno chcesz usunąć ten wyjazd?'),
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

    if (potwierdz == true && mounted) {
      try {
        await FirebaseFirestore.instance
            .collection('wyjazdy')
            .doc(wyjazdId)
            .delete();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Wyjazd usunięty'),
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
  }
}
