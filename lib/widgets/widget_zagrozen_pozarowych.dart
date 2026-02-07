import 'package:flutter/material.dart';
import '../services/serwis_imgw.dart';

/// Widget pokazujący zagrożenie pożarowe lasów i alerty wiatru
class WidgetZagrozeniaPozarowego extends StatefulWidget {
  const WidgetZagrozeniaPozarowego({super.key});

  @override
  State<WidgetZagrozeniaPozarowego> createState() => _WidgetZagrozeniaPozarowegoState();
}

class _WidgetZagrozeniaPozarowegoState extends State<WidgetZagrozeniaPozarowego> {
  final SerwisIMGW _serwisIMGW = SerwisIMGW();
  Map<String, dynamic>? _zagrozeniePozarowe;
  Map<String, dynamic>? _alertWiatru;
  bool _ladowanie = true;

  @override
  void initState() {
    super.initState();
    _zaladujDane();
  }

  Future<void> _zaladujDane() async {
    setState(() => _ladowanie = true);
    
    final pozarowe = await _serwisIMGW.pobierzZagrozeniePozaroweIPN();
    final wiatr = await _serwisIMGW.sprawdzSilnyWiatr();
    
    if (mounted) {
      setState(() {
        _zagrozeniePozarowe = pozarowe;
        _alertWiatru = wiatr;
        _ladowanie = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ladowanie) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    // Sprawdź czy są jakieś alerty
    final czyAlertWiatru = _alertWiatru?['aktywny'] == true;
    final poziomPozarowy = _zagrozeniePozarowe?['stopien'] ?? 0;
    final czyZagrozeniePozarowe = poziomPozarowy >= 2; // Pokaż od średniego

    if (!czyAlertWiatru && !czyZagrozeniePozarowe) {
      // Brak zagrożeń - nie pokazuj widgetu
      return const SizedBox.shrink();
    }

    return Card(
      color: _kolorTla(),
      elevation: 4,
      child: Column(
        children: [
          // Nagłówek
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kolorNaglowka(),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Alerty i Zagrożenia',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _zaladujDane,
                ),
              ],
            ),
          ),

          // Zagrożenie pożarowe
          if (czyZagrozeniePozarowe) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    _zagrozeniePozarowe?['emoji'] ?? '🔥',
                    style: const TextStyle(fontSize: 40),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Zagrożenie pożarowe lasów',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _zagrozeniePozarowe?['opis'] ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _kolorStopnia(poziomPozarowy),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Stopień $poziomPozarowy/4',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Alert wiatru
          if (czyAlertWiatru) ...[
            if (czyZagrozeniePozarowe) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    '💨',
                    style: TextStyle(fontSize: 40),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Silny wiatr - zagrożenie!',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _alertWiatru?['ostrzezenie'] ?? '',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.air,
                              size: 20,
                              color: Colors.red[700],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_alertWiatru?['predkosc'] ?? 0} km/h',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _kolorTla() {
    final czyAlertWiatru = _alertWiatru?['aktywny'] == true;
    final poziomPozarowy = _zagrozeniePozarowe?['stopien'] ?? 0;
    
    if (czyAlertWiatru || poziomPozarowy >= 3) {
      return Colors.red[50]!;
    } else if (poziomPozarowy >= 2) {
      return Colors.orange[50]!;
    }
    return Colors.yellow[50]!;
  }

  Color _kolorNaglowka() {
    final czyAlertWiatru = _alertWiatru?['aktywny'] == true;
    final poziomPozarowy = _zagrozeniePozarowe?['stopien'] ?? 0;
    
    if (czyAlertWiatru || poziomPozarowy >= 3) {
      return Colors.red[700]!;
    } else if (poziomPozarowy >= 2) {
      return Colors.orange[700]!;
    }
    return Colors.amber[600]!;
  }

  Color _kolorStopnia(int stopien) {
    switch (stopien) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.amber[600]!;
      case 3:
        return Colors.orange[700]!;
      case 4:
        return Colors.red[700]!;
      default:
        return Colors.grey;
    }
  }
}
