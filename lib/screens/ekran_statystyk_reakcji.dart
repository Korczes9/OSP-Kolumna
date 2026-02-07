import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/strazak.dart';

/// Ekran ze statystykami reakcji strażaków na alarmy
class EkranStatystykReakcji extends StatefulWidget {
  final Strazak aktualnyStrazak;

  const EkranStatystykReakcji({super.key, required this.aktualnyStrazak});

  @override
  State<EkranStatystykReakcji> createState() => _EkranStatystykReakcjiState();
}

class _EkranStatystykReakcjiState extends State<EkranStatystykReakcji> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Współrzędne OSP Kolumna: Łask, ul. Leśników Polskich 63
  static const double _ospLat = 51.5906;
  static const double _ospLon = 19.1361;
  
  bool _ladowanie = true;
  List<Map<String, dynamic>> _statystykiStrazakow = [];
  Map<String, dynamic> _statystykiOgolne = {};

  @override
  void initState() {
    super.initState();
    _zaladujStatystyki();
  }

  Future<void> _zaladujStatystyki() async {
    setState(() => _ladowanie = true);

    try {
      // Pobierz wszystkie wyjazdy
      final wyjazdySnapshot = await _firestore
          .collection('wyjazdy')
          .orderBy('utworzonoO', descending: true)
          .limit(100)
          .get();

      // Pobierz wszystkich strażaków (tylko aktywnych)
      final strazacySnapshot = await _firestore
          .collection('strazacy')
          .where('aktywny', isEqualTo: true)
          .get();
      
      Map<String, Map<String, dynamic>> statystykiMap = {};
      
      // Inicjalizuj statystyki dla każdego strażaka
      for (var doc in strazacySnapshot.docs) {
        final data = doc.data();
        statystykiMap[doc.id] = {
          'id': doc.id,
          'imie': data['imie'] ?? '',
          'nazwisko': data['nazwisko'] ?? '',
          'pelneImie': '${data['imie']} ${data['nazwisko']}',
          'liczbaPotwierdzen': 0,
          'liczbaJadze': 0,
          'liczbaObecnosci': 0,
          'czasReakcjiLista': <int>[],
          'czasDotarciaLista': <int>[],
          'dystanseLista': <double>[],
          'predkosciLista': <double>[],
        };
      }

      int liczbWyjazdow = 0;

      // Analizuj każdy wyjazd
      for (var wyjazdDoc in wyjazdySnapshot.docs) {
        liczbWyjazdow++;
        final wyjazdData = wyjazdDoc.data();
        final DateTime czasAlarmu = (wyjazdData['utworzonoO'] as Timestamp).toDate();

        // Pobierz odpowiedzi strażaków
        final odpowiedziSnapshot = await _firestore
            .collection('wyjazdy')
            .doc(wyjazdDoc.id)
            .collection('odpowiedzi')
            .get();

        // Pobierz rzeczywistych uczestników
        final uczestnicy1 = (wyjazdData['strazacyIds'] as List<dynamic>?) ?? [];
        final uczestnicy2 = (wyjazdData['woz1StrazacyIds'] as List<dynamic>?) ?? [];
        final uczestnicy3 = (wyjazdData['woz2StrazacyIds'] as List<dynamic>?) ?? [];
        final wszyscyUczestnicy = {...uczestnicy1, ...uczestnicy2, ...uczestnicy3};

        for (var odpDoc in odpowiedziSnapshot.docs) {
          final strazakId = odpDoc.id;
          final odpData = odpDoc.data();
          final status = odpData['status'] ?? '';
          
          // Jeśli strażak nie jest w mapie, dodaj go (może być nieaktywny lub usunięty)
          if (!statystykiMap.containsKey(strazakId)) {
            // Spróbuj pobrać dane strażaka
            try {
              final strazakDoc = await _firestore.collection('strazacy').doc(strazakId).get();
              if (strazakDoc.exists) {
                final strazakData = strazakDoc.data()!;
                statystykiMap[strazakId] = {
                  'id': strazakId,
                  'imie': strazakData['imie'] ?? '',
                  'nazwisko': strazakData['nazwisko'] ?? '',
                  'pelneImie': '${strazakData['imie'] ?? 'Nieznany'} ${strazakData['nazwisko'] ?? 'Strażak'}',
                  'liczbaPotwierdzen': 0,
                  'liczbaJadze': 0,
                  'liczbaObecnosci': 0,
                  'czasReakcjiLista': <int>[],
                  'czasDotarciaLista': <int>[],
                  'dystanseLista': <double>[],
                  'predkosciLista': <double>[],
                };
              } else {
                // Strażak nie istnieje w bazie
                statystykiMap[strazakId] = {
                  'id': strazakId,
                  'imie': 'Nieznany',
                  'nazwisko': 'Strażak',
                  'pelneImie': 'Nieznany Strażak (ID: ${strazakId.substring(0, 8)})',
                  'liczbaPotwierdzen': 0,
                  'liczbaJadze': 0,
                  'liczbaObecnosci': 0,
                  'czasReakcjiLista': <int>[],
                  'czasDotarciaLista': <int>[],
                  'dystanseLista': <double>[],
                  'predkosciLista': <double>[],
                };
              }
            } catch (e) {
              debugPrint('⚠️ Błąd pobierania danych strażaka $strazakId: $e');
              continue;
            }
          }
          
          // Zwiększ liczbę potwierdzeń
          statystykiMap[strazakId]!['liczbaPotwierdzen']++;
          
          if (status == 'jadę') {
            statystykiMap[strazakId]!['liczbaJadze']++;
          }

          // Sprawdź czy był rzeczywiście obecny
          if (wszyscyUczestnicy.contains(strazakId)) {
            statystykiMap[strazakId]!['liczbaObecnosci']++;
          }

          // Oblicz czas reakcji
          final czasOdpowiedziStr = odpData['czasOdpowiedzi'];
          if (czasOdpowiedziStr != null) {
            final czasOdpowiedzi = DateTime.parse(czasOdpowiedziStr);
            final czasReakcji = czasOdpowiedzi.difference(czasAlarmu).inSeconds;
            
            if (czasReakcji > 0 && czasReakcji < 3600) { // maksymalnie 1 godzina
              statystykiMap[strazakId]!['czasReakcjiLista'].add(czasReakcji);
            }
          }

          // Oblicz czas dotarcia i dystans
          final czasDotarciaStr = odpData['czasDotarcia'];
          final lat = odpData['lokalizacjaLat'];
          final lon = odpData['lokalizacjaLon'];
          
          if (czasDotarciaStr != null) {
            final czasDotarcia = DateTime.parse(czasDotarciaStr);
            final czasDojazdu = czasDotarcia.difference(czasAlarmu).inSeconds;
            
            if (czasDojazdu > 0 && czasDojazdu < 3600) {
              statystykiMap[strazakId]!['czasDotarciaLista'].add(czasDojazdu);
            }
          }

          if (lat != null && lon != null) {
            // Oblicz dystans od pozycji alarmu do OSP
            final dystans = Geolocator.distanceBetween(lat, lon, _ospLat, _ospLon) / 1000; // km
            statystykiMap[strazakId]!['dystanseLista'].add(dystans);
            
            // Oblicz prędkość (jeśli jest czas dotarcia i odpowiedzi)
            if (czasDotarciaStr != null && czasOdpowiedziStr != null) {
              final czasDotarcia = DateTime.parse(czasDotarciaStr);
              final czasOdp = DateTime.parse(czasOdpowiedziStr);
              final czasDojazdu = czasDotarcia.difference(czasOdp).inMinutes;
              
              if (czasDojazdu > 0) {
                final predkosc = (dystans / czasDojazdu) * 60; // km/h
                if (predkosc > 0 && predkosc < 200) { // realistyczna prędkość
                  statystykiMap[strazakId]!['predkosciLista'].add(predkosc);
                }
              }
            }
          }
        }
      }
      
      // Oblicz średnie dla każdego strażaka
      List<Map<String, dynamic>> statystyki = [];
      
      for (var stat in statystykiMap.values) {
        final czasReakcjiLista = stat['czasReakcjiLista'] as List<int>;
        final czasDotarciaLista = stat['czasDotarciaLista'] as List<int>;
        final dystanseLista = stat['dystanseLista'] as List<double>;
        final predkosciLista = stat['predkosciLista'] as List<double>;
        
        stat['sredniCzasReakcji'] = czasReakcjiLista.isEmpty 
            ? null 
            : czasReakcjiLista.reduce((a, b) => a + b) / czasReakcjiLista.length;
        
        stat['sredniCzasDotarcia'] = czasDotarciaLista.isEmpty 
            ? null 
            : czasDotarciaLista.reduce((a, b) => a + b) / czasDotarciaLista.length;
        
        stat['sredniDystans'] = dystanseLista.isEmpty 
            ? null 
            : dystanseLista.reduce((a, b) => a + b) / dystanseLista.length;
        
        stat['sredniaPredkosc'] = predkosciLista.isEmpty 
            ? null 
            : predkosciLista.reduce((a, b) => a + b) / predkosciLista.length;
        
        // Wskaźnik zaangażowania (% obecności względem potwierdzeń "jadę")
        final liczbaJadze = stat['liczbaJadze'] as int;
        stat['wskaznikZaangazowania'] = liczbaJadze > 0 
            ? (stat['liczbaObecnosci'] as int) / liczbaJadze * 100 
            : 0.0;
        
        // Tylko strażacy z przynajmniej jednym potwierdzeniem
        if (stat['liczbaPotwierdzen'] > 0) {
          statystyki.add(stat);
        }
      }

      // Sortuj po średnim czasie reakcji (najszybsi pierwsi)
      statystyki.sort((a, b) {
        final aReakcja = a['sredniCzasReakcji'];
        final bReakcja = b['sredniCzasReakcji'];
        if (aReakcja == null && bReakcja == null) return 0;
        if (aReakcja == null) return 1;
        if (bReakcja == null) return -1;
        return aReakcja.compareTo(bReakcja);
      });

      // Oblicz statystyki ogólne
      final wszystkieCzasyReakcji = statystyki
          .where((s) => s['sredniCzasReakcji'] != null)
          .map((s) => s['sredniCzasReakcji'] as double)
          .toList();
      
      final wszystkieCzasyDotarcia = statystyki
          .where((s) => s['sredniCzasDotarcia'] != null)
          .map((s) => s['sredniCzasDotarcia'] as double)
          .toList();

      setState(() {
        _statystykiStrazakow = statystyki;
        _statystykiOgolne = {
          'liczbaWyjazdow': liczbWyjazdow,
          'sredniCzasReakcjiOgolny': wszystkieCzasyReakcji.isEmpty 
              ? null 
              : wszystkieCzasyReakcji.reduce((a, b) => a + b) / wszystkieCzasyReakcji.length,
          'sredniCzasDotarciaOgolny': wszystkieCzasyDotarcia.isEmpty 
              ? null 
              : wszystkieCzasyDotarcia.reduce((a, b) => a + b) / wszystkieCzasyDotarcia.length,
        };
        _ladowanie = false;
      });

    } catch (e) {
      debugPrint('❌ Błąd ładowania statystyk reakcji: $e');
      setState(() => _ladowanie = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statystyki Reakcji'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _zaladujStatystyki,
          ),
        ],
      ),
      body: _ladowanie
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Statystyki ogólne
                _buildStatystykiOgolne(),
                const SizedBox(height: 24),

                // Ranking czasu reakcji
                _buildSekcja(
                  'Najszybsza reakcja na alarm',
                  Icons.speed,
                  Colors.green,
                  _statystykiStrazakow,
                  sortowaniePo: 'sredniCzasReakcji',
                ),
                const SizedBox(height: 24),

                // Ranking zaangażowania
                _buildSekcja(
                  'Ranking zaangażowania',
                  Icons.emoji_events,
                  Colors.orange,
                  _statystykiStrazakow,
                  sortowaniePo: 'wskaznikZaangazowania',
                  odwrotnie: true,
                ),
                const SizedBox(height: 24),

                // Ranking czasu dotarcia
                _buildSekcja(
                  'Najszybszy dojazd do OSP',
                  Icons.directions_car,
                  Colors.blue,
                  _statystykiStrazakow,
                  sortowaniePo: 'sredniCzasDotarcia',
                ),
              ],
            ),
    );
  }

  Widget _buildStatystykiOgolne() {
    final sredniReakcja = _statystykiOgolne['sredniCzasReakcjiOgolny'];
    final sredniDotarcie = _statystykiOgolne['sredniCzasDotarciaOgolny'];

    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue[700], size: 32),
                const SizedBox(width: 12),
                const Text(
                  'Statystyki ogólne',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatWiersz(
              'Przeanalizowano wyjazdów',
              '${_statystykiOgolne['liczbaWyjazdow']}',
              Icons.local_fire_department,
            ),
            if (sredniReakcja != null) ...[
              const Divider(),
              _buildStatWiersz(
                'Średni czas reakcji',
                _formatujCzas(sredniReakcja),
                Icons.timer,
              ),
            ],
            if (sredniDotarcie != null) ...[
              const Divider(),
              _buildStatWiersz(
                'Średni czas dotarcia',
                _formatujCzas(sredniDotarcie),
                Icons.access_time,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSekcja(
    String tytul,
    IconData ikona,
    Color kolor,
    List<Map<String, dynamic>> dane, {
    required String sortowaniePo,
    bool odwrotnie = false,
  }) {
    // Sortuj dane
    final posortowane = List<Map<String, dynamic>>.from(dane);
    posortowane.sort((a, b) {
      final aVal = a[sortowaniePo];
      final bVal = b[sortowaniePo];
      if (aVal == null && bVal == null) return 0;
      if (aVal == null) return 1;
      if (bVal == null) return -1;
      
      int comparison = (aVal as num).compareTo(bVal as num);
      return odwrotnie ? -comparison : comparison;
    });

    // Weź tylko top 10
    final top10 = posortowane.take(10).toList();

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kolor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(ikona, color: kolor, size: 28),
                const SizedBox(width: 12),
                Text(
                  tytul,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kolor,
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: top10.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final stat = top10[index];
              return _buildRankingItem(index + 1, stat, sortowaniePo);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRankingItem(int miejsce, Map<String, dynamic> stat, String pole) {
    Color kolorMiejsca;
    if (miejsce == 1) {
      kolorMiejsca = Colors.amber;
    } else if (miejsce == 2) {
      kolorMiejsca = Colors.grey;
    } else if (miejsce == 3) {
      kolorMiejsca = Colors.brown;
    } else {
      kolorMiejsca = Colors.blue[200]!;
    }

    String wartosc = '';
    String dodatkowe = '';

    switch (pole) {
      case 'sredniCzasReakcji':
        final czas = stat['sredniCzasReakcji'];
        wartosc = czas != null ? _formatujCzas(czas) : '---';
        dodatkowe = '${stat['liczbaPotwierdzen']} potwierdzeń';
        break;
      case 'wskaznikZaangazowania':
        final wskaznik = stat['wskaznikZaangazowania'];
        wartosc = wskaznik != null ? '${wskaznik.toStringAsFixed(0)}%' : '---';
        dodatkowe = '${stat['liczbaObecnosci']}/${stat['liczbaJadze']} wyjazdów';
        break;
      case 'sredniCzasDotarcia':
        final czas = stat['sredniCzasDotarcia'];
        final dystans = stat['sredniDystans'];
        final predkosc = stat['sredniaPredkosc'];
        wartosc = czas != null ? _formatujCzas(czas) : '---';
        if (dystans != null) {
          dodatkowe = '${dystans.toStringAsFixed(1)} km';
          if (predkosc != null) {
            dodatkowe += ' • ${predkosc.toStringAsFixed(0)} km/h';
          }
        }
        break;
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: kolorMiejsca,
        child: Text(
          '$miejsce',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      title: Text(
        stat['pelneImie'],
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: dodatkowe.isNotEmpty ? Text(dodatkowe) : null,
      trailing: Text(
        wartosc,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatWiersz(String nazwa, String wartosc, IconData ikona) {
    return Row(
      children: [
        Icon(ikona, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            nazwa,
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
        ),
        Text(
          wartosc,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatujCzas(double sekundy) {
    final minuty = (sekundy / 60).floor();
    final sek = (sekundy % 60).floor();
    
    if (minuty == 0) {
      return '${sek}s';
    }
    return '${minuty}m ${sek}s';
  }
}
