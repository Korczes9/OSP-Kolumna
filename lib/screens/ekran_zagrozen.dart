import 'package:flutter/material.dart';
import '../models/strazak.dart';
import '../services/serwis_imgw.dart';

/// Główny ekran zestawienia zagrożeń w rejonie
class EkranZagrozen extends StatefulWidget {
  final Strazak strazak;

  const EkranZagrozen({super.key, required this.strazak});

  @override
  State<EkranZagrozen> createState() => _EkranZagrozeniState();
}

class _EkranZagrozeniState extends State<EkranZagrozen> {
  final SerwisIMGW _serwisIMGW = SerwisIMGW();
  
  List<OstrzezenieIMGW> _ostrzezenia = [];
  bool _laduje = true;
  String? _blad;

  @override
  void initState() {
    super.initState();
    _zaladujOstrzezenia();
  }

  Future<void> _zaladujOstrzezenia() async {
    setState(() {
      _laduje = true;
      _blad = null;
    });

    try {
      final ostrzezenia = await _serwisIMGW.pobierzWszystkieOstrzezenia(forceRefresh: true);
      if (mounted) {
        setState(() {
          _ostrzezenia = ostrzezenia;
          _laduje = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _blad = e.toString();
          _laduje = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zagrożenia i bezpieczeństwo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _zaladujOstrzezenia,
            tooltip: 'Odśwież dane',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _zaladujOstrzezenia,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Nagłówek
            Card(
              color: Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 64,
                      color: Colors.red[700],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Zestawienie zagrożeń w rejonie',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'IMGW + Alerty RCB • Gmina Łask i okolice',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Ostrzeżenia IMGW - bezpośrednia lista
            if (_laduje)
              const Center(child: CircularProgressIndicator())
            else if (_blad != null)
              Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red[700]),
                      const SizedBox(height: 8),
                      const Text('Błąd ładowania ostrzeżeń'),
                      const SizedBox(height: 4),
                      Text(
                        _blad!,
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else ..._ostrzezenia.map((ostrzezenie) {
              return _buildOstrzezenieCard(ostrzezenie);
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildOstrzezenieCard(OstrzezenieIMGW ostrzezenie) {
    Color kolor = _kolorPoziomu(ostrzezenie.poziom);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _pokazSzczegoly(ostrzezenie),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nagłówek z kolorem poziomu
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kolor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _nazwaPoziomy(ostrzezenie.poziom),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      ostrzezenie.region,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Treść
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ostrzezenie.tytul,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (ostrzezenie.opis.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      ostrzezenie.opis,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${_formatujDate(ostrzezenie.dataOd)} - ${_formatujDate(ostrzezenie.dataDo)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
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
    );
  }

  void _pokazSzczegoly(OstrzezenieIMGW ostrzezenie) {
    Color kolor = _kolorPoziomu(ostrzezenie.poziom);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kolor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nazwaPoziomy(ostrzezenie.poziom),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ostrzezenie.tytul,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (ostrzezenie.opis.isNotEmpty) ...[
                    const Text(
                      'Opis ostrzeżenia:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ostrzezenie.opis,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const Divider(height: 24),
                  ],
                  _buildInfo('Region', ostrzezenie.region, Icons.location_on),
                  _buildInfo(
                    'Wydano',
                    _formatujDataCzas(ostrzezenie.dataWydania),
                    Icons.access_time,
                  ),
                  _buildInfo(
                    'Obowiązuje od',
                    _formatujDataCzas(ostrzezenie.dataOd),
                    Icons.event,
                  ),
                  _buildInfo(
                    'Obowiązuje do',
                    _formatujDataCzas(ostrzezenie.dataDo),
                    Icons.event_available,
                  ),
                ],
              ),
            ),
          ],
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

  Widget _buildInfo(String label, String wartosc, IconData ikona) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(ikona, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  wartosc,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _kolorPoziomu(PoziomOstrzezenia poziom) {
    switch (poziom) {
      case PoziomOstrzezenia.zolty:
        return Colors.amber[600]!;
      case PoziomOstrzezenia.pomaranczowy:
        return Colors.orange[700]!;
      case PoziomOstrzezenia.czerwony:
        return Colors.red[700]!;
      default:
        return Colors.grey;
    }
  }

  String _nazwaPoziomy(PoziomOstrzezenia poziom) {
    switch (poziom) {
      case PoziomOstrzezenia.brak:
        return 'Brak ostrzeżeń';
      case PoziomOstrzezenia.zolty:
        return 'Ostrzeżenie 1° (żółty)';
      case PoziomOstrzezenia.pomaranczowy:
        return 'Ostrzeżenie 2° (pomarańczowy)';
      case PoziomOstrzezenia.czerwony:
        return 'Ostrzeżenie 3° (czerwony)';
    }
  }

  String _formatujDate(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}.${data.month.toString().padLeft(2, '0')}';
  }

  String _formatujDataCzas(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}.${data.month.toString().padLeft(2, '0')}.${data.year} ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }
}
