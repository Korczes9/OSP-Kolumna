import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
	const HomeScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('OSP Kolumna')),
			body: ListView(
				padding: const EdgeInsets.all(16),
				children: [
					ListTile(
						leading: const Icon(Icons.warning, color: Colors.red),
						title: const Text('Alarms'),
						onTap: () {},
					),
					ListTile(
						leading: const Icon(Icons.chat),
						title: const Text('Unit Chat'),
						onTap: () {},
					),
					ListTile(
						leading: const Icon(Icons.calendar_month),
						title: const Text('Duty & Training'),
						onTap: () {},
					),
				],
			),
		);
	}
}
