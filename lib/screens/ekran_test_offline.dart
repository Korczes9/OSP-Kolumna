import 'package:flutter/material.dart';
import '../services/serwis_polaczenia.dart';
import '../services/serwis_cache_lokalnego.dart';
import '../services/serwis_alarmu.dart';
import '../services/serwis_wozu.dart';

/// Ekran testowy pokazujący funkcje offline
class EkranTestOffline extends StatefulWidget {
  const EkranTestOffline({super.key});

  @override
  State<EkranTestOffline> createState() => _EkranTestOfflineState();
}

class _EkranTestOfflineState extends State<EkranTestOffline> {
  bool _czyOnline = false;
  int _liczbaOczekujacych = 0;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _sprawdzStatus();
  }

  Future<void> _sprawdzStatus() async {
    final online = await SerwisPolaczenia.czyOnline();
    final operacje = await SerwisCacheLokalne.pobierzOczekujaceOperacje();
    
    setState(() {
      _czyOnline = online;
      _liczbaOczekujacych = operacje.length;
      _statusMessage = online ? 'Połączono z internetem' : 'Tryb offline';
    });
  }

  Future<void> _testujZapisOffline() async {
    setState(() {
      _statusMessage = 'Zapisywanie testu offline...';
    });

    await AlarmService.setStatus(
      userId: 'test_user',
      name: 'Test User',
      status: 'Jadę',
    );

    await _sprawdzStatus();
    
    setState(() {
      _statusMessage = 'Test zapisany!';
    });
  }

  Future<void> _synchronizuj() async {
    setState(() {
      _statusMessage = 'Synchronizacja...';
    });

    await AlarmService.synchronizujOperacjeOffline();
    await SerwisWozu.synchronizujOperacjeOffline();
    
    await _sprawdzStatus();

    setState(() {
      _statusMessage = 'Synchronizacja zakończona!';
    });
  }

  Future<void> _wyczyscCache() async {
    await SerwisCacheLokalne.wyczyscCache();
    await _sprawdzStatus();
    
    setState(() {
      _statusMessage = 'Cache wyczyszczony';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Offline'),
        backgroundColor: _czyOnline ? Colors.green : Colors.orange,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status Card
          Card(
            color: _czyOnline ? Colors.green.shade50 : Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    _czyOnline ? Icons.cloud_done : Icons.cloud_off,
                    size: 64,
                    color: _czyOnline ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Oczekujące operacje: $_liczbaOczekujacych',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          const Text(
            'Akcje Testowe',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Test Button
          ElevatedButton.icon(
            onPressed: _testujZapisOffline,
            icon: const Icon(Icons.save),
            label: const Text('Testuj Zapis Offline'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
          ),
          
          const SizedBox(height: 12),

          // Sync Button
          ElevatedButton.icon(
            onPressed: _czyOnline ? _synchronizuj : null,
            icon: const Icon(Icons.sync),
            label: const Text('Synchronizuj Teraz'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),

          const SizedBox(height: 12),

          // Refresh Button
          OutlinedButton.icon(
            onPressed: _sprawdzStatus,
            icon: const Icon(Icons.refresh),
            label: const Text('Odśwież Status'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
          ),

          const SizedBox(height: 12),

          // Clear Cache Button
          OutlinedButton.icon(
            onPressed: _wyczyscCache,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Wyczyść Cache'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              foregroundColor: Colors.red,
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Info Section
          const Text(
            'Jak Testować',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoTile(
            '1. Wyłącz WiFi/Dane',
            'Status powinien zmienić się na Offline (pomarańczowy)',
          ),
          _buildInfoTile(
            '2. Kliknij "Testuj Zapis Offline"',
            'Operacja zostanie zapisana w kolejce',
          ),
          _buildInfoTile(
            '3. Włącz WiFi/Dane',
            'Status zmieni się na Online (zielony)',
          ),
          _buildInfoTile(
            '4. Kliknij "Synchronizuj Teraz"',
            'Wszystkie oczekujące operacje zostaną wysłane do serwera',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
