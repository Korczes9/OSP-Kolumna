import 'package:flutter/material.dart';

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
		// ReportService.startReport(); // Wymaga Firebase - odkomentuj po konfiguracji
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
						// ...existing or future widgets...
					],
				),
			),
		);
	}
}
