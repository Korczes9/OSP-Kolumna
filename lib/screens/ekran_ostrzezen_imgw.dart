import 'package:flutter/material.dart';
import '../services/serwis_imgw.dart';

class EkranOstrzezenIMGW extends StatefulWidget {
  const EkranOstrzezenIMGW({super.key});

  @override
  State<EkranOstrzezenIMGW> createState() => _EkranOstrzezenIMGWState();
}

class _EkranOstrzezenIMGWState extends State<EkranOstrzezenIMGW> {
  final SerwisIMGW _serwis = SerwisIMGW();
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
      final ostrzezenia = await _serwis.pobierzOstrzezenia();
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
        title: const Text('Ostrzeżenia IMGW'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _zaladujOstrzezenia,
            tooltip: 'Odśwież',
          ),
        ],
      ),
      body: _laduje
          ? const Center(child: CircularProgressIndicator())
          : _blad != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text('Błąd połączenia z IMGW'),
                      const SizedBox(height: 8),
                      Text(
                        _blad!,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _zaladujOstrzezenia,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Spróbuj ponownie'),
                      ),
                    ],
                  ),
                )
              : _ostrzezenia.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wb_sunny, size: 80, color: Colors.green[400]),
                          const SizedBox(height: 16),
                          const Text('Brak ostrzeżeń'),
                          const SizedBox(height: 8),
                          Text(
                            'Nie ma aktywnych ostrzeżeń dla gminy Łask',
                            style: TextStyle(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _zaladujOstrzezenia,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _ostrzezenia.length,
                        itemBuilder: (context, index) {
                          final ostrzezenie = _ostrzezenia[index];
                          return _buildKartaOstrzezenia(ostrzezenie);
                        },
                      ),
                    ),
    );
  }

  Widget _buildKartaOstrzezenia(OstrzezenieIMGW ostrzezenie) {
    Color kolor = _kolorPoziomu(ostrzezenie.poziom);
    IconData ikona = _ikonaPoziomu(ostrzezenie.poziom);
    String tekstPoziomu = _tekstPoziomu(ostrzezenie.poziom);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _pokazSzczegoly(ostrzezenie),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kolor, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nagłówek z poziomem zagrożenia
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kolor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(ikona, color: Colors.white, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tekstPoziomu,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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
                        maxLines: 2,
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
                  Row(
                    children: [
                      Icon(_ikonaPoziomu(ostrzezenie.poziom),
                          color: Colors.white, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _tekstPoziomu(ostrzezenie.poziom),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ostrzezenie.tytul,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
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

  Widget _buildInfo(String label, String value, IconData ikona) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(ikona, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Color _kolorPoziomu(PoziomOstrzezenia poziom) {
    switch (poziom) {
      case PoziomOstrzezenia.brak:
        return Colors.grey;
      case PoziomOstrzezenia.zolty:
        return Colors.amber[600]!;
      case PoziomOstrzezenia.pomaranczowy:
        return Colors.orange;
      case PoziomOstrzezenia.czerwony:
        return Colors.red;
    }
  }

  IconData _ikonaPoziomu(PoziomOstrzezenia poziom) {
    switch (poziom) {
      case PoziomOstrzezenia.brak:
        return Icons.info;
      case PoziomOstrzezenia.zolty:
        return Icons.warning;
      case PoziomOstrzezenia.pomaranczowy:
        return Icons.error;
      case PoziomOstrzezenia.czerwony:
        return Icons.dangerous;
    }
  }

  String _tekstPoziomu(PoziomOstrzezenia poziom) {
    switch (poziom) {
      case PoziomOstrzezenia.brak:
        return 'Informacja';
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
