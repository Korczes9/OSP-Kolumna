import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wyjazd.dart';
import '../models/strazak.dart';

/// Ekran statystyk i dashboardu
class EkranStatystyk extends StatefulWidget {
  final Strazak aktualnyStrazak;

  const EkranStatystyk({super.key, required this.aktualnyStrazak});

  @override
  State<EkranStatystyk> createState() => _EkranStatystykState();
}

class _EkranStatystykState extends State<EkranStatystyk> {
  final _firestore = FirebaseFirestore.instance;
  DateTime _okresOd = DateTime.now().subtract(const Duration(days: 30));
  DateTime _okresDo = DateTime.now();
  int? _wybranyRok; // null = wszystkie lata

  List<int> _dostepneLata() {
    final obecnyRok = DateTime.now().year;
    return List.generate(10, (index) => obecnyRok - index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statystyki'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Wybór okresu
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Okres',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final data = await showDatePicker(
                              context: context,
                              initialDate: _okresOd,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (data != null) {
                              setState(() => _okresOd = data);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Od',
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(_formatujDate(_okresOd)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final data = await showDatePicker(
                              context: context,
                              initialDate: _okresDo,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (data != null) {
                              setState(() => _okresDo = data);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Do',
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(_formatujDate(_okresDo)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          initialValue: _wybranyRok,
                          decoration: const InputDecoration(
                            labelText: 'Filtruj według roku',
                            prefixIcon: Icon(Icons.filter_list),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Wszystkie lata'),
                            ),
                            ..._dostepneLata().map((rok) => DropdownMenuItem(
                              value: rok,
                              child: Text(rok.toString()),
                            )),
                          ],
                          onChanged: (rok) {
                            setState(() {
                              _wybranyRok = rok;
                              if (rok != null) {
                                _okresOd = DateTime(rok, 1, 1);
                                _okresDo = DateTime(rok, 12, 31);
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Ostatnie 7 dni'),
                        onSelected: (selected) {
                          setState(() {
                            _okresDo = DateTime.now();
                            _okresOd =
                                _okresDo.subtract(const Duration(days: 7));
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Ostatnie 30 dni'),
                        onSelected: (selected) {
                          setState(() {
                            _okresDo = DateTime.now();
                            _okresOd =
                                _okresDo.subtract(const Duration(days: 30));
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Ten miesiąc'),
                        onSelected: (selected) {
                          final now = DateTime.now();
                          setState(() {
                            _okresOd = DateTime(now.year, now.month, 1);
                            _okresDo = now;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Statystyki ogólne
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('wyjazdy')
                .where('dataWyjazdu',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(_okresOd))
                .where('dataWyjazdu',
                    isLessThanOrEqualTo: Timestamp.fromDate(_okresDo))
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final wyjazdy = snapshot.data!.docs
                  .map((doc) => Wyjazd.fromMap(
                      doc.data() as Map<String, dynamic>, doc.id))
                  .toList();

              final sumaGodzin = wyjazdy
                  .where((w) =>
                      w.godzinaRozpoczecia != null &&
                      w.godzinaZakonczenia != null)
                  .fold<int>(
                      0, (sum, w) => sum + w.czasTrwaniaGodzinyZaokraglone);

              final sumaEkwiwalentu = wyjazdy
                  .where((w) =>
                      w.godzinaRozpoczecia != null &&
                      w.godzinaZakonczenia != null)
                  .fold<double>(0, (sum, w) => sum + w.ekwiwalent);

              // Grupowanie po kategorii
              final poKategorii = <KategoriaWyjazdu, int>{};
              for (var w in wyjazdy) {
                poKategorii[w.kategoria] = (poKategorii[w.kategoria] ?? 0) + 1;
              }

              return Column(
                children: [
                  // Karty podsumowania
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Wyjazdy',
                          wyjazdy.length.toString(),
                          Icons.local_fire_department,
                          Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Godziny',
                          '$sumaGodzin h',
                          Icons.access_time,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Ekwiwalent',
                          '${sumaEkwiwalentu.toInt()} PLN',
                          Icons.attach_money,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Wyjazdy po kategorii
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Wyjazdy według kategorii',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...poKategorii.entries.map((entry) {
                            final procent = wyjazdy.isEmpty
                                ? 0.0
                                : (entry.value / wyjazdy.length) * 100;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(entry.key.nazwa),
                                      Text(
                                        '${entry.value} (${procent.toStringAsFixed(1)}%)',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(
                                    value: procent / 100,
                                    backgroundColor: Colors.grey[200],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _kolorKategorii(entry.key),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // TOP 5 strażaków
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('strazacy').snapshots(),
                    builder: (context, strazacySnapshot) {
                      if (!strazacySnapshot.hasData) {
                        return const SizedBox();
                      }

                      final strazacy = strazacySnapshot.data!.docs
                          .map((doc) => Strazak.fromMap(
                              doc.data() as Map<String, dynamic>, doc.id))
                          .toList();

                      // Policz wyjazdy per strażak (każdy wyjazd liczony raz)
                      final wyjazdyPerStrazak = <String, int>{};
                      for (var w in wyjazdy) {
                        // Utwórz set ze wszystkich unikalnych uczestników
                        final uczestnicy = <String>{};
                        uczestnicy.add(w.utworzonePrzez);
                        uczestnicy.addAll(w.strazacyIds);
                        
                        // Każdy uczestnik dostaje +1
                        for (var strazakId in uczestnicy) {
                          wyjazdyPerStrazak[strazakId] =
                              (wyjazdyPerStrazak[strazakId] ?? 0) + 1;
                        }
                      }

                      final topStrazacy = wyjazdyPerStrazak.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value));

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Najbardziej aktywni strażacy',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...topStrazacy.take(5).map((entry) {
                                final strazak = strazacy.firstWhere(
                                  (s) => s.id == entry.key,
                                  orElse: () => Strazak(
                                    id: '',
                                    imie: 'Nieznany',
                                    nazwisko: '',
                                    email: '',
                                    numerTelefonu: '',
                                  ),
                                );
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.orange,
                                    child: Text(
                                      '${topStrazacy.indexOf(entry) + 1}',
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  title: Text(strazak.pelneImie),
                                  trailing: Text(
                                    '${entry.value} wyjazdów',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String wartosc, IconData ikona, Color kolor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(ikona, color: kolor, size: 32),
            const SizedBox(height: 8),
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
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Color _kolorKategorii(KategoriaWyjazdu kategoria) {
    switch (kategoria) {
      case KategoriaWyjazdu.pozar:
        return Colors.red;
      case KategoriaWyjazdu.miejscoweZagrozenie:
        return Colors.orange;
      case KategoriaWyjazdu.alarmFalszywy:
        return Colors.purple;
      case KategoriaWyjazdu.zabezpieczenieRejonu:
        return Colors.blue;
      case KategoriaWyjazdu.zPoleceniaBurmistrza:
        return Colors.teal;
      case KategoriaWyjazdu.cwiczenia:
        return Colors.green;
    }
  }

  String _formatujDate(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}.${data.month.toString().padLeft(2, '0')}.${data.year}';
  }
}
