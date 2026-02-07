import 'package:flutter/material.dart';
import '../services/serwis_powiadomien.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

/// Pełnoekranowy ekran alarmu wyświetlany przy powiadomieniu
class EkranAlarmufullscreen extends StatefulWidget {
  final String tytul;
  final String? lokalizacja;
  final String kategoria;
  final String? opis;
  final String? wyjazdId;
  final String godzina;

  const EkranAlarmufullscreen({
    super.key,
    required this.tytul,
    this.lokalizacja,
    required this.kategoria,
    this.opis,
    this.wyjazdId,
    required this.godzina,
  });

  @override
  State<EkranAlarmufullscreen> createState() => _EkranAlarmufullscreenState();
}

class _EkranAlarmufullscreenState extends State<EkranAlarmufullscreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  String _wybranyStatus = 'jadę';
  bool _potwierdzono = false;

  @override
  void initState() {
    super.initState();
    
    // Animacja pulsowania dla alarmu
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _potwierdzUdzial() async {
    // Zatrzymaj syrenę
    await SerwisPowiadomien.zatrzymajSyrene();

    setState(() => _potwierdzono = true);

    // Zapisz odpowiedź do Firestore
    if (widget.wyjazdId != null) {
      try {
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          // Pobierz lokalizację
          Position? pozycja;
          try {
            pozycja = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 5),
            );
          } catch (e) {
            debugPrint('Nie można pobrać lokalizacji: $e');
          }

          final Map<String, dynamic> odpowiedz = {
            'status': _wybranyStatus,
            'czasOdpowiedzi': DateTime.now().toIso8601String(),
          };

          // Dodaj lokalizację jeśli udało się pobrać
          if (pozycja != null) {
            odpowiedz['lokalizacjaLat'] = pozycja.latitude;
            odpowiedz['lokalizacjaLon'] = pozycja.longitude;
            odpowiedz['lokalizacjaDokl'] = pozycja.accuracy;
          }

          await FirebaseFirestore.instance
              .collection('wyjazdy')
              .doc(widget.wyjazdId)
              .collection('odpowiedzi')
              .doc(userId)
              .set(odpowiedz);

          // Jeśli jadę, uruchom śledzenie dotarcia
          if (_wybranyStatus == 'jadę') {
            _sledzDotarcie(userId);
          }
        }
      } catch (e) {
        print('Błąd zapisywania odpowiedzi: $e');
      }
    }

    // Pokaż komunikat
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('Potwierdzono: $_wybranyStatus'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Poczekaj chwilę i zamknij ekran
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  /// Śledź kiedy strażak dotrze do OSP (OSP Kolumna: Łask, ul. Leśników Polskich 63)
  Future<void> _sledzDotarcie(String userId) async {
    const double ospLat = 51.5906;
    const double ospLon = 19.1361;
    const double promienOSP = 100; // metry

    try {
      // Sprawdzaj co 30 sekund przez maksymalnie 30 minut
      for (int i = 0; i < 60; i++) {
        await Future.delayed(const Duration(seconds: 30));

        try {
          final pozycja = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10),
          );

          final dystans = Geolocator.distanceBetween(
            pozycja.latitude,
            pozycja.longitude,
            ospLat,
            ospLon,
          );

          // Jeśli jest w promieniu 100m od OSP
          if (dystans <= promienOSP) {
            debugPrint('✅ Strażak dotarł do OSP! Dystans: ${dystans.toStringAsFixed(0)}m');

            // Zapisz czas dotarcia
            await FirebaseFirestore.instance
                .collection('wyjazdy')
                .doc(widget.wyjazdId)
                .collection('odpowiedzi')
                .doc(userId)
                .update({
              'czasDotarcia': DateTime.now().toIso8601String(),
            });

            break;
          }
        } catch (e) {
          debugPrint('Błąd śledzenia lokalizacji: $e');
        }
      }
    } catch (e) {
      debugPrint('Błąd śledzenia dotarcia: $e');
    }
  }

  Future<void> _odrzucAlarm() async {
    // Zatrzymaj syrenę
    await SerwisPowiadomien.zatrzymajSyrene();

    // Zapisz odpowiedź do Firestore
    if (widget.wyjazdId != null) {
      try {
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          await FirebaseFirestore.instance
              .collection('wyjazdy')
              .doc(widget.wyjazdId)
              .collection('odpowiedzi')
              .doc(userId)
              .set({
            'status': 'nie jadę',
            'czasOdpowiedzi': DateTime.now().toIso8601String(),
          });
        }
      } catch (e) {
        print('Błąd zapisywania odpowiedzi: $e');
      }
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime godzina = DateTime.tryParse(widget.godzina) ?? DateTime.now();
    
    return WillPopScope(
      onWillPop: () async {
        // Wymagaj potwierdzenia przed zamknięciem
        return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Czy na pewno?'),
                content: const Text('Czy chcesz zamknąć ekran alarmu bez potwierdzenia?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Anuluj'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Zamknij'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              // Nagłówek z animacją
              Expanded(
                flex: 2,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.red[900]!, Colors.red[700]!],
                    ),
                  ),
                  child: ScaleTransition(
                    scale: _pulseAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.warning_rounded,
                          size: 100,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.tytul,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.kategoria.toUpperCase(),
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.orange[300],
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Szczegóły alarmu
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Godzina
                      _buildInfoRow(
                        Icons.access_time,
                        'Godzina alarmu',
                        '${godzina.hour.toString().padLeft(2, '0')}:${godzina.minute.toString().padLeft(2, '0')}',
                      ),
                      const SizedBox(height: 16),
                      
                      // Lokalizacja (opcjonalna)
                      if (widget.lokalizacja != null && widget.lokalizacja!.isNotEmpty) ...[
                        _buildInfoRow(
                          Icons.location_on,
                          'Lokalizacja',
                          widget.lokalizacja!,
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Opis (opcjonalny)
                      if (widget.opis != null && widget.opis!.isNotEmpty) ...[
                        _buildInfoRow(
                          Icons.description,
                          'Opis',
                          widget.opis!,
                        ),
                        const SizedBox(height: 24),
                      ],

                      const Divider(color: Colors.white24),
                      const SizedBox(height: 16),

                      // Wybór statusu (jeśli nie potwierdzono)
                      if (!_potwierdzono) ...[
                        const Text(
                          'Twoja odpowiedź:',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Jadę'),
                              selected: _wybranyStatus == 'jadę',
                              onSelected: (selected) {
                                if (selected) setState(() => _wybranyStatus = 'jadę');
                              },
                              selectedColor: Colors.green,
                              labelStyle: TextStyle(
                                color: _wybranyStatus == 'jadę' ? Colors.white : Colors.black,
                              ),
                            ),
                            ChoiceChip(
                              label: const Text('Wrzuć ciuchy!'),
                              selected: _wybranyStatus == 'wrzuć ciuchy',
                              onSelected: (selected) {
                                if (selected) setState(() => _wybranyStatus = 'wrzuć ciuchy');
                              },
                              selectedColor: Colors.orange,
                              labelStyle: TextStyle(
                                color: _wybranyStatus == 'wrzuć ciuchy' ? Colors.white : Colors.black,
                              ),
                            ),
                            ChoiceChip(
                              label: const Text('Nie mogę'),
                              selected: _wybranyStatus == 'nie mogę',
                              onSelected: (selected) {
                                if (selected) setState(() => _wybranyStatus = 'nie mogę');
                              },
                              selectedColor: Colors.red,
                              labelStyle: TextStyle(
                                color: _wybranyStatus == 'nie mogę' ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Przyciski akcji
              Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    if (!_potwierdzono) ...[
                      // Przycisk potwierdzenia
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton.icon(
                          onPressed: _potwierdzUdzial,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.check_circle, size: 28),
                          label: const Text(
                            'POTWIERDZAM',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Przycisk odrzucenia
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _odrzucAlarm,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white30),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.cancel),
                          label: const Text('Nie jadę'),
                        ),
                      ),
                    ] else ...[
                      const Icon(
                        Icons.check_circle,
                        size: 60,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Potwierdzono!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.orange[300], size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
