import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class VehicleScreen extends StatelessWidget {
	/// Vehicle name (e.g. "GBA", "GCBA")
	final String vehicle;

	const VehicleScreen({
		super.key,
		required this.vehicle,
	});

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: Text('Vehicle crew $vehicle'),
				backgroundColor: Colors.red,
			),
			body: StreamBuilder<QuerySnapshot>(
				stream: FirebaseFirestore.instance
						.collection('alarmy')
						.doc('aktywny')
						.collection('pojazdy')
						.doc(vehicle)
						.collection('crew')
						.snapshots(),
				builder: (context, snapshot) {
					if (snapshot.connectionState == ConnectionState.waiting) {
						return const Center(
							child: CircularProgressIndicator(),
						);
					}
					if (snapshot.hasError) {
						return Center(
							child: Text('❌ Error: ${snapshot.error}'),
						);
					}
					if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
						return Center(
							child: Text(
								'Vehicle $vehicle - no crew',
								style: const TextStyle(fontSize: 16, color: Colors.grey),
							),
						);
					}
					final crew = snapshot.data!.docs;
					return ListView.builder(
						padding: const EdgeInsets.all(8),
						itemCount: crew.length,
						itemBuilder: (context, index) {
							final doc = crew[index];
							final data = doc.data() as Map<String, dynamic>;
							final name = data['name'] ?? 'Unknown';
							return Card(
								margin: const EdgeInsets.symmetric(vertical: 8),
								child: ListTile(
									leading: Container(
										width: 40,
										height: 40,
										decoration: const BoxDecoration(
											color: Colors.red,
											shape: BoxShape.circle,
										),
										child: const Icon(
											Icons.person,
											color: Colors.white,
										),
									),
									title: Text(
										name,
										style: const TextStyle(
											fontWeight: FontWeight.bold,
											fontSize: 16,
										),
									),
									subtitle: Text('ID: ${doc.id}'),
									trailing: IconButton(
										icon: const Icon(Icons.close, color: Colors.red),
										onPressed: () {
											ScaffoldMessenger.of(context).showSnackBar(
												SnackBar(
													content: Text('Removed $name from vehicle $vehicle'),
												),
											);
										},
									),
								),
							);
						},
					);
				},
			),
			floatingActionButton: FloatingActionButton(
				onPressed: () {
					ScaffoldMessenger.of(context).showSnackBar(
						SnackBar(
							content: Text('Add crew to vehicle $vehicle'),
						),
					);
				},
				tooltip: 'Add member',
				child: const Icon(Icons.add),
			),
		);
	}
}
