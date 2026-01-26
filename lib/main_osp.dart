import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const AplikacjaOSPKolumna());
}

class AplikacjaOSPKolumna extends StatelessWidget {
  const AplikacjaOSPKolumna({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OSP Kolumna',
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      home: const LoginScreen(),
    );
  }
}
