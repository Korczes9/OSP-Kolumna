import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/alarm_screen.dart';

void main() {
  runApp(const AplikacjaLogowania());
}

class AplikacjaLogowania extends StatelessWidget {
  const AplikacjaLogowania({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aplikacja Logowania',
      theme: TematDane.lightTheme(),
      home: Stack(
        children: [
          LoginScreen(),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AlarmScreen(),
          ),
        ],
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class TematDane {
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }
}
