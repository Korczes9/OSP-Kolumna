import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/strazak.dart';
import '../models/hydrant.dart';

class EkranHydrantow extends StatefulWidget {
  final Strazak strazak;

  const EkranHydrantow({super.key, required this.strazak});

  @override
  State<EkranHydrantow> createState() => _EkranHydrantowState();
}

class _EkranHydrantowState extends State<EkranHydrantow> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StatusHydranta? _filtrStatus;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hydranty i źródła wody'),
        actions: [
          PopupMenuButton<StatusHydranta?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtruj status',
            onSelected: (status) => setState(() => _filtrStatus = status),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('Wszystkie'),
              ),
              ...StatusHydranta.values.map((status) => PopupMenuItem(
                    value: status,
                    child: Text(status.nazwa),
                  )),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _filtrStatus == null
            ? _firestore.collection('hydranty').orderBy('numer').snapshots()
            : _firestore
                .collection('hydranty')
                .where('status', isEqualTo: _filtrStatus.toString())
                .orderBy('numer')
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Błąd: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final hydranty = snapshot.data!.docs.map((doc) {
            return Hydrant.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList();

          if (hydranty.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.water_drop_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('Brak zarejestrowanych hydrantów'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: hydranty.length,
            itemBuilder: (context, index) {
              final hydrant = hydranty[index];
              return _buildKartaHydranta(hydrant);
            },
          );
        },
      ),
      floatingActionButton: widget.strazak.rola.poziom >= 3
          ? FloatingActionButton(
              onPressed: _dodajHydrant,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildKartaHydranta(Hydrant hydrant) {
    Color kolorStatusu = _kolorStatusu(hydrant.status);
    bool wymaga = hydrant.wymagaPrzegladu;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _pokazSzczegoly(hydrant),
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
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _ikonaTypu(hydrant.typ),
                      color: Colors.blue[700],
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Hydrant ${hydrant.numer}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (wymaga) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.warning, size: 16, color: Colors.orange[700]),
                            ],
                          ],
                        ),
                        Text(
                          hydrant.typ.nazwa,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: kolorStatusu.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kolorStatusu),
                    ),
                    child: Text(
                      hydrant.status.nazwa,
                      style: TextStyle(
                        fontSize: 11,
                        color: kolorStatusu,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      hydrant.lokalizacja,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
              if (hydrant.cisnienie != null || hydrant.pojemnosc != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (hydrant.cisnienie != null) ...[
                      Icon(Icons.speed, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Ciśnienie: ${hydrant.cisnienie} bar',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                    if (hydrant.pojemnosc != null) ...[
                      const SizedBox(width: 16),
                      Icon(Icons.water, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Pojemność: ${hydrant.pojemnosc} L',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _pokazSzczegoly(Hydrant hydrant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hydrant ${hydrant.numer}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRzad('Typ', hydrant.typ.nazwa),
              _buildRzad('Lokalizacja', hydrant.lokalizacja),
              _buildRzad('Status', hydrant.status.nazwa),
              if (hydrant.cisnienie != null)
                _buildRzad('Ciśnienie', '${hydrant.cisnienie} bar'),
              if (hydrant.pojemnosc != null)
                _buildRzad('Pojemność', '${hydrant.pojemnosc} L'),
              if (hydrant.uwagi.isNotEmpty)
                _buildRzad('Uwagi', hydrant.uwagi),
              _buildRzad(
                'Ostatni przegląd',
                _formatujDate(hydrant.dataOstatniegoPrzegladu),
              ),
              if (hydrant.dataKolejnegoPrzegladu != null)
                _buildRzad(
                  'Kolejny przegląd',
                  _formatujDate(hydrant.dataKolejnegoPrzegladu!),
                ),
              if (hydrant.przeprowadzilPrzeglad != null)
                _buildRzad('Przeprowadził', hydrant.przeprowadzilPrzeglad!),
            ],
          ),
        ),
        actions: [
          if (widget.strazak.rola.poziom >= 2)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _edytujHydrant(hydrant);
              },
              child: const Text('Edytuj'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zamknij'),
          ),
        ],
      ),
    );
  }

  Widget _buildRzad(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Color _kolorStatusu(StatusHydranta status) {
    switch (status) {
      case StatusHydranta.sprawny:
        return Colors.green;
      case StatusHydranta.uszkodzony:
        return Colors.red;
      case StatusHydranta.nieczynny:
        return Colors.grey;
      case StatusHydranta.wymagaPrzegladu:
        return Colors.orange;
    }
  }

  IconData _ikonaTypu(TypZrodlaWody typ) {
    switch (typ) {
      case TypZrodlaWody.hydrantPodziemny:
      case TypZrodlaWody.hydrantNadziemny:
        return Icons.water_drop;
      case TypZrodlaWody.zbiornikOtwarty:
      case TypZrodlaWody.zbiornikZamkniety:
        return Icons.water;
      case TypZrodlaWody.rzeka:
      case TypZrodlaWody.staw:
        return Icons.waves;
      case TypZrodlaWody.inny:
        return Icons.help_outline;
    }
  }

  String _formatujDate(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}.${data.month.toString().padLeft(2, '0')}.${data.year}';
  }

  Future<void> _dodajHydrant() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funkcja w budowie - dodawanie hydranta')),
    );
  }

  Future<void> _edytujHydrant(Hydrant hydrant) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funkcja w budowie - edycja hydranta')),
    );
  }
}
