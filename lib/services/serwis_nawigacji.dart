import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Serwis obsługujący nawigację do map i otwieranie URL'i
class NavigationService {
  /// Opens Google Maps with route to given location
  static Future<void> goToLocation(double latitude, double longitude) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('✌️ Error opening map: $e');
    }
  }

  /// Opens SMS message to emergency number
  static Future<void> sendSMS(String number) async {
    final uri = Uri(scheme: 'sms', path: number);
    try {
      await launchUrl(uri);
    } catch (e) {
      debugPrint('✌️ Error sending SMS: $e');
    }
  }

  /// Opens phone call
  static Future<void> callNumber(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    try {
      await launchUrl(uri);
    } catch (e) {
      debugPrint('✌️ Error making call: $e');
    }
  }

  /// Opens email message
  static Future<void> sendEmail(String email) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': 'OSP Kolumna Intervention Report',
        'body': 'Report content...'
      },
    );
    try {
      await launchUrl(uri);
    } catch (e) {
      debugPrint('✌️ Error sending email: $e');
    }
  }
}
