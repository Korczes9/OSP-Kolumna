import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../models/wyjazd.dart';

class MapItem {
  final Wyjazd wyjazd;
  final LatLng pozycja;

  MapItem(this.wyjazd, this.pozycja);
}

class EkranMapyWyjazdow extends StatefulWidget {
  const EkranMapyWyjazdow({super.key});

  @override
  State<EkranMapyWyjazdow> createState() => _EkranMapyWyjazdowState();
}

class _EkranMapyWyjazdowState extends State<EkranMapyWyjazdow> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  List<MapItem> _mapItems = [];
  LatLng _centrum = const LatLng(51.9189, 19.1451); // Kolumna (domyślnie)
  bool _pobieraLokalizacje = true;
  
  // Filtrowanie po roku
  int? _wybranyRok;
  List<int> _dostepneLata = [];

  @override
  void initState() {
    super.initState();
    _pobierzAktualnaLokalizacje();
    _ladujDostepneLata();
    _ladujWyjazdy();
  }

  Future<void> _pobierzAktualnaLokalizacje() async {
    try {
      // Sprawdź uprawnienia
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        // Użyj domyślnej lokalizacji
        setState(() => _pobieraLokalizacje = false);
        return;
      }

      // Pobierz aktualną pozycję
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _centrum = LatLng(position.latitude, position.longitude);
        _pobieraLokalizacje = false;
      });

      // Przesuń mapę do aktualnej lokalizacji
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_centrum, 13),
      );
    } catch (e) {
      // Błąd - użyj domyślnej lokalizacji
      setState(() => _pobieraLokalizacje = false);
    }
  }

  Future<void> _createMarkers() async {
    final markers = <Marker>{};
    for (var i = 0; i < _mapItems.length; i++) {
      final item = _mapItems[i];
      markers.add(
        Marker(
          markerId: MarkerId('marker_$i'),
          position: item.pozycja,
          onTap: () => _pokazSzczegolyWyjazdu(item.wyjazd),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed,
          ),
          infoWindow: InfoWindow(
            title: '🚒 ' + item.wyjazd.kategoria.nazwa,
            snippet: item.wyjazd.lokalizacja,
          ),
        ),
      );
    }
    setState(() {
      _markers = markers;
    });
  }

  Future<void> _ladujDostepneLata() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('wyjazdy')
          .orderBy('dataWyjazdu', descending: true)
          .get();

      final lata = snapshot.docs
          .map((doc) {
            final data = doc.data();
            final dataWyjazdu = (data['dataWyjazdu'] as Timestamp?)?.toDate();
            return dataWyjazdu?.year;
          })
          .where((rok) => rok != null)
          .cast<int>()
          .toSet()
          .toList();

      lata.sort((a, b) => b.compareTo(a)); // Sortuj malejąco

      setState(() {
        _dostepneLata = lata;
      });
    } catch (e) {
      // Błąd przy ładowaniu lat - kontynuuj normalnie
    }
  }

  Future<void> _ladujWyjazdy() async {
    try {
      Query query = FirebaseFirestore.instance
          .collection('wyjazdy')
          .orderBy('dataWyjazdu', descending: true)
          .limit(500);

      final snapshot = await query.get();

      var wyjazdy = snapshot.docs
          .map((doc) => Wyjazd.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // Filtruj po roku jeśli wybrany
      if (_wybranyRok != null) {
        wyjazdy = wyjazdy.where((w) => w.dataWyjazdu.year == _wybranyRok).toList();
      }

      // Konwertuj adresy na współrzędne GPS używając geocodingu
      final items = <MapItem>[];
      for (var w in wyjazdy) {
        LatLng pozycja;
        
        try {
          // Spróbuj geokodować adres
          final locations = await locationFromAddress(
            w.lokalizacja,
          );
          
          if (locations.isNotEmpty) {
            pozycja = LatLng(
              locations.first.latitude,
              locations.first.longitude,
            );
          } else {
            // Jeśli nie znaleziono - użyj domyślnej pozycji z małym offsetem
            final offset = w.hashCode % 100;
            pozycja = LatLng(
              _centrum.latitude + offset / 10000,
              _centrum.longitude + offset / 10000,
            );
          }
        } catch (e) {
          // Błąd geocodingu - użyj pozycji centralnej z offsetem
          final offset = w.hashCode % 100;
          pozycja = LatLng(
            _centrum.latitude + offset / 10000,
            _centrum.longitude + offset / 10000,
          );
        }
        
        items.add(MapItem(w, pozycja));
      }

      setState(() {
        _mapItems = items;
      });

      await _createMarkers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd ładowania wyjazdów: $e')),
        );
      }
    }
  }

  void _pokazSzczegolyWyjazdu(Wyjazd wyjazd) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.local_fire_department, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                wyjazd.kategoria.nazwa,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(Icons.location_on, 'Lokalizacja', wyjazd.lokalizacja),
              _buildInfoRow(
                Icons.calendar_today,
                'Data',
                _formatujDate(wyjazd.dataWyjazdu),
              ),
              if (wyjazd.liczbaStrazakow > 0)
                _buildInfoRow(
                  Icons.people,
                  'Liczba strażaków',
                  '${wyjazd.liczbaStrazakow}',
                ),
              if (wyjazd.opis.isNotEmpty) ...[
                const Divider(),
                const Text(
                  'Opis:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  wyjazd.opis,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
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

  Widget _buildInfoRow(IconData ikona, String label, String wartosc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikona, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: wartosc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatujDate(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}.${data.month.toString().padLeft(2, '0')}.${data.year} ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa wyjazdów 🚒'),
        actions: [
          // Filtr po roku
          if (_dostepneLata.isNotEmpty)
            PopupMenuButton<int?>(
              icon: Icon(
                Icons.filter_list,
                color: _wybranyRok != null ? Colors.orange : Colors.white,
              ),
              tooltip: 'Filtruj po roku',
              onSelected: (rok) {
                setState(() {
                  _wybranyRok = rok;
                });
                _ladujWyjazdy();
              },
              itemBuilder: (context) => [
                PopupMenuItem<int?>(
                  value: null,
                  child: Row(
                    children: [
                      Icon(
                        _wybranyRok == null ? Icons.check : Icons.close,
                        size: 16,
                        color: _wybranyRok == null ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      const Text('Wszystkie lata'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                ..._dostepneLata.map((rok) => PopupMenuItem<int>(
                      value: rok,
                      child: Row(
                        children: [
                          Icon(
                            _wybranyRok == rok ? Icons.check : Icons.close,
                            size: 16,
                            color: _wybranyRok == rok ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(rok.toString()),
                        ],
                      ),
                    )),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _pobierzAktualnaLokalizacje,
            tooltip: 'Moja lokalizacja',
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _centrum,
              zoom: 13,
            ),
            markers: _markers,
            onMapCreated: (controller) {
              _mapController = controller;
              if (!_pobieraLokalizacje) {
                controller.animateCamera(
                  CameraUpdate.newLatLngZoom(_centrum, 13),
                );
              }
            },
            myLocationButtonEnabled: true,
            myLocationEnabled: true,
          ),
          if (_mapItems.isEmpty || _pobieraLokalizacje)
            Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(_pobieraLokalizacje 
                        ? 'Pobieranie lokalizacji...' 
                        : 'Ładowanie wyjazdów...'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(_centrum, 13),
          );
        },
        icon: const Icon(Icons.my_location),
        label: const Text('Wyśrodkuj'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
