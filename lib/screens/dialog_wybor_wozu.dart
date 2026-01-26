import 'package:flutter/material.dart';
import '../services/serwis_wozu.dart';
import 'vehicle_screen.dart';

/// Dialog do wyboru wozu
class DialogWyborWozu extends StatelessWidget {
  /// Action type: 'assign' or 'crew'
  final String actionType;
  final String userId;
  final String name;

  const DialogWyborWozu({
    super.key,
    required this.actionType,
    this.userId = 'user_001',
    this.name = 'Jerzy Kowalski',
  });

  @override
  Widget build(BuildContext context) {
    final vehicles = SerwisWozu.getVehicles();

    return AlertDialog(
      title: Text(
        actionType == 'assign' ? 'Assign to vehicle' : 'Select vehicle',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: vehicles.length,
          itemBuilder: (context, index) {
            final vehicle = vehicles[index];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.fire_truck, color: Colors.red),
                title: Text(
                  vehicle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                onTap: () async {
                  if (actionType == 'assign') {
                    // Assign to vehicle
                    await SerwisWozu.assignToVehicle(
                      vehicle: vehicle,
                      userId: userId,
                      name: name,
                    );

                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✓ Assigned to vehicle $vehicle'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    // Open vehicle crew screen
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VehicleScreen(vehicle: vehicle),
                      ),
                    );
                  }
                },
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ANULUJ'),
        ),
      ],
    );
  }
}
