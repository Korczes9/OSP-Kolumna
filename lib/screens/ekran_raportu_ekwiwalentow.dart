import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wyjazd.dart';
import '../models/strazak.dart';
import 'ekran_edycji_wyjazdu.dart';

/// Ekran raportu ekwiwalentów
class EkranRaportuEkwiwalentow extends StatefulWidget {
  final Strazak aktualnyStrazak;

  const EkranRaportuEkwiwalentow({super.key, required this.aktualnyStrazak});

  @override
  State<EkranRaportuEkwiwalentow> createState() =>
      _EkranRaportuEkwiwalentowState();
}

class _EkranRaportuEkwiwalentowState extends State<EkranRaportuEkwiwalentow> {
  final _firestore = FirebaseFirestore.instance;
  DateTime _dataOd = DateTime.now().subtract(const Duration(days: 30));
  DateTime _dataDo = DateTime.now();
  String? _wybranyStrazakId;
  Map<String, Strazak> _strazacy = {};

  @override
  void initState() {
    super.initState();
    _pobierzStrazakow();
  }

  Future<void> _pobierzStrazakow() async {
    final snap = await _firestore.collection('strazacy').get();
    setState(() {
      _strazacy = {
        for (var doc in snap.docs) doc.id: Strazak.fromMap(doc.data(), doc.id)
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sprawdź w jakich wyjazdach brałem udział'),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filtry
          Container(
            color: Colors.orange[50],
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filtry',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),

                // Zakres dat
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final data = await showDatePicker(
                            context: context,
                            initialDate: _dataOd,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (data != null) {
                            setState(() => _dataOd = data);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Data od',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(_formatujDate(_dataOd)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final data = await showDatePicker(
                            context: context,
                            initialDate: _dataDo,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (data != null) {
                            setState(() => _dataDo = data);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Data do',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(_formatujDate(_dataDo)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Wybór strażaka
                DropdownButtonFormField<String?>(
                  initialValue: _wybranyStrazakId,
                  decoration: const InputDecoration(
                    labelText: 'Strażak',
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Wszyscy'),
                    ),
                    ..._strazacy.entries.map((entry) {
                      return DropdownMenuItem(
                        value: entry.key,
                        child:
                            Text('${entry.value.imie} ${entry.value.nazwisko}'),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() => _wybranyStrazakId = value);
                  },
                ),
              ],
            ),
          ),

          // Lista wyjazdów z ekwiwalentem
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _pobierzWyjazdy(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Błąd: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final wyjazdy = snapshot.data!.docs
                    .map((doc) => Wyjazd.fromMap(
                          doc.data() as Map<String, dynamic>,
                          doc.id,
                        ))
                    .where((w) {
                      // Sprawdź czy wyjazd ma wypełnione godziny
                      if (w.godzinaRozpoczecia == null || w.godzinaZakonczenia == null) {
                        return false;
                      }
                      
                      // Jeśli nie wybrano konkretnego strażaka, pokaż wszystkie
                      if (_wybranyStrazakId == null) {
                        return true;
                      }
                      
                      // Sprawdź czy wybrany strażak brał udział w wyjeździe
                      // Może być w jednej z trzech list uczestników
                      return w.strazacyIds.contains(_wybranyStrazakId) ||
                             w.woz1StrazacyIds.contains(_wybranyStrazakId) ||
                             w.woz2StrazacyIds.contains(_wybranyStrazakId);
                    })
                    .toList();

                if (wyjazdy.isEmpty) {
                  return const Center(
                    child: Text('Brak wyjazdów z wypełnionymi godzinami'),
                  );
                }

                // Oblicz sumy
                final sumaGodzin = wyjazdy.fold<int>(
                  0,
                  (sum, w) => sum + w.czasTrwaniaGodzinyZaokraglone,
                );
                final sumaEkwiwalentu = wyjazdy
                    .fold<double>(
                      0.0,
                      (sum, w) => sum + w.ekwiwalent,
                    )
                    .toInt();

                return Column(
                  children: [
                    // Podsumowanie
                    Container(
                      color: Colors.green[50],
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSumaCard(
                            'Wyjazdy',
                            wyjazdy.length.toString(),
                            Icons.local_fire_department,
                            Colors.red,
                          ),
                          _buildSumaCard(
                            'Godziny',
                            '$sumaGodzin h',
                            Icons.access_time,
                            Colors.blue,
                          ),
                          _buildSumaCard(
                            'Ekwiwalent',
                            '$sumaEkwiwalentu PLN',
                            Icons.attach_money,
                            Colors.green,
                          ),
                        ],
                      ),
                    ),

                    // Lista wyjazdów
                    Expanded(
                      child: ListView.builder(
                        itemCount: wyjazdy.length,
                        itemBuilder: (context, index) {
                          return _buildWyjazdCard(wyjazdy[index]);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
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
    );
  }

  Widget _buildWyjazdCard(Wyjazd wyjazd) {
    final strazak = _strazacy[wyjazd.utworzonePrzez];
    final kolorKategorii = _kolorKategorii(wyjazd.kategoria);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    wyjazd.lokalizacja,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kolorKategorii.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    wyjazd.kategoria.nazwa,
                    style: TextStyle(
                      color: kolorKategorii,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (strazak != null)
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${strazak.imie} ${strazak.nazwisko}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),

            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  _formatujDate(wyjazd.dataWyjazdu),
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),

            const SizedBox(height: 8),
            const Divider(),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 18, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      '${wyjazd.czasTrwaniaSformatowany} (${wyjazd.czasTrwaniaGodzinyZaokraglone} h zaokr.)',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.attach_money,
                        size: 18, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      '${wyjazd.ekwiwalent} PLN',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Przycisk edycji (tylko dla Moderatorów i Administratorów)
            if (widget.aktualnyStrazak.czyMozeDodawacWyjazdy) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EkranEdycjiWyjazdu(
                          wyjazd: wyjazd,
                          aktualnyStrazak: widget.aktualnyStrazak,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edytuj'),
                ),
              ),
            ],
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

  Stream<QuerySnapshot> _pobierzWyjazdy() {
    // Używamy dataWyjazdu (nowy format) zamiast data (stary format)
    Query query = _firestore
        .collection('wyjazdy')
        .where('dataWyjazdu', isGreaterThanOrEqualTo: Timestamp.fromDate(_dataOd))
        .where('dataWyjazdu',
            isLessThanOrEqualTo:
                Timestamp.fromDate(_dataDo.add(const Duration(days: 1))))
        .orderBy('dataWyjazdu', descending: true);

    // Nie możemy dodać kolejnego where dla utworzonePrzez bo wymagałoby to indeksu
    // Filtrujemy po stronie klienta jeśli potrzeba
    return query.snapshots();
  }

  String _formatujDate(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}.${data.month.toString().padLeft(2, '0')}.${data.year}';
  }
}
