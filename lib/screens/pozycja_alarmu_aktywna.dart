import 'package:flutter/material.dart';
import 'alarm_screen.dart';

class PozyjaAlarmowAktywna extends StatelessWidget {
  const PozyjaAlarmowAktywna({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      /// Ikona alarmu
      leading: const Icon(Icons.warning, color: Colors.red),

      /// Tytuł pozycji
      title: const Text('AKTYWNY ALARM'),

      /// Opis alarmu
      subtitle: const Text('Pożar budynku mieszkalnego'),

      /// Akcja - przejście do ekranu alarmu
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AlarmScreen()),
        );
      },

      /// Strzałka wskazująca dalej
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
    );
  }
}
