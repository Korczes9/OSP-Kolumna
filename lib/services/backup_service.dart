import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class BackupService {
  static Future<void> backupReports() async {
    final db = FirebaseFirestore.instance;
    final storage = FirebaseStorage.instance;

    final snapshot = await db.collection('reports').get();

    final data = snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        ...doc.data(),
      };
    }).toList();

    final jsonString = jsonEncode({
      'createdAt': DateTime.now().toIso8601String(),
      'reports': data,
    });

    final ref = storage.ref(
      'backups/backup_${DateTime.now().toIso8601String()}.json',
    );

    await ref.putString(jsonString);
  }
}
