import 'package:flutter/material.dart';
import 'alarm_screen.dart';
import 'responders_screen.dart';
import 'vehicle_screen.dart';
import 'report_screen.dart';
import 'reports_history_screen.dart';

class HomeScreen extends StatelessWidget {
	const HomeScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('OSP Kolumna'),
				actions: [
					IconButton(
						icon: const Icon(Icons.exit_to_app),
						onPressed: () => Navigator.pop(context),
					),
				],
			),
			body: ListView(
				padding: const EdgeInsets.all(16),
				children: [
					_buildCard(
						context,
						icon: Icons.warning,
						color: Colors.red,
						title: 'Alarmy',
						subtitle: 'Bieżące alarmy i interwencje',
						onTap: () => Navigator.push(
							context,
							MaterialPageRoute(builder: (_) => const AlarmScreen()),
						),
					),
					_buildCard(
						context,
						icon: Icons.people,
						color: Colors.blue,
						title: 'Jadący strażacy',
						subtitle: 'Lista odpowiadających strażaków',
						onTap: () => Navigator.push(
							context,
							MaterialPageRoute(builder: (_) => const RespondersScreen()),
						),
					),
					_buildCard(
						context,
						icon: Icons.fire_truck,
						color: Colors.orange,
						title: 'Obsada wozu',
						subtitle: 'Przypisz strażaków do pojazdów',
						onTap: () async {
							final vehicle = await showDialog<String>(
								context: context,
								builder: (ctx) => AlertDialog(
									title: const Text('Wybierz wóz'),
									content: Column(
										mainAxisSize: MainAxisSize.min,
										children: ['GBA', 'GCBA', 'SLRT', 'JRK', 'KDA']
												.map((v) => ListTile(
															title: Text(v),
															onTap: () => Navigator.pop(ctx, v),
														))
												.toList(),
									),
								),
							);
							if (vehicle != null && context.mounted) {
								Navigator.push(
									context,
									MaterialPageRoute(
										builder: (_) => VehicleScreen(vehicle: vehicle),
									),
								);
							}
						},
					),
					_buildCard(
						context,
						icon: Icons.description,
						color: Colors.green,
						title: 'Raport interwencji',
						subtitle: 'Utwórz raport z akcji',
						onTap: () => Navigator.push(
							context,
							MaterialPageRoute(
								builder: (_) => const ReportScreen(reportId: 'active'),
							),
						),
					),
					_buildCard(
						context,
						icon: Icons.history,
						color: Colors.purple,
						title: 'Historia raportów',
						subtitle: 'Przeglądaj wcześniejsze raporty',
						onTap: () => Navigator.push(
							context,
							MaterialPageRoute(builder: (_) => const ReportsHistoryScreen()),
						),
					),
				],
			),
		);
	}

	Widget _buildCard(
		BuildContext context, {
		required IconData icon,
		required Color color,
		required String title,
		required String subtitle,
		required VoidCallback onTap,
	}) {
		return Card(
			margin: const EdgeInsets.only(bottom: 12),
			child: ListTile(
				leading: Icon(icon, color: color, size: 40),
				title: Text(
					title,
					style: const TextStyle(
						fontWeight: FontWeight.bold,
						fontSize: 16,
					),
				),
				subtitle: Text(subtitle),
				trailing: const Icon(Icons.arrow_forward_ios),
				onTap: onTap,
			),
		);
	}
}
