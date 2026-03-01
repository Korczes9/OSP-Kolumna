import 'package:flutter/material.dart';
import '../services/serwis_powiadomien.dart';

/// Prosty ekran diagnostyki alarmu i powiadomień
class EkranDiagnostykiAlarmu extends StatefulWidget {
  const EkranDiagnostykiAlarmu({super.key});

  @override
  State<EkranDiagnostykiAlarmu> createState() => _EkranDiagnostykiAlarmuState();
}

class _EkranDiagnostykiAlarmuState extends State<EkranDiagnostykiAlarmu> {
  bool _chkPowiadomienia = false;
  bool _chkBateria = false;
  bool _chkOverlay = false;
  bool _chkSerwisCzuwanie = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostyka alarmu'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Checklist – sprawdź po kolei',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Powiadomienia i kanał "Alarmy" włączone'),
                    subtitle: const Text('Ustawienia systemowe → Powiadomienia → OSP Kolumna'),
                    value: _chkPowiadomienia,
                    onChanged: (v) => setState(() => _chkPowiadomienia = v ?? false),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Brak ograniczeń baterii dla aplikacji'),
                    subtitle: const Text('Ustawienia baterii → Brak optymalizacji / Bez ograniczeń'),
                    value: _chkBateria,
                    onChanged: (v) => setState(() => _chkBateria = v ?? false),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Zezwól na "wyświetlanie nad innymi aplikacjami"'),
                    subtitle: const Text('Jeśli telefon ma takie ustawienie dla OSP Kolumna'),
                    value: _chkOverlay,
                    onChanged: (v) => setState(() => _chkOverlay = v ?? false),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Widzisz powiadomienie "OSP Kolumna – czuwanie"'),
                    subtitle: const Text('Serwis w tle działa – nie usuwaj tego powiadomienia'),
                    value: _chkSerwisCzuwanie,
                    onChanged: (v) => setState(() => _chkSerwisCzuwanie = v ?? false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: isDark ? Colors.red[900] : Colors.red[50],
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1. Uprawnienia do powiadomień',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Sprawdź w ustawieniach telefonu, czy aplikacja OSP Kolumna ma włączone powiadomienia.\n'
                    '• W szczególności kanał "Alarmy" powinien mieć priorytet Wysoki/Pilny oraz zezwolenie na wyskakujące okna na ekranie blokady.',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: isDark ? Colors.orange[900] : Colors.orange[50],
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '2. Praca w tle / oszczędzanie baterii',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Wyłącz optymalizację baterii dla aplikacji OSP Kolumna.\n'
                    '• Na wielu telefonach trzeba ręcznie zezwolić na pracę w tle ("bez ograniczeń", "chroniona aplikacja").',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: isDark ? Colors.blue[900] : Colors.blue[50],
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '3. Wyświetlanie nad innymi aplikacjami',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Upewnij się, że aplikacja ma włączone uprawnienie "Wyświetlaj nad innymi aplikacjami" (jeśli telefon takie ma).\n'
                    '• Dzięki temu pełnoekranowy alarm może pojawić się nawet na zablokowanym ekranie.',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Test działania alarmu',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ten test działa tylko gdy aplikacja jest otwarta. Pozwala sprawdzić, czy syrena i ekran alarmu działają poprawnie.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: SerwisPowiadomien.wyslijTestowyAlarm,
                      icon: Icon(Icons.campaign),
                      label: Text('Uruchom testowy alarm'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
