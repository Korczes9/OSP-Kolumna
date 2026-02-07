import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/serwis_powiadomien.dart';

/// Przycisk testowego alarmu z dźwiękiem syreny
class PrzyciskTestowegoAlarmu extends StatefulWidget {
  const PrzyciskTestowegoAlarmu({super.key});

  @override
  State<PrzyciskTestowegoAlarmu> createState() =>
      _PrzyciskTestowegoAlarmuState();
}

class _PrzyciskTestowegoAlarmuState extends State<PrzyciskTestowegoAlarmu> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _odtwarzanie = false;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _odtworzAlarm() async {
    try {
      if (_odtwarzanie) {
        await _audioPlayer.stop();
        setState(() => _odtwarzanie = false);
        return;
      }

      setState(() => _odtwarzanie = true);

      // Użyj nowego pliku syreny syrena-2.mp3
      try {
        await _audioPlayer.play(AssetSource('sounds/syrena-2.mp3'));
      } catch (e) {
        debugPrint('Brak pliku syrena-2.mp3, próba siren.mp3: $e');
        try {
          await _audioPlayer.play(AssetSource('sounds/siren.mp3'));
        } catch (e2) {
          debugPrint('Brak plików dźwiękowych, pomijam dźwięk alarmu: $e2');
          setState(() => _odtwarzanie = false);
        }
      }

      // Jeśli nie ma pliku, pokaż komunikat
      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (state == PlayerState.completed || state == PlayerState.stopped) {
          if (mounted) {
            setState(() => _odtwarzanie = false);
          }
        }
      });

      // Automatycznie zatrzymaj po 5 sekundach
      Future.delayed(const Duration(seconds: 5), () async {
        if (_odtwarzanie) {
          await _audioPlayer.stop();
          if (mounted) {
            setState(() => _odtwarzanie = false);
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 8),
              Text('ALARM TESTOWY - Odtwarzanie syreny'),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      debugPrint('Błąd odtwarzania alarmu: $e');
      setState(() => _odtwarzanie = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nie można odtworzyć dźwięku alarmu: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: _odtworzAlarm,
      backgroundColor: _odtwarzanie ? Colors.orange : Colors.red[700],
      icon: Icon(
        _odtwarzanie ? Icons.stop : Icons.campaign,
        color: Colors.white,
      ),
      label: Text(
        _odtwarzanie ? 'STOP' : 'ALARM PRÓBNY',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Widget uproszczonego przycisku alarmu (dla innych ekranów)
class IkonaTestowegoAlarmu extends StatelessWidget {
  const IkonaTestowegoAlarmu({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.campaign),
      tooltip: 'Alarm próbny',
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.red[700]),
                const SizedBox(width: 8),
                const Text('Alarm próbny'),
              ],
            ),
            content: const Text(
              'Czy chcesz uruchomić alarm próbny?\n\n'
              'Zobaczysz pełnoekranowy ekran alarmu z dźwiękiem syreny.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Anuluj'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);

                  // Użyj nowego serwisu powiadomień
                  await SerwisPowiadomien.wyslijTestowyAlarm();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                ),
                child: const Text('Uruchom'),
              ),
            ],
          ),
        );
      },
    );
  }
}
