import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../models/strazak.dart';
import '../models/zgloszenie_problemu.dart';
import 'package:intl/intl.dart';

/// Ekran zgłaszania problemów w aplikacji
class EkranZglaszaniaProblemow extends StatefulWidget {
  final Strazak aktualnyStrazak;

  const EkranZglaszaniaProblemow({super.key, required this.aktualnyStrazak});

  @override
  State<EkranZglaszaniaProblemow> createState() =>
      _EkranZglaszaniaProblemowState();
}

class _EkranZglaszaniaProblemowState extends State<EkranZglaszaniaProblemow> {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _formKey = GlobalKey<FormState>();
  final _opisController = TextEditingController();
  File? _wybranyObraz;
  bool _wysylanie = false;

  @override
  void dispose() {
    _opisController.dispose();
    super.dispose();
  }

  Future<void> _wybierzObraz() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _wybranyObraz = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd wyboru obrazu: $e')),
        );
      }
    }
  }

  Future<String?> _uploadObraz(String zgloszenieId) async {
    if (_wybranyObraz == null) return null;

    try {
      final fileName =
          'zgloszenia/$zgloszenieId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(fileName);
      await ref.putFile(_wybranyObraz!);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Błąd uploadu obrazu: $e');
      return null;
    }
  }

  Future<void> _wyslijZgloszenie() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _wysylanie = true);

    try {
      // Dodaj zgłoszenie do Firestore
      final docRef = await _firestore.collection('zgloszenia_problemow').add({
        'uzytkownikId': widget.aktualnyStrazak.id,
        'uzytkownikImie': widget.aktualnyStrazak.pelneImie,
        'opis': _opisController.text.trim(),
        'dataZgloszenia': FieldValue.serverTimestamp(),
        'status': 'nowe',
      });

      // Upload obrazu jeśli istnieje
      String? screenshotUrl;
      if (_wybranyObraz != null) {
        screenshotUrl = await _uploadObraz(docRef.id);
        if (screenshotUrl != null) {
          await docRef.update({'screenshotUrl': screenshotUrl});
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Zgłoszenie wysłane pomyślnie'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd wysyłania zgłoszenia: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _wysylanie = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zgłoś problem'),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Lista zgłoszeń
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('zgloszenia_problemow')
                  .orderBy('dataZgloszenia', descending: true)
                  .snapshots(),
              initialData: null,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Błąd: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final zgloszenia = snapshot.data!.docs
                    .map((doc) => ZgloszeniProblemu.fromMap(
                          doc.data() as Map<String, dynamic>,
                          doc.id,
                        ))
                    .toList();

                if (zgloszenia.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bug_report_outlined,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Brak zgłoszeń',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: zgloszenia.length,
                  itemBuilder: (context, index) {
                    final zgloszenie = zgloszenia[index];
                    return _buildZgloszenieCard(zgloszenie);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _pokazDialogNowegoZgloszenia(),
        icon: const Icon(Icons.add),
        label: const Text('Zgłoś problem'),
        backgroundColor: Colors.orange[700],
      ),
    );
  }

  Widget _buildZgloszenieCard(ZgloszeniProblemu zgloszenie) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (zgloszenie.status) {
      case 'rozwiazane':
        statusColor = Colors.green;
        statusText = 'Rozwiązane';
        statusIcon = Icons.check_circle;
        break;
      case 'w_trakcie':
        statusColor = Colors.orange;
        statusText = 'W trakcie';
        statusIcon = Icons.hourglass_empty;
        break;
      default:
        statusColor = Colors.red;
        statusText = 'Nowe';
        statusIcon = Icons.error;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: statusColor.withOpacity(0.2),
              child: Icon(statusIcon, color: statusColor),
            ),
            title: Text(
              zgloszenie.uzytkownikImie,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              DateFormat('dd.MM.yyyy HH:mm').format(zgloszenie.dataZgloszenia),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              zgloszenie.opis,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          if (zgloszenie.screenshotUrl != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  zgloszenie.screenshotUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.broken_image, size: 48),
                      ),
                    );
                  },
                ),
              ),
            ),
          // Przyciski dla administratora
          if (widget.aktualnyStrazak.jestAdministratorem)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (zgloszenie.status != 'w_trakcie')
                    TextButton.icon(
                      onPressed: () => _zmienStatus(zgloszenie.id, 'w_trakcie'),
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: const Text('W trakcie'),
                    ),
                  const SizedBox(width: 8),
                  if (zgloszenie.status != 'rozwiazane')
                    TextButton.icon(
                      onPressed: () =>
                          _zmienStatus(zgloszenie.id, 'rozwiazane'),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Rozwiązane'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.green,
                      ),
                    ),
                  const SizedBox(width: 8),
                  // Przycisk usuwania zgłoszenia
                  TextButton.icon(
                    onPressed: () => _usunZgloszenie(zgloszenie.id, zgloszenie.screenshotUrl),
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Usuń'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _zmienStatus(String zgloszenieId, String nowyStatus) async {
    try {
      await _firestore
          .collection('zgloszenia_problemow')
          .doc(zgloszenieId)
          .update({'status': nowyStatus});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status zmieniony na: $nowyStatus'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd zmiany statusu: $e')),
        );
      }
    }
  }

  Future<void> _usunZgloszenie(String zgloszenieId, String? screenshotUrl) async {
    // Pokaż dialog potwierdzenia
    final potwierdz = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usuń zgłoszenie'),
        content: const Text('Czy na pewno chcesz usunąć to zgłoszenie? Ta operacja jest nieodwracalna.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );

    if (potwierdz != true) return;

    try {
      // Usuń screenshot z Firebase Storage jeśli istnieje
      if (screenshotUrl != null && screenshotUrl.isNotEmpty) {
        try {
          final ref = _storage.refFromURL(screenshotUrl);
          await ref.delete();
        } catch (e) {
          debugPrint('Błąd usuwania obrazu: $e');
          // Kontynuuj mimo błędu usuwania obrazu
        }
      }

      // Usuń dokument z Firestore
      await _firestore
          .collection('zgloszenia_problemow')
          .doc(zgloszenieId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Zgłoszenie zostało usunięte'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Błąd usuwania zgłoszenia: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _pokazDialogNowegoZgloszenia() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nowe zgłoszenie'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _opisController,
                  decoration: const InputDecoration(
                    labelText: 'Opis problemu',
                    hintText: 'Opisz szczegółowo napotkany problem...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Podaj opis problemu';
                    }
                    if (value.trim().length < 10) {
                      return 'Opis musi mieć min. 10 znaków';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Screenshot (opcjonalnie)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (_wybranyObraz != null)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _wybranyObraz!,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                          ),
                          onPressed: () {
                            setState(() => _wybranyObraz = null);
                            Navigator.pop(context);
                            _pokazDialogNowegoZgloszenia();
                          },
                        ),
                      ),
                    ],
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _wybierzObraz();
                      _pokazDialogNowegoZgloszenia();
                    },
                    icon: const Icon(Icons.image),
                    label: const Text('Dodaj screenshot'),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _wybranyObraz = null;
                _opisController.clear();
              });
            },
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: _wysylanie
                ? null
                : () async {
                    Navigator.pop(context);
                    await _wyslijZgloszenie();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
            ),
            child: _wysylanie
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Wyślij'),
          ),
        ],
      ),
    );
  }
}
