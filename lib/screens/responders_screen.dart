import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Screen displaying the list of responders
class RespondersScreen extends StatelessWidget {
	const RespondersScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('Kto jedzie'),
				backgroundColor: Colors.red,
			),
			body: StreamBuilder<QuerySnapshot>(
				stream: FirebaseFirestore.instance
						.collection('alarmy')
						.doc('aktywny')
						.collection('odpowiadajacy')
						.snapshots(),
				builder: (context, snapshot) {
					if (snapshot.connectionState == ConnectionState.waiting) {
						return const Center(
							child: CircularProgressIndicator(),
						);
					}

					if (snapshot.hasError) {
						return Center(
							child: Text('❌ Błąd: {snapshot.error}'),
						);
					}

					if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
						return const Center(
							child: Text(
								'Nikt jeszcze się nie zgłosił',
								style: TextStyle(fontSize: 16, color: Colors.grey),
							),
						);
					}

					final responders = snapshot.data!.docs;

					return ListView.builder(
						padding: const EdgeInsets.all(8),
						itemCount: responders.length,
						itemBuilder: (context, index) {
							final doc = responders[index];
							final data = doc.data() as Map<String, dynamic>;
							final name = data['name'] ?? 'Unknown';
							final status = data['status'] ?? 'Bez statusu';

							Color statusColor = Colors.grey;
							if (status == 'JADĘ') statusColor = Colors.green;
							if (status == 'Nie mogę') statusColor = Colors.red;
							if (status == 'Na miejscu') statusColor = Colors.blue;

							return Card(
								margin: const EdgeInsets.symmetric(vertical: 8),
								child: ListTile(
									leading: const Icon(Icons.person, color: Colors.red),
									title: Text(
										name,
										style: const TextStyle(fontWeight: FontWeight.bold),
									),
									trailing: Container(
										padding: const EdgeInsets.symmetric(
											horizontal: 12,
											vertical: 6,
										),
										decoration: BoxDecoration(
											color: statusColor,
											borderRadius: BorderRadius.circular(20),
										),
										child: Text(
											status,
											style: const TextStyle(
												color: Colors.white,
												fontWeight: FontWeight.bold,
												fontSize: 12,
											),
										),
									),
									subtitle: Text('ID: ${doc.id}'),
								),
							);
						},
					);
				},
			),
		);
	}
}
