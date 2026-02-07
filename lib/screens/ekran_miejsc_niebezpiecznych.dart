import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/strazak.dart';
import '../models/miejsce_niebezpieczne.dart';

class EkranMiejscNiebezpiecznych extends StatefulWidget {
  final Strazak strazak;

  const EkranMiejscNiebezpiecznych({super.key, required this.strazak});

  @override
  State<EkranMiejscNiebezpiecznych> createState() => _EkranMiejscNiebezpiecznychState();
}

class _EkranMiejscNiebezpiecznychState extends State<EkranMiejscNiebezpiecznych> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _pokazMape = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Miejsca niebezpieczne'),
        actions: [
          IconButton(
            icon: Icon(_pokazMape ? Icons.list : Icons.map),
            onPressed: () => setState(() => _pokazMape = !_pokazMape),
            tooltip: _pokazMape ? 'Widok listy' : 'Widok mapy',
          ),
        ],
      ),
      body: _pokazMape ? _buildMapa() : _buildLista(),
      floatingActionButton: widget.strazak.rola.poziom >= 3
          ? FloatingActionButton(
              onPressed: _dodajMiejsce,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildLista() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('miejsca_niebezpieczne')
          .orderBy('nazwa')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Błąd: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final miejsca = snapshot.data!.docs.map((doc) {
          return MiejsceNiebezpieczne.fromMap(
            doc.data() as Map<String, dynamic>,
            doc.id,
          );
        }).toList();

        if (miejsca.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_off, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text('Brak zarejestrowanych miejsc niebezpiecznych'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: miejsca.length,
          itemBuilder: (context, index) {
            final miejsce = miejsca[index];
            return _buildKartaMiejsca(miejsce);
          },
        );
      },
    );
  }

  Widget _buildKartaMiejsca(MiejsceNiebezpieczne miejsce) {
    Color kolor = _kolorDlaTypu(miejsce.typ);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _pokazSzczegoly(miejsce),
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
                      color: kolor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _ikonaDlaTypu(miejsce.typ),
                      color: kolor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          miejsce.nazwa,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          miejsce.typ.nazwa,
                          style: TextStyle(
                            fontSize: 12,
                            color: kolor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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
                      miejsce.adres,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
              if (miejsce.substancje.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.warning_amber, size: 16, color: Colors.orange[700]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        miejsce.substancje,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapa() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('miejsca_niebezpieczne').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final miejsca = snapshot.data!.docs.map((doc) {
          return MiejsceNiebezpieczne.fromMap(
            doc.data() as Map<String, dynamic>,
            doc.id,
          );
        }).toList();

        final markers = miejsca.map((miejsce) {
          return Marker(
            markerId: MarkerId(miejsce.id),
            position: LatLng(miejsce.szerokosc, miejsce.dlugosc),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              _kolorMarkera(miejsce.typ),
            ),
            infoWindow: InfoWindow(
              title: miejsce.nazwa,
              snippet: miejsce.typ.nazwa,
            ),
            onTap: () => _pokazSzczegoly(miejsce),
          );
        }).toSet();

        return GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: LatLng(51.9189, 19.1451), // Kolumna
            zoom: 12,
          ),
          markers: markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
        );
      },
    );
  }

  void _pokazSzczegoly(MiejsceNiebezpieczne miejsce) {
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
                      color: _kolorDlaTypu(miejsce.typ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _ikonaDlaTypu(miejsce.typ),
                      color: _kolorDlaTypu(miejsce.typ),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          miejsce.nazwa,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          miejsce.typ.nazwa,
                          style: TextStyle(
                            fontSize: 14,
                            color: _kolorDlaTypu(miejsce.typ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              _buildSekcjaSzczegolow('Adres', miejsce.adres, Icons.location_on),
              if (miejsce.opis.isNotEmpty)
                _buildSekcjaSzczegolow('Opis', miejsce.opis, Icons.description),
              if (miejsce.substancje.isNotEmpty)
                _buildSekcjaSzczegolow('Substancje', miejsce.substancje, Icons.science),
              if (miejsce.procedury.isNotEmpty)
                _buildSekcjaSzczegolow('Procedury', miejsce.procedury, Icons.checklist),
              if (miejsce.kontakt.isNotEmpty)
                _buildSekcjaSzczegolow('Kontakt', miejsce.kontakt, Icons.phone),
              const SizedBox(height: 16),
              if (widget.strazak.rola.poziom >= 3)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _edytujMiejsce(miejsce);
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
                          _usunMiejsce(miejsce);
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

  Widget _buildSekcjaSzczegolow(String tytul, String tresc, IconData ikona) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ikona, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                tytul,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
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

  Color _kolorDlaTypu(TypZagrozenia typ) {
    switch (typ) {
      case TypZagrozenia.zbiornik:
        return Colors.blue;
      case TypZagrozenia.chemikalia:
        return Colors.orange;
      case TypZagrozenia.gaz:
        return Colors.purple;
      case TypZagrozenia.paliwo:
        return Colors.red;
      case TypZagrozenia.wybuchowe:
        return Colors.deepOrange;
      case TypZagrozenia.promieniotworcze:
        return Colors.amber[600]!;
      case TypZagrozenia.biologiczne:
        return Colors.green;
      case TypZagrozenia.inne:
        return Colors.grey;
    }
  }

  IconData _ikonaDlaTypu(TypZagrozenia typ) {
    switch (typ) {
      case TypZagrozenia.zbiornik:
        return Icons.water_drop;
      case TypZagrozenia.chemikalia:
        return Icons.science;
      case TypZagrozenia.gaz:
        return Icons.cloud;
      case TypZagrozenia.paliwo:
        return Icons.local_gas_station;
      case TypZagrozenia.wybuchowe:
        return Icons.warning;
      case TypZagrozenia.promieniotworcze:
        return Icons.radio;
      case TypZagrozenia.biologiczne:
        return Icons.biotech;
      case TypZagrozenia.inne:
        return Icons.help_outline;
    }
  }

  double _kolorMarkera(TypZagrozenia typ) {
    switch (typ) {
      case TypZagrozenia.zbiornik:
        return BitmapDescriptor.hueBlue;
      case TypZagrozenia.chemikalia:
        return BitmapDescriptor.hueOrange;
      case TypZagrozenia.gaz:
        return BitmapDescriptor.hueViolet;
      case TypZagrozenia.paliwo:
        return BitmapDescriptor.hueRed;
      case TypZagrozenia.wybuchowe:
        return BitmapDescriptor.hueRose;
      case TypZagrozenia.promieniotworcze:
        return BitmapDescriptor.hueYellow;
      case TypZagrozenia.biologiczne:
        return BitmapDescriptor.hueGreen;
      case TypZagrozenia.inne:
        return BitmapDescriptor.hueAzure;
    }
  }

  Future<void> _dodajMiejsce() async {
    // TODO: Formularz dodawania miejsca
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funkcja w budowie - dodawanie miejsca')),
    );
  }

  Future<void> _edytujMiejsce(MiejsceNiebezpieczne miejsce) async {
    // TODO: Formularz edycji
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funkcja w budowie - edycja miejsca')),
    );
  }

  Future<void> _usunMiejsce(MiejsceNiebezpieczne miejsce) async {
    final potwierdz = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usuń miejsce'),
        content: Text('Czy na pewno usunąć "${miejsce.nazwa}"?'),
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
      await _firestore.collection('miejsca_niebezpieczne').doc(miejsce.id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Miejsce usunięte')),
        );
      }
    }
  }
}
