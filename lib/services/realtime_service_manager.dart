import 'dart:io';
import 'package:flutter/services.dart';

/// Manager dla natywnego Foreground Service (tylko Android)
class RealtimeServiceManager {
  static const MethodChannel _channel = MethodChannel('pl.ospkolumna.app/realtime_service');
  
  /// Uruchom serwis w tle (Foreground Service)
  static Future<bool> startService() async {
    if (!Platform.isAndroid) {
      print('⚠️ Foreground Service dostępny tylko na Android');
      return false;
    }
    
    try {
      final bool result = await _channel.invokeMethod('startService');
      print('✅ Serwis uruchomiony: $result');
      return result;
    } on PlatformException catch (e) {
      print('❌ Błąd uruchamiania serwisu: ${e.message}');
      return false;
    }
  }
  
  /// Zatrzymaj serwis w tle
  static Future<bool> stopService() async {
    if (!Platform.isAndroid) {
      return false;
    }
    
    try {
      final bool result = await _channel.invokeMethod('stopService');
      print('🛑 Serwis zatrzymany: $result');
      return result;
    } on PlatformException catch (e) {
      print('❌ Błąd zatrzymywania serwisu: ${e.message}');
      return false;
    }
  }
  
  /// Sprawdź czy serwis jest uruchomiony
  static Future<bool> isServiceRunning() async {
    if (!Platform.isAndroid) {
      return false;
    }
    
    try {
      final bool result = await _channel.invokeMethod('isServiceRunning');
      return result;
    } on PlatformException catch (e) {
      print('❌ Błąd sprawdzania statusu serwisu: ${e.message}');
      return false;
    }
  }
}
