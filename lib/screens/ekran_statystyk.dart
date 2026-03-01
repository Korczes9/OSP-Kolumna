import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wyjazd.dart';
import '../models/strazak.dart';
import '../services/serwis_raportow_pdf.dart';

/// Ekran statystyk i dashboardu
class EkranStatystyk extends StatefulWidget {
  final Strazak aktualnyStrazak;

  const EkranStatystyk({super.key, required this.aktualnyStrazak});

  @override
  State<EkranStatystyk> createState() => _EkranStatystykState();
}

class _EkranStatystykState extends State<EkranStatystyk> {
  final _firestore = FirebaseFirestore.instance;
  late DateTime _okresOd;
  late DateTime _okresDo;
  int? _wybranyRok; // null = wszystkie lata
  bool _generujePdf = false;

  List<int> _dostepneLata() {
    final obecnyRok = DateTime.now().year;
    return List.generate(10, (index) => obecnyRok - index);
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final kwartal = ((now.month - 1) ~/ 3) + 1;
    final startMonth = (kwartal - 1) * 3 + 1;
    _okresOd = DateTime(now.year, startMonth, 1);
    _okresDo = now;
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
                        FilterChip(
                          label: const Text('Bieżący kwartał'),
                          onSelected: (selected) {
                            final now = DateTime.now();
                            final kwartal = ((now.month - 1) ~/ 3) + 1;
                            final startMonth = (kwartal - 1) * 3 + 1;
                            setState(() {
                              _okresOd = DateTime(now.year, startMonth, 1);
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

          // Szybki raport PDF dla wybranego okresu
          Card(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.blueGrey[900]
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Raport ekwiwalentów (PDF)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Wygeneruj raport ekwiwalentów dla aktualnie wybranego okresu (${_formatujDate(_okresOd)} - ${_formatujDate(_okresDo)})',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton.icon(
                      onPressed:
                          _generujePdf ? null : _generujRaportEkwiwalentowDlaZakresu,
                      icon: _generujePdf
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.picture_as_pdf),
                      label: const Text('Generuj PDF'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Szybki raport PDF dla wybranego okresu
          Card(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.blueGrey[900]
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Raport ekwiwalentów (PDF)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Wygeneruj raport ekwiwalentów dla aktualnie wybranego okresu (${''}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton.icon(
                      onPressed: _generujePdf ? null : _generujRaportEkwiwalentowDlaZakresu,
                      icon: _generujePdf
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.picture_as_pdf),
                      label: const Text('Generuj PDF'),
                    ),
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

                // Rok do analizy (jeśli wybrano konkretny rok, użyj go,
                // w przeciwnym razie rok z daty początkowej zakresu)
                final rokAnalizy = _wybranyRok ?? _okresOd.year;
                final wyjazdyRok = wyjazdy
                  .where((w) => w.dataWyjazdu.year == rokAnalizy)
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

              // Grupowanie po wozach
              final poWozach = <String, int>{};
              for (var w in wyjazdy) {
                // Dla wstecznej kompatybilności - stary system z jednym wozem
                if (w.wozId != null && w.wozId!.isNotEmpty) {
                  poWozach[w.wozId!] = (poWozach[w.wozId!] ?? 0) + 1;
                }
                // Nowy system z dwoma wozami
                if (w.woz1Id != null && w.woz1Id!.isNotEmpty) {
                  poWozach[w.woz1Id!] = (poWozach[w.woz1Id!] ?? 0) + 1;
                }
                if (w.woz2Id != null && w.woz2Id!.isNotEmpty) {
                  poWozach[w.woz2Id!] = (poWozach[w.woz2Id!] ?? 0) + 1;
                }
              }

              return Column(
                children: [
                  // Zakładka "Dzieje się" – podsumowanie roku
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dzieje się w roku $rokAnalizy',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (wyjazdyRok.isEmpty)
                            const Text(
                              'Brak wyjazdów w wybranym roku.',
                              style:
                                  TextStyle(fontSize: 13, color: Colors.grey),
                            )
                          else ...[
                            // Najdłuższa i najkrótsza akcja (tylko z poprawnym czasem)
                            (() {
                              final zCzasem = wyjazdyRok
                                  .where((w) => w.czasTrwaniaMinuty > 0)
                                  .toList();
                              if (zCzasem.isEmpty) {
                                return const Text(
                                  'Brak danych o czasie trwania akcji.',
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.grey),
                                );
                              }

                              zCzasem.sort((a, b) =>
                                  a.czasTrwaniaMinuty
                                      .compareTo(b.czasTrwaniaMinuty));
                              final najkrotsza = zCzasem.first;
                              final najdluzsza = zCzasem.last;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Najdłuższa akcja: ${najdluzsza.kategoria.nazwa.toLowerCase()} – ${najdluzsza.lokalizacja} (${_formatujDate(najdluzsza.dataWyjazdu)}, ${najdluzsza.czasTrwaniaSformatowany})',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Najkrótsza akcja: ${najkrotsza.kategoria.nazwa.toLowerCase()} – ${najkrotsza.lokalizacja} (${_formatujDate(najkrotsza.dataWyjazdu)}, ${najkrotsza.czasTrwaniaSformatowany})',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              );
                            })(),

                            // Łączny czas działań w roku (godziny i minuty)
                            (() {
                              final laczneMinuty = wyjazdyRok
                                  .where((w) => w.czasTrwaniaMinuty > 0)
                                  .fold<int>(
                                      0,
                                      (sum, w) =>
                                          sum + w.czasTrwaniaMinuty);
                              return Text(
                                'Łącznie na akcjach: ${_formatujCzasMinuty(laczneMinuty)}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              );
                            })(),
                            const SizedBox(height: 8),

                            // Jak często występują poszczególne kategorie
                            const Text(
                              'Jak często występują kategorie zdarzeń:',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            ...KategoriaWyjazdu.values.map((kategoria) {
                              final lista = wyjazdyRok
                                  .where((w) => w.kategoria == kategoria)
                                  .toList()
                                ..sort((a, b) => a.dataWyjazdu
                                    .compareTo(b.dataWyjazdu));

                              if (lista.isEmpty) {
                                return const SizedBox.shrink();
                              }

                              if (lista.length == 1) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    '${kategoria.nazwa}: 1 zdarzenie w roku',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                );
                              }

                              // Policz średnią przerwę między zdarzeniami
                              var sumDays = 0.0;
                              for (var i = 1; i < lista.length; i++) {
                                final diff = lista[i]
                                    .dataWyjazdu
                                    .difference(lista[i - 1].dataWyjazdu)
                                    .inDays;
                                sumDays += diff.abs().toDouble();
                              }
                              final avgDays =
                                  sumDays / (lista.length - 1).toDouble();

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 2),
                                child: Text(
                                  '${kategoria.nazwa}: ${lista.length} zdarzeń, średnio co ${avgDays.toStringAsFixed(1)} dni',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

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

                  // Statystyki wozów
                  if (poWozach.isNotEmpty)
                    StreamBuilder<QuerySnapshot>(
                      stream: _firestore.collection('wozy_strazackie').snapshots(),
                      builder: (context, wozySnapshot) {
                        // Tworzymy mapę ID -> Marka wozu
                        final nazwyWozow = <String, String>{};
                        if (wozySnapshot.hasData) {
                          for (var doc in wozySnapshot.data!.docs) {
                            final data = doc.data() as Map<String, dynamic>;

                            // Staramy się złożyć czytelną nazwę wozu na podstawie
                            // dostępnych pól w dokumencie (numer operacyjny,
                            // nazwa/opis/model itp.). Dzięki temu niezależnie od
                            // dokładnych nazw pól w Firestore powinniśmy dostać
                            // sensowny podpis zamiast "Nieznany wóz".
                            final numerOperacyjny = (data['numerOperacyjny'] ??
                                data['nrOperacyjny'] ??
                                data['numer'] ??
                                data['symbol'] ??
                                '')
                              .toString();
                            // Niektóre dokumenty wozów mają nazwę w polu ":nazwa",
                            // dlatego bierzemy ją pod uwagę jako pierwszą.
                            final nazwa = (data[':nazwa'] ??
                                data['nazwa'] ??
                                data['opis'] ??
                                data['typ'] ??
                                data['model'] ??
                                data['marka'] ??
                                '')
                              .toString();

                            String label;
                            if (numerOperacyjny.isNotEmpty && nazwa.isNotEmpty) {
                              label = '$numerOperacyjny $nazwa';
                            } else if (numerOperacyjny.isNotEmpty) {
                              label = numerOperacyjny;
                            } else if (nazwa.isNotEmpty) {
                              label = nazwa;
                            } else {
                              label = 'Nieznany wóz';
                            }

                            nazwyWozow[doc.id] = label;
                          }
                        }

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Wyjazdy według wozów',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...(() {
                                  final sortowane = poWozach.entries.toList()
                                    ..sort((a, b) => b.value.compareTo(a.value));
                                  return sortowane.map((entry) {
                                    final procent = wyjazdy.isEmpty
                                        ? 0.0
                                        : (entry.value / wyjazdy.length) * 100;
                                    final nazwaWozu = nazwyWozow[entry.key] ?? 'Nieznany wóz';
                                    
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.local_shipping,
                                                        size: 20, color: Colors.red),
                                                    const SizedBox(width: 8),
                                                    Flexible(
                                                      child: Text(
                                                        nazwaWozu,
                                                        style: const TextStyle(
                                                            fontWeight: FontWeight.w600),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
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
                                            valueColor:
                                                const AlwaysStoppedAnimation<Color>(
                                              Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  });
                                })(),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  if (poWozach.isNotEmpty) const SizedBox(height: 16),

                  // TOP strażaków z podziałem na typy wyjazdów
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

                        // Policz wyjazdy per strażak z podziałem na kategorie
                        // (pożar/miejscowe/alarm fałszywy jako "Wyjazdy",
                        // osobno zabezpieczenie rejonu, ćwiczenia i z polecenia burmistrza).
                        final aktywnoscPerStrazak = <String, Map<String, int>>{};

                        int _sumaWyjazdow(Map<String, int> m) =>
                          (m['wyjazdy'] ?? 0) +
                          (m['zabezpieczenie'] ?? 0) +
                          (m['cwiczenia'] ?? 0) +
                          (m['zPolecenia'] ?? 0);
                      for (var w in wyjazdy) {
                        // Utwórz set ze wszystkich unikalnych uczestników
                        final uczestnicy = <String>{};
                        
                        // Stary system - jeden wóz
                        if (w.strazacyIds.isNotEmpty) {
                          uczestnicy.addAll(w.strazacyIds);
                        }
                        
                        // Nowy system - dwa wozy
                        if (w.woz1StrazacyIds.isNotEmpty) {
                          uczestnicy.addAll(w.woz1StrazacyIds);
                        }
                        if (w.woz2StrazacyIds.isNotEmpty) {
                          uczestnicy.addAll(w.woz2StrazacyIds);
                        }
                        
                        // Każdy uczestnik dostaje +1 w odpowiedniej kategorii
                        for (var strazakId in uczestnicy) {
                          final stats = aktywnoscPerStrazak.putIfAbsent(
                            strazakId,
                            () => {
                              'wyjazdy': 0,
                              'zabezpieczenie': 0,
                              'cwiczenia': 0,
                              'zPolecenia': 0,
                            },
                          );

                          switch (w.kategoria) {
                            case KategoriaWyjazdu.pozar:
                            case KategoriaWyjazdu.miejscoweZagrozenie:
                            case KategoriaWyjazdu.alarmFalszywy:
                              stats['wyjazdy'] = (stats['wyjazdy'] ?? 0) + 1;
                              break;
                            case KategoriaWyjazdu.zabezpieczenieRejonu:
                              stats['zabezpieczenie'] =
                                  (stats['zabezpieczenie'] ?? 0) + 1;
                              break;
                            case KategoriaWyjazdu.cwiczenia:
                              stats['cwiczenia'] =
                                  (stats['cwiczenia'] ?? 0) + 1;
                              break;
                            case KategoriaWyjazdu.zPoleceniaBurmistrza:
                              stats['zPolecenia'] =
                                  (stats['zPolecenia'] ?? 0) + 1;
                              break;
                          }
                        }
                      }

                        // Pomiń wpisy dla strażaków, których konta już nie ma
                        final topStrazacy = aktywnoscPerStrazak.entries
                          .where((entry) =>
                            strazacy.any((s) => s.id == entry.key))
                          .toList()
                        ..sort((a, b) =>
                          _sumaWyjazdow(b.value).compareTo(_sumaWyjazdow(a.value)));

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
                              ...topStrazacy.map((entry) {
                                // W tym miejscu mamy pewność, że strażak istnieje,
                                // bo wcześniej przefiltrowaliśmy listę
                                final strazak = strazacy.firstWhere(
                                  (s) => s.id == entry.key,
                                );
                                final stats = entry.value;
                                final suma = _sumaWyjazdow(stats);
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
                                  subtitle: Text(
                                    'Wyjazdy: ${stats['wyjazdy'] ?? 0}   '
                                    'Zabezp. rejonu: ${stats['zabezpieczenie'] ?? 0}   '
                                    'Ćwiczenia: ${stats['cwiczenia'] ?? 0}   '
                                    'Z polecenia Burmistrza: ${stats['zPolecenia'] ?? 0}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: Text(
                                    '$suma łącznie',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
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

  String _formatujCzasMinuty(int minuty) {
    if (minuty <= 0) return '0 min';
    final godziny = minuty ~/ 60;
    final pozostaleMinuty = minuty % 60;
    if (godziny == 0) {
      return '$pozostaleMinuty min';
    }
    if (pozostaleMinuty == 0) {
      return '$godziny godz.';
    }
    return '$godziny godz. $pozostaleMinuty min';
  }

  String _formatujDate(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}.${data.month.toString().padLeft(2, '0')}.${data.year}';
  }

  Future<void> _generujRaportEkwiwalentowDlaZakresu() async {
    setState(() => _generujePdf = true);
    try {
      await SerwisRaportowPDF().generujRaportEkwiwalentow(
        od: _okresOd,
        doDaty: _okresDo,
        opisOkresu: '${_formatujDate(_okresOd)} - ${_formatujDate(_okresDo)}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd generowania raportu: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _generujePdf = false);
      }
    }
  }
}
