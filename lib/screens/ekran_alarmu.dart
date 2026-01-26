import 'package:flutter/material.dart';
import '../services/serwis_nawigacji.dart';
import '../services/serwis_alarmu.dart';
import '../services/report_service.dart';
import 'responders_screen.dart';
import 'dialog_wybor_wozu.dart';

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  String status = 'Brak statusu';

  /// Ustawia nowy status odpowiadającego
  void ustawStatus(String nowyStatus) {
    setState(() {
      status = nowyStatus;
    });
  }

  @override
  void initState() {
    super.initState();
    ReportService.startReport();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red,
        title: const Text('🚨 ALARM'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            /// Typ alarmu
            const Text(
              'Pożar',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            /// Lokalizacja
            const Text('📍 Kolumna, ul. Grzelaczka 12'),
            const SizedBox(height: 8),

            /// Godzina alarmu
            const Text('🕒 14:32'),
            const Divider(height: 32),

            /// Aktualny status
            Text(
              'Twój status: $status',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),

            /// Przycisk - Jadę
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.directions_car),
              label: const Text('JADĘ', style: TextStyle(fontSize: 16)),
              onPressed: () async {
                ustawStatus('JADĘ');
                
                // Zapisz status w Firebase
                await AlarmService.setStatus(
                  userId: 'user_001',
                  name: 'Jerzy Kowalski',
                  status: 'JADĘ',
                );
              },
            ),
            const SizedBox(height: 10),

            /// Przycisk - Dojazd (otwiera mapę z trasą)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.map),
              label: const Text('DOJAZD', style: TextStyle(fontSize: 16)),
              onPressed: () {
                // Koordynaty OSP Kolumna (51.7592°N, 19.4580°E)
                NavigationService.goToLocation(51.7592, 19.4580);
              },
            ),
            const SizedBox(height: 10),

            /// Przycisk - Nie mogę
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.cancel),
              label: const Text('NIE MOGĘ', style: TextStyle(fontSize: 16)),
              onPressed: () async {
                ustawStatus('Nie mogę');
                
                // Zapisz status w Firebase
                await AlarmService.setStatus(
                  userId: 'user_001',
                  name: 'Jerzy Kowalski',
                  status: 'Nie mogę',
                );
              },
            ),
            const SizedBox(height: 10),

            /// Przycisk - Na miejscu
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.check_circle),
              label: const Text('NA MIEJSCU', style: TextStyle(fontSize: 16)),
              onPressed: () async {
                ustawStatus('Na miejscu');
                
                // Zapisz status w Firebase
                await AlarmService.setStatus(
                  userId: 'user_001',
                  name: 'Jerzy Kowalski',
                  status: 'Na miejscu',
                );
              },
            ),
            const SizedBox(height: 20),

            /// Przycisk - Kto jedzie (lista odpowiadających)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.people),
              label: const Text('KTO JEDZIE', style: TextStyle(fontSize: 16)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RespondersScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.fire_truck),
              label: const Text('PRZYPISZ DO WOZU', style: TextStyle(fontSize: 16)),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => DialogWyborWozu(
                    actionType: 'assign',
                    userId: 'user_001',
                    name: 'Jerzy Kowalski',
                  ),
                );
              },
            ),
            const SizedBox(height: 10),

            /// Przycisk - Wyświetl obsadę wozu (wybór dynamiczny)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.list),
              label: const Text('OBSADA WOZU', style: TextStyle(fontSize: 16)),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => DialogWyborWozu(
                    actionType: 'crew',
                    userId: 'user_001',
                    name: 'Jerzy Kowalski',
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            /// Przycisk - Zakończ działania (karta wyjazdu)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              child: const Text('ZAKOŃCZ DZIAŁANIA'),
              onPressed: () async {
                await ReportService.endReport('REPORT_ID'); // tymczasowo ręcznie
              },
            ),
          ],
        ),
      ),
    );
  }
}
