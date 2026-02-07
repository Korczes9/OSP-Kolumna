import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Serwis monitorujący status połączenia internetowego
class SerwisPolaczenia {
  static final Connectivity _connectivity = Connectivity();
  
  /// Sprawdza czy jest dostępne połączenie internetowe
  static Future<bool> czyJestPolaczenie() async {
    try {
      final List<ConnectivityResult> wynik = await _connectivity.checkConnectivity();
      final maPolaczenie = wynik.contains(ConnectivityResult.mobile) ||
          wynik.contains(ConnectivityResult.wifi) ||
          wynik.contains(ConnectivityResult.ethernet);
      
      debugPrint('Status połączenia: ${maPolaczenie ? "Online" : "Offline"}');
      return maPolaczenie;
    } catch (e) {
      debugPrint('Błąd sprawdzania połączenia: $e');
      return false;
    }
  }
  
  /// Stream monitorujący zmiany połączenia
  static Stream<List<ConnectivityResult>> monitorujPolaczenie() {
    return _connectivity.onConnectivityChanged;
  }
  
  /// Sprawdza czy urządzenie jest online
  static Future<bool> czyOnline() async {
    return await czyJestPolaczenie();
  }
}
