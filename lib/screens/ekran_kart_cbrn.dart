import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/strazak.dart';
import '../models/karta_cbrn.dart';

class EkranKartCBRN extends StatefulWidget {
  final Strazak strazak;

  const EkranKartCBRN({super.key, required this.strazak});

  @override
  State<EkranKartCBRN> createState() => _EkranKartCBRNState();
}

class _EkranKartCBRNState extends State<EkranKartCBRN> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  TypCBRN? _filtrTyp;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Karty CBRN'),
        actions: [
          PopupMenuButton<TypCBRN?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtruj typ',
            onSelected: (typ) => setState(() => _filtrTyp = typ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('Wszystkie'),
              ),
              ...TypCBRN.values.map((typ) => PopupMenuItem(
                    value: typ,
                    child: Text(typ.nazwa),
                  )),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _filtrTyp == null
            ? _firestore.collection('karty_cbrn').orderBy('nazwaSubstancji').snapshots()
            : _firestore
                .collection('karty_cbrn')
                .where('typ', isEqualTo: _filtrTyp.toString())
                .orderBy('nazwaSubstancji')
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Błąd: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final karty = snapshot.data!.docs.map((doc) {
            return KartaCBRN.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList();

          if (karty.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.science_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('Brak kart CBRN'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: karty.length,
            itemBuilder: (context, index) {
              final karta = karty[index];
              return _buildKartaCBRN(karta);
            },
          );
        },
      ),
      floatingActionButton: widget.strazak.rola.poziom >= 3
          ? FloatingActionButton(
              onPressed: _dodajKarte,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildKartaCBRN(KartaCBRN karta) {
    Color kolor = _kolorTypu(karta.typ);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _pokazSzczegoly(karta),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: kolor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        karta.typ.skrot,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          karta.nazwaSubstancji,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          karta.typ.nazwa,
                          style: TextStyle(
                            fontSize: 12,
                            color: kolor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (karta.numerUN.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        border: Border.all(color: Colors.orange),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'UN ${karta.numerUN}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange[900],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (karta.wzorChemiczny.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        karta.wzorChemiczny,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
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

  void _pokazSzczegoly(KartaCBRN karta) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
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
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _kolorTypu(karta.typ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        karta.typ.skrot,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          karta.nazwaSubstancji,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          karta.typ.nazwa,
                          style: TextStyle(
                            fontSize: 14,
                            color: _kolorTypu(karta.typ),
                          ),
                        ),
                        if (karta.numerUN.isNotEmpty)
                          Text(
                            'UN ${karta.numerUN}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              if (karta.wzorChemiczny.isNotEmpty)
                _buildSekcja('Wzór chemiczny', karta.wzorChemiczny, Icons.science),
              if (karta.wlasciwosciFizyczne.isNotEmpty)
                _buildSekcja('Właściwości fizyczne', karta.wlasciwosciFizyczne, Icons.info),
              if (karta.zagrozenia.isNotEmpty)
                _buildSekcja('Zagrożenia', karta.zagrozenia, Icons.warning, Colors.red),
              if (karta.objawy.isNotEmpty)
                _buildSekcja('Objawy', karta.objawy, Icons.medical_services, Colors.orange),
              if (karta.srodkiOchrony.isNotEmpty)
                _buildSekcja('Środki ochrony', karta.srodkiOchrony, Icons.shield),
              if (karta.pierwszaPomoc.isNotEmpty)
                _buildSekcja('Pierwsza pomoc', karta.pierwszaPomoc, Icons.local_hospital, Colors.green),
              if (karta.neutralizacja.isNotEmpty)
                _buildSekcja('Neutralizacja', karta.neutralizacja, Icons.cleaning_services),
              if (karta.dekontaminacja.isNotEmpty)
                _buildSekcja('Dekontaminacja', karta.dekontaminacja, Icons.wash),
              if (karta.proceduraEwakuacji.isNotEmpty)
                _buildSekcja('Procedura ewakuacji', karta.proceduraEwakuacji, Icons.exit_to_app),
              if (karta.strefaBezpieczenstwa.isNotEmpty)
                _buildSekcja('Strefa bezpieczeństwa', karta.strefaBezpieczenstwa, Icons.social_distance),
              if (karta.kontaktAwaryjny.isNotEmpty)
                _buildSekcja('Kontakt awaryjny', karta.kontaktAwaryjny, Icons.phone, Colors.red),
              const SizedBox(height: 16),
              if (widget.strazak.rola.poziom >= 3)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _edytujKarte(karta);
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edytuj kartę'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSekcja(String tytul, String tresc, IconData ikona, [Color? kolor]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ikona, size: 20, color: kolor ?? Colors.grey[700]),
              const SizedBox(width: 8),
              Text(
                tytul,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: kolor ?? Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (kolor ?? Colors.grey).withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: (kolor ?? Colors.grey).withOpacity(0.2)),
            ),
            child: Text(
              tresc,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Color _kolorTypu(TypCBRN typ) {
    switch (typ) {
      case TypCBRN.chemiczny:
        return Colors.orange;
      case TypCBRN.biologiczny:
        return Colors.green;
      case TypCBRN.radiologiczny:
        return Colors.purple;
      case TypCBRN.nuklearny:
        return Colors.red;
    }
  }

  Future<void> _dodajKarte() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funkcja w budowie - dodawanie karty CBRN')),
    );
  }

  Future<void> _edytujKarte(KartaCBRN karta) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funkcja w budowie - edycja karty CBRN')),
    );
  }
}
