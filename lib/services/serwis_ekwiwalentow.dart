import 'package:cloud_firestore/cloud_firestore.dart';

class SerwisEkwiwalentow {
  static double stawkaPozarMiejscoweAlarm = 19.0;
  static double stawkaZabezpieczeniePolecenie = 9.0;
  static double stawkaCwiczenia = 6.0;

  static const String _configDocPath = 'config/ekwiwalent';

  static Future<void> init() async {
    try {
      final doc = await FirebaseFirestore.instance.doc(_configDocPath).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        stawkaPozarMiejscoweAlarm =
            (data['stawkaPozarMiejscoweAlarm'] ?? 19).toDouble();
        stawkaZabezpieczeniePolecenie =
            (data['stawkaZabezpieczeniePolecenie'] ?? 9).toDouble();
        stawkaCwiczenia = (data['stawkaCwiczenia'] ?? 6).toDouble();
      } else {
        await _zapisDomyslnychStawek();
      }
    } catch (_) {
      // W razie błędu zostają domyślne wartości
    }
  }

  static Future<void> _zapisDomyslnychStawek() async {
    await FirebaseFirestore.instance.doc(_configDocPath).set({
      'stawkaPozarMiejscoweAlarm': stawkaPozarMiejscoweAlarm,
      'stawkaZabezpieczeniePolecenie': stawkaZabezpieczeniePolecenie,
      'stawkaCwiczenia': stawkaCwiczenia,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> zapiszStawki({
    required double nowaStawkaPozarMiejscoweAlarm,
    required double nowaStawkaZabezpieczeniePolecenie,
    required double nowaStawkaCwiczenia,
  }) async {
    stawkaPozarMiejscoweAlarm = nowaStawkaPozarMiejscoweAlarm;
    stawkaZabezpieczeniePolecenie = nowaStawkaZabezpieczeniePolecenie;
    stawkaCwiczenia = nowaStawkaCwiczenia;

    await FirebaseFirestore.instance.doc(_configDocPath).set({
      'stawkaPozarMiejscoweAlarm': stawkaPozarMiejscoweAlarm,
      'stawkaZabezpieczeniePolecenie': stawkaZabezpieczeniePolecenie,
      'stawkaCwiczenia': stawkaCwiczenia,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
