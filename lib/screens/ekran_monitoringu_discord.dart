import 'package:flutter/material.dart';
import '../services/serwis_monitoringu_discord.dart';

/// Ekran zarządzania monitoringiem Discord
class EkranMonitoringuDiscord extends StatefulWidget {
  const EkranMonitoringuDiscord({super.key});

  @override
  State<EkranMonitoringuDiscord> createState() => _EkranMonitoringuDiscordState();
}

class _EkranMonitoringuDiscordState extends State<EkranMonitoringuDiscord> {
  final _serwis = SerwisMonitoringuDiscord();
  bool _ladowanie = false;
  int _interwalSprawdzania = 1;

  @override
  void initState() {
    super.initState();
    _wczytajInterwal();
  }

  Future<void> _wczytajInterwal() async {
    final interwal = await _serwis.pobierzInterwalSprawdzania();
    setState(() => _interwalSprawdzania = interwal);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Powiadomienia Discord'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      const Text(
                        'Monitoring Discord',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'System automatycznie sprawdza nowe wiadomości na Discord '
                    'co $_interwalSprawdzania ${_interwalSprawdzania == 1 ? "sekundę" : _interwalSprawdzania < 5 ? "sekundy" : "sekund"} i wysyła powiadomienia push do wszystkich '
                    'użytkowników aplikacji.\n\n'
                    'Możesz zmienić częstotliwość sprawdzania poniżej.',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Akcje',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          Card(
            child: ListTile(
              leading: Icon(Icons.refresh, color: Colors.orange[700]),
              title: const Text('Wymuszenie sprawdzenia'),
              subtitle: const Text('Sprawdź nowe wiadomości teraz'),
              trailing: _ladowanie
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _ladowanie ? null : () async {
                setState(() => _ladowanie = true);
                try {
                  _serwis.stopMonitoring();
                  await _serwis.startMonitoring();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sprawdzono nowe wiadomości'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Błąd: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _ladowanie = false);
                }
              },
            ),
          ),

          Card(
            child: ListTile(
              leading: Icon(Icons.restart_alt, color: Colors.blue[700]),
              title: const Text('Resetuj monitoring'),
              subtitle: const Text('Wyczyść historię i rozpocznij od nowa'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                final potwierdz = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Resetuj monitoring?'),
                    content: const Text(
                      'Spowoduje to wyczyszczenie historii sprawdzonych wiadomości. '
                      'Następne sprawdzenie potraktuje wszystkie wiadomości jako nowe.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Anuluj'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Resetuj'),
                      ),
                    ],
                  ),
                );

                if (potwierdz == true) {
                  await _serwis.resetujMonitoring();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Monitoring zresetowany'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
            ),
          ),

          const SizedBox(height: 16),

          // Konfiguracja interwału sprawdzania
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.timer, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      const Text(
                        'Częstotliwość sprawdzania',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Co $_interwalSprawdzania ${_interwalSprawdzania == 1 ? "sekundę" : _interwalSprawdzania < 5 ? "sekundy" : "sekund"}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Niższa wartość = szybsza reakcja, ale większe zużycie baterii',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final nowyInterwal = await showDialog<int>(
                            context: context,
                            builder: (context) => _DialogWyboruInterwalu(
                              aktualnyInterwal: _interwalSprawdzania,
                            ),
                          );
                          
                          if (nowyInterwal != null && nowyInterwal != _interwalSprawdzania) {
                            try {
                              await _serwis.ustawInterwalSprawdzania(nowyInterwal);
                              setState(() => _interwalSprawdzania = nowyInterwal);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Interwał zmieniony na $nowyInterwal ${nowyInterwal == 1 ? "sekundę" : nowyInterwal < 5 ? "sekundy" : "sekund"}'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Błąd: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Zmień'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          const Text(
            'Jak to działa?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '1. System sprawdza kanał Discord według ustawionej częstotliwości\n'
            '2. Porównuje z ostatnio sprawdzoną wiadomością\n'
            '3. Jeśli znajdzie nową - wysyła powiadomienie push\n'
            '4. Wszyscy użytkownicy dostają powiadomienie\n'
            '5. Można kliknąć powiadomienie aby otworzyć aplikację',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// Dialog wyboru interwału sprawdzania
class _DialogWyboruInterwalu extends StatefulWidget {
  final int aktualnyInterwal;

  const _DialogWyboruInterwalu({required this.aktualnyInterwal});

  @override
  State<_DialogWyboruInterwalu> createState() => _DialogWyboruInterwaluState();
}

class _DialogWyboruInterwaluState extends State<_DialogWyboruInterwalu> {
  late int _wybranyInterwal;

  // Predefiniowane opcje
  final List<Map<String, dynamic>> _opcje = [
    {'wartosc': 1, 'nazwa': '1 sekunda', 'opis': 'Najszybsza reakcja (najwięcej baterii)'},
    {'wartosc': 5, 'nazwa': '5 sekund', 'opis': 'Bardzo szybka reakcja'},
    {'wartosc': 10, 'nazwa': '10 sekund', 'opis': 'Szybka reakcja'},
    {'wartosc': 30, 'nazwa': '30 sekund', 'opis': 'Zbalansowane (zalecane)'},
    {'wartosc': 60, 'nazwa': '1 minuta', 'opis': 'Oszczędzanie baterii'},
    {'wartosc': 120, 'nazwa': '2 minuty', 'opis': 'Maksymalne oszczędzanie'},
  ];

  @override
  void initState() {
    super.initState();
    _wybranyInterwal = widget.aktualnyInterwal;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Częstotliwość sprawdzania'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _opcje.length,
          itemBuilder: (context, index) {
            final opcja = _opcje[index];
            final wartosc = opcja['wartosc'] as int;
            final nazwa = opcja['nazwa'] as String;
            final opis = opcja['opis'] as String;

            return RadioListTile<int>(
              title: Text(nazwa),
              subtitle: Text(opis, style: const TextStyle(fontSize: 12)),
              value: wartosc,
              groupValue: _wybranyInterwal,
              onChanged: (value) {
                setState(() => _wybranyInterwal = value!);
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _wybranyInterwal),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[700],
            foregroundColor: Colors.white,
          ),
          child: const Text('Zastosuj'),
        ),
      ],
    );
  }
}
