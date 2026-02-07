import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/strazak.dart';
import '../models/wiadomosc_czatu.dart';

/// Ekran czatu grupowego - widoczny dla wszystkich strażaków
class EkranCzatuGrupowego extends StatefulWidget {
  final Strazak aktualnyStrazak;

  const EkranCzatuGrupowego({super.key, required this.aktualnyStrazak});

  @override
  State<EkranCzatuGrupowego> createState() => _EkranCzatuGropowegoState();
}

class _EkranCzatuGropowegoState extends State<EkranCzatuGrupowego> {
  final _firestore = FirebaseFirestore.instance;
  final _trescController = TextEditingController();
  final _scrollController = ScrollController();
  bool _wysylanie = false;

  @override
  void dispose() {
    _trescController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _wyslijWiadomosc() async {
    if (_trescController.text.trim().isEmpty) return;

    setState(() => _wysylanie = true);

    try {
      final tresc = _trescController.text.trim();
      await _firestore.collection('czat_grupowy').add({
        'uzytkownikId': widget.aktualnyStrazak.id,
        'uzytkownikImie': widget.aktualnyStrazak.pelneImie,
        'tresc': tresc,
        'dataNadania': FieldValue.serverTimestamp(),
      });

      // Wyślij powiadomienie push (oprócz autora)
      _wyslijPowiadomieniePush(tresc);

      _trescController.clear();
      
      // Przewiń na dół po wysłaniu wiadomości
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Błąd wysyłania wiadomości: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _wysylanie = false);
      }
    }
  }

  Future<void> _usunWiadomosc(String wiadomoscId) async {
    final potwierdz = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usuń wiadomość'),
        content: const Text('Czy na pewno chcesz usunąć tę wiadomość?'),
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
      await _firestore.collection('czat_grupowy').doc(wiadomoscId).delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Błąd usuwania: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Wysyła powiadomienie push do wszystkich strażaków (oprócz autora)
  Future<void> _wyslijPowiadomieniePush(String tresc) async {
    try {
      // Pobierz wszystkich aktywnych strażaków z tokenami FCM
      final strazacySnapshot = await _firestore
          .collection('strazacy')
          .where('aktywny', isEqualTo: true)
          .get();

      final tokens = <String>[];
      for (var doc in strazacySnapshot.docs) {
        // Pomiń autora wiadomości
        if (doc.id == widget.aktualnyStrazak.id) continue;
        
        final data = doc.data();
        final fcmToken = data['fcmToken'] as String?;
        if (fcmToken != null && fcmToken.isNotEmpty) {
          tokens.add(fcmToken);
        }
      }

      if (tokens.isEmpty) {
        debugPrint('⚠️ Brak tokenów FCM - nikt nie dostanie powiadomienia czatu');
        return;
      }

      // Skróć treść dla powiadomienia (max 100 znaków)
      final trescPowiadomienia = tresc.length > 100 
          ? '${tresc.substring(0, 97)}...' 
          : tresc;

      // Dodaj powiadomienie do kolejki (Cloud Function je wyśle)
      await _firestore.collection('powiadomienia').add({
        'tokens': tokens,
        'title': '💬 ${widget.aktualnyStrazak.pelneImie}',
        'body': trescPowiadomienia,
        'data': {
          'type': 'czat',
          'authorId': widget.aktualnyStrazak.id,
          'authorName': widget.aktualnyStrazak.pelneImie,
        },
        'timestamp': FieldValue.serverTimestamp(),
        'wyslane': false,
      });

      debugPrint('✅ Dodano powiadomienie czatu do kolejki dla ${tokens.length} strażaków');
    } catch (e) {
      debugPrint('❌ Błąd wysyłania powiadomienia czatu: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Czat jednostki'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Informacja o czacie
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E3A5F)
                : Colors.blue[50],
            child: Row(
              children: [
                Icon(Icons.chat, color: Colors.blue[700], size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Czat grupowy dla wszystkich strażaków OSP Kolumna',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lista wiadomości
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('czat_grupowy')
                  .orderBy('dataNadania', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Błąd: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final wiadomosci = snapshot.data!.docs
                    .map((doc) => WiadomoscCzatu.fromMap(
                          doc.data() as Map<String, dynamic>,
                          doc.id,
                        ))
                    .toList();

                if (wiadomosci.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Brak wiadomości',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Wyślij pierwszą wiadomość!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Przewiń na dół po załadowaniu wiadomości
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(
                      _scrollController.position.maxScrollExtent,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: wiadomosci.length,
                  itemBuilder: (context, index) {
                    final wiadomosc = wiadomosci[index];
                    final czyMoja = wiadomosc.uzytkownikId == widget.aktualnyStrazak.id;
                    
                    return _buildWiadomoscCard(wiadomosc, czyMoja);
                  },
                );
              },
            ),
          ),

          // Pole wprowadzania wiadomości
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E1E1E)
                  : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _trescController,
                      decoration: InputDecoration(
                        hintText: 'Napisz wiadomość...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _wyslijWiadomosc(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    onPressed: _wysylanie ? null : _wyslijWiadomosc,
                    backgroundColor: Colors.blue[700],
                    mini: true,
                    child: _wysylanie
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWiadomoscCard(WiadomoscCzatu wiadomosc, bool czyMoja) {
    final formatter = DateFormat('HH:mm');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Align(
      alignment: czyMoja ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: GestureDetector(
          onLongPress: () {
            // Pozwól usunąć tylko własne wiadomości lub administratorowi wszystkie
            if (czyMoja || widget.aktualnyStrazak.jestAdministratorem) {
              _usunWiadomosc(wiadomosc.id);
            }
          },
          child: Card(
            color: isDark
                ? (czyMoja ? const Color(0xFF1E3A5F) : const Color(0xFF2A2A2A))
                : (czyMoja ? Colors.blue[100] : Colors.grey[200]),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(czyMoja ? 12 : 0),
                bottomRight: Radius.circular(czyMoja ? 0 : 12),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!czyMoja)
                    Text(
                      wiadomosc.uzytkownikImie,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isDark ? Colors.blue[300] : Colors.blue[900],
                      ),
                    ),
                  if (!czyMoja) const SizedBox(height: 4),
                  Text(
                    wiadomosc.tresc,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatter.format(wiadomosc.dataNadania),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
