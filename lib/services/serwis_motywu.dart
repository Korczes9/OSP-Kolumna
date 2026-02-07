import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serwis do zarządzania motywem aplikacji (jasny/ciemny)
class SerwisMotywu extends ChangeNotifier {
  static const String _klucz = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  SerwisMotywu() {
    _zaladujMotyw();
  }

  /// Ładuje zapisany motyw z SharedPreferences
  Future<void> _zaladujMotyw() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_klucz);
    
    if (saved != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.toString() == saved,
        orElse: () => ThemeMode.system,
      );
      notifyListeners();
    }
  }

  /// Zmienia motyw i zapisuje preferencję
  Future<void> zmienMotyw(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_klucz, mode.toString());
  }

  /// Przełącza między trybem jasnym a ciemnym
  Future<void> przelaczMotyw() async {
    final nowyMotyw = _themeMode == ThemeMode.light 
        ? ThemeMode.dark 
        : ThemeMode.light;
    await zmienMotyw(nowyMotyw);
  }

  /// Sprawdza czy aktualnie jest włączony tryb ciemny
  bool get czyCiemny => _themeMode == ThemeMode.dark;
}
