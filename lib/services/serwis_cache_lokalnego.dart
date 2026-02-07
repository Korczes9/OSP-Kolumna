import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

/// Serwis do zarządzania lokalnym cache przy użyciu Hive
class SerwisCacheLokalne {
  static const String _boxName = 'offline_cache';
  static const String _respondersKey = 'responders';
  static const String _vehiclesKey = 'vehicles';
  
  /// Inicjalizuje box Hive
  static Future<void> init() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        await Hive.openBox(_boxName);
      }
      debugPrint('✓ Cache lokalny zainicjalizowany');
    } catch (e) {
      debugPrint('❌ Błąd inicjalizacji cache: $e');
    }
  }
  
  /// Zapisuje odpowiadających w lokalnym cache
  static Future<void> zapiszOdpowiadajacych(List<Map<String, dynamic>> dane) async {
    try {
      final box = await Hive.openBox(_boxName);
      await box.put(_respondersKey, dane);
      debugPrint('✓ Zapisano ${dane.length} odpowiadających offline');
    } catch (e) {
      debugPrint('❌ Błąd zapisu odpowiadających: $e');
    }
  }
  
  /// Pobiera odpowiadających z lokalnego cache
  static Future<List<Map<String, dynamic>>> pobierzOdpowiadajacych() async {
    try {
      final box = await Hive.openBox(_boxName);
      final dane = box.get(_respondersKey, defaultValue: []);
      if (dane is List) {
        return dane.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('❌ Błąd odczytu odpowiadających: $e');
      return [];
    }
  }
  
  /// Zapisuje załogę pojazdu w lokalnym cache
  static Future<void> zapiszZalogeWozu(String nazwaWozu, List<Map<String, dynamic>> dane) async {
    try {
      final box = await Hive.openBox(_boxName);
      final klucz = '${_vehiclesKey}_$nazwaWozu';
      await box.put(klucz, dane);
      debugPrint('✓ Zapisano załogę wozu $nazwaWozu offline');
    } catch (e) {
      debugPrint('❌ Błąd zapisu załogi: $e');
    }
  }
  
  /// Pobiera załogę pojazdu z lokalnego cache
  static Future<List<Map<String, dynamic>>> pobierzZalogeWozu(String nazwaWozu) async {
    try {
      final box = await Hive.openBox(_boxName);
      final klucz = '${_vehiclesKey}_$nazwaWozu';
      final dane = box.get(klucz, defaultValue: []);
      if (dane is List) {
        return dane.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('❌ Błąd odczytu załogi: $e');
      return [];
    }
  }
  
  /// Zapisuje status użytkownika offline (do synchronizacji później)
  static Future<void> zapiszOperacjeOffline(Map<String, dynamic> operacja) async {
    try {
      final box = await Hive.openBox(_boxName);
      List<dynamic> kolejka = box.get('pending_operations', defaultValue: []);
      kolejka.add(operacja);
      await box.put('pending_operations', kolejka);
      debugPrint('✓ Zapisano operację offline do kolejki');
    } catch (e) {
      debugPrint('❌ Błąd zapisu operacji offline: $e');
    }
  }
  
  /// Pobiera oczekujące operacje do synchronizacji
  static Future<List<Map<String, dynamic>>> pobierzOczekujaceOperacje() async {
    try {
      final box = await Hive.openBox(_boxName);
      final dane = box.get('pending_operations', defaultValue: []);
      if (dane is List) {
        return dane.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('❌ Błąd odczytu operacji: $e');
      return [];
    }
  }
  
  /// Czyści oczekujące operacje po synchronizacji
  static Future<void> wyczyscOczekujaceOperacje() async {
    try {
      final box = await Hive.openBox(_boxName);
      await box.delete('pending_operations');
      debugPrint('✓ Wyczyszczono kolejkę operacji offline');
    } catch (e) {
      debugPrint('❌ Błąd czyszczenia kolejki: $e');
    }
  }
  
  /// Czyści cały cache
  static Future<void> wyczyscCache() async {
    try {
      final box = await Hive.openBox(_boxName);
      await box.clear();
      debugPrint('✓ Wyczyszczono cache lokalny');
    } catch (e) {
      debugPrint('❌ Błąd czyszczenia cache: $e');
    }
  }
}
