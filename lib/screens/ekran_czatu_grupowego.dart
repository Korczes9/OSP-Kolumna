import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/strazak.dart';
import '../models/wiadomosc_czatu.dart';
import '../screens/galeria_czatu.dart';
import '../services/serwis_powiadomien.dart';
import 'ekran_czatu_grupowego_reactions.dart';

/// Ekran czatu grupowego - widoczny dla wszystkich strażaków
class EkranCzatuGrupowego extends StatefulWidget {
  final Strazak aktualnyStrazak;

  const EkranCzatuGrupowego({super.key, required this.aktualnyStrazak});

  @override
  State<EkranCzatuGrupowego> createState() => _EkranCzatuGropowegoState();
}

class _EkranCzatuGropowegoState extends State<EkranCzatuGrupowego> {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();
  final _trescController = TextEditingController();
  final _scrollController = ScrollController();
  bool _wysylanie = false;
  bool _autoScroll = true; // śledzi, czy użytkownik jest blisko końca listy
  WiadomoscCzatu? _odpowiedzNa;

  // Oznaczenia @użytkownik
  List<String> _wszyscyStrazacy = [];
  List<String> _filtrowaneOznaczenia = [];
  bool _pokazOznaczenia = false;
  // Mapa userId → pełne imię (do podglądu reakcji)
  Map<String, String> _mapIdNazwa = {};

  @override
  void initState() {
    super.initState();
    // Powiadom serwis powiadamien ze jestesmy na ekranie czatu
    SerwisPowiadomien.ustawAktywnyEkran('czat');
    // Anuluj wszelkie powiadomienia czatu – użytkownik właśnie tu wszedł
    SerwisPowiadomien.anulujPowiadomieniaCzatu();
    // Zapisz czas otwarcia czatu jako "ostatnio odczytane"
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt(
        'lastChatRead_${widget.aktualnyStrazak.id}',
        DateTime.now().millisecondsSinceEpoch,
      );
    });
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position.pixels;
      // Z reverse:true, pixels=0 to dół listy
      _autoScroll = pos <= 80;
    });
    _trescController.addListener(_sprawdzOznaczenie);
    _zaladujStrazakow();
  }

  Future<void> _zaladujStrazakow() async {
    try {
      final snap = await _firestore
          .collection('strazacy')
          .where('aktywny', isEqualTo: true)
          .get();
      if (!mounted) return;
      setState(() {
        _wszyscyStrazacy = snap.docs.map((d) {
          final data = d.data();
          // pelneImie jest getterem w modelu Dart - w Firestore są pola imie i nazwisko
          final pelne = (data['pelneImie'] as String?) ?? '';
          if (pelne.isNotEmpty) return pelne;
          final imie = (data['imie'] as String?) ?? '';
          final nazwisko = (data['nazwisko'] as String?) ?? '';
          return '$imie $nazwisko'.trim();
        }).where((n) => n.isNotEmpty && n != widget.aktualnyStrazak.pelneImie)
            .toList()
          ..sort();
        // Buduj mapę id → nazwa
        _mapIdNazwa = {widget.aktualnyStrazak.id: widget.aktualnyStrazak.pelneImie};
        for (final doc in snap.docs) {
          final data = doc.data();
          final pelne = (data['pelneImie'] as String?) ?? '';
          if (pelne.isNotEmpty) {
            _mapIdNazwa[doc.id] = pelne;
          } else {
            final imie = (data['imie'] as String?) ?? '';
            final nazwisko = (data['nazwisko'] as String?) ?? '';
            final name = '$imie $nazwisko'.trim();
            if (name.isNotEmpty) _mapIdNazwa[doc.id] = name;
          }
        }
      });
    } catch (e) {
      debugPrint('Błąd ładowania strażaków do oznaczeń: $e');
    }
  }

  void _sprawdzOznaczenie() {
    final text = _trescController.text;
    final cursor = _trescController.selection.baseOffset;
    if (cursor < 0) {
      if (_pokazOznaczenia) setState(() => _pokazOznaczenia = false);
      return;
    }
    final upToCursor = text.substring(0, cursor);
    final atIdx = upToCursor.lastIndexOf('@');
    if (atIdx == -1) {
      if (_pokazOznaczenia) setState(() => _pokazOznaczenia = false);
      return;
    }
    final fragment = upToCursor.substring(atIdx + 1);
    // Jeśli po @ jest spacja (tzn. już wybraliśmy imię), nie pokazuj listy
    if (fragment.contains('  ')) {
      if (_pokazOznaczenia) setState(() => _pokazOznaczenia = false);
      return;
    }
    final filtered = _wszyscyStrazacy
        .where((n) => n.toLowerCase().contains(fragment.toLowerCase()))
        .toList();
    setState(() {
      _filtrowaneOznaczenia = filtered;
      _pokazOznaczenia = filtered.isNotEmpty;
    });
  }

  void _wstawOznaczenie(String imie) {
    final text = _trescController.text;
    final cursor = _trescController.selection.baseOffset;
    if (cursor < 0) return;
    final upToCursor = text.substring(0, cursor);
    final atIdx = upToCursor.lastIndexOf('@');
    if (atIdx == -1) return;
    final newText =
        '${text.substring(0, atIdx)}@$imie ${text.substring(cursor)}';
    final newCursor = atIdx + imie.length + 2;
    _trescController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
    setState(() => _pokazOznaczenia = false);
  }

  void _pokazZdjeciePelnyEkran(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 64,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _wybierzZdjecie() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked == null) return;
      await _wyslijWiadomosc(imagePath: picked.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nie udało się wczytać zdjęcia: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    // Wyrejestruj ekran czatu
    SerwisPowiadomien.usunAktywnyEkran('czat');
    _trescController.removeListener(_sprawdzOznaczenie);
    _trescController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleReakcja(WiadomoscCzatu wiadomosc, String emoji) async {
    final userId = widget.aktualnyStrazak.id;
    await toggleReakcjaDoFirestore(wiadomosc, emoji, userId);
  }

  void _pokazKtoZareagowalo(String emoji, List<String> userIds) {
    if (userIds.isEmpty) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 8),
                  Text(
                    '${userIds.length}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    'Kto zareagował',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: userIds.map((id) {
                final name = _mapIdNazwa[id] ?? 'Nieznany';
                return ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.blue[700],
                    child: Text(
                      _inicjaly(name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(name),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _wyslijWiadomosc({String? imagePath}) async {
    final tresc = _trescController.text.trim();
    if (tresc.isEmpty && imagePath == null) return;

    setState(() => _wysylanie = true);

    try {
      final docRef = _firestore.collection('czat_grupowy').doc();
      String? imageUrl;

      if (imagePath != null) {
        final file = File(imagePath);
        final ref = _storage.ref().child('czat_zdjecia/${docRef.id}.jpg');
        await ref.putFile(file);
        imageUrl = await ref.getDownloadURL();
      }

      final data = {
        'uzytkownikId': widget.aktualnyStrazak.id,
        'uzytkownikImie': widget.aktualnyStrazak.pelneImie,
        'tresc': tresc,
        'dataNadania': FieldValue.serverTimestamp(),
        'przeczytanePrzez': [widget.aktualnyStrazak.id],
        'przeczytanePrzezInicjaly': [_inicjaly(widget.aktualnyStrazak.pelneImie)],
        if (_odpowiedzNa != null) 'odpowiedzNaId': _odpowiedzNa!.id,
        if (_odpowiedzNa != null) 'odpowiedzNaAutor': _odpowiedzNa!.uzytkownikImie,
        if (_odpowiedzNa != null)
          'odpowiedzNaTresc': _odpowiedzNa!.tresc.isNotEmpty
              ? _odpowiedzNa!.tresc
              : (_odpowiedzNa!.imageUrl != null ? '[Zdjęcie]' : ''),
        if (imageUrl != null) 'imageUrl': imageUrl,
      };

      await docRef.set(data);

      _trescController.clear();
      setState(() => _odpowiedzNa = null);

      // reverse:true → 0 to dół (najnowsze wiadomości)
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
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

  Future<void> _edytujWiadomosc(WiadomoscCzatu wiadomosc) async {
    final controller =
        TextEditingController(text: wiadomosc.tresc);
    final nowa = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edytuj wiadomość'),
        content: TextField(
          controller: controller,
          maxLines: null,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Treść wiadomości...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (nowa == null || nowa.isEmpty || nowa == wiadomosc.tresc) return;
    try {
      await _firestore
          .collection('czat_grupowy')
          .doc(wiadomosc.id)
          .update({'tresc': nowa, 'edytowana': true});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Błąd edycji: $e'),
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
        actions: [
          IconButton(
            tooltip: 'Galeria zdjęć',
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GaleriaCzatu(
                    aktualnyStrazak: widget.aktualnyStrazak,
                  ),
                ),
              );
            },
          ),
        ],
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
                  .orderBy('dataNadania', descending: true)
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

                // Zapamiętaj indeks pierwszej nieprzeczytanej wiadomości (tylko raz przy otwarciu)
                // (przy reverse:true + descending, wiadomości są od najnowszej, szukamy ostatniej nieprzeczytanej)
                // Auto-scroll dla nowych wiadomości (gdy użytkownik jest blisko dołu)
                if (_autoScroll) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!_scrollController.hasClients) return;
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                  });
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
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
                  color: Colors.grey.withValues(alpha: 0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_odpowiedzNa != null) ...[
                    Builder(builder: (context) {
                      final isDarkReply =
                          Theme.of(context).brightness == Brightness.dark;
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDarkReply
                              ? const Color(0xFF1A2E45)
                              : Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDarkReply
                                ? Colors.blue[700]!
                                : Colors.blue[200]!,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.blue[600],
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _odpowiedzNa!.uzytkownikImie,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: isDarkReply
                                          ? Colors.blue[300]
                                          : Colors.blue[800],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _odpowiedzNa!.tresc.isNotEmpty
                                        ? _odpowiedzNa!.tresc
                                        : (_odpowiedzNa!.imageUrl != null
                                            ? '[Zdjęcie]'
                                            : ''),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDarkReply
                                          ? Colors.grey[300]
                                          : Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                size: 18,
                                color: isDarkReply
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                              ),
                              onPressed: () =>
                                  setState(() => _odpowiedzNa = null),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  if (_pokazOznaczenia && _filtrowaneOznaczenia.isNotEmpty)
                    Builder(builder: (ctx) {
                      final isDarkM =
                          Theme.of(ctx).brightness == Brightness.dark;
                      return Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: isDarkM
                              ? const Color(0xFF2A2A2A)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDarkM
                                ? Colors.white12
                                : Colors.grey.shade300,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, -2),
                            ),
                          ],
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _filtrowaneOznaczenia.length,
                          itemBuilder: (_, i) {
                            final name = _filtrowaneOznaczenia[i];
                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _wstawOznaczenie(name),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 15,
                                      backgroundColor: Colors.blue[700],
                                      child: Text(
                                        _inicjaly(name),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '@$name',
                                      style: TextStyle(
                                        color: isDarkM
                                            ? Colors.blue[300]
                                            : Colors.blue[700],
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.image_outlined),
                        tooltip: 'Wyślij zdjęcie',
                        onPressed: _wysylanie ? null : _wybierzZdjecie,
                      ),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWiadomoscCard(WiadomoscCzatu wiadomosc, bool czyMoja,
      {bool oznaczPrzeczytane = true, bool czyNieprzeczytana = false}) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (oznaczPrzeczytane) {
      _oznaczPrzeczytane(wiadomosc);
    }

    final card = GestureDetector(
      onLongPress: () async {
        final selectedEmoji = await showModalBottomSheet<String>(
          context: context,
          builder: (_) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final emoji in ['👍', '❤️', '😂', '😮', '😢', '🔥', '🙏', '🎉'])
                        IconButton(
                          onPressed: () => Navigator.pop(context, emoji),
                          icon: Text(emoji, style: const TextStyle(fontSize: 26)),
                        ),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.reply),
                  title: const Text('Odpowiedz'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _odpowiedzNa = wiadomosc);
                  },
                ),
                if (czyMoja && wiadomosc.tresc.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.edit_outlined, color: Colors.blueGrey),
                    title: const Text('Edytuj'),
                    onTap: () {
                      Navigator.pop(context);
                      _edytujWiadomosc(wiadomosc);
                    },
                  ),
                if (czyMoja || widget.aktualnyStrazak.jestAdministratorem)
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('Usuń'),
                    onTap: () {
                      Navigator.pop(context);
                      _usunWiadomosc(wiadomosc.id);
                    },
                  ),
              ],
            ),
          ),
        );
        if (selectedEmoji != null) {
          _toggleReakcja(wiadomosc, selectedEmoji);
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
              if (wiadomosc.odpowiedzNaId != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wiadomosc.odpowiedzNaAutor ?? 'Odpowiedź',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.blue[200] : Colors.blue[800],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (wiadomosc.odpowiedzNaTresc ?? '').isNotEmpty
                            ? wiadomosc.odpowiedzNaTresc!
                            : '[Zdjęcie]',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.grey[300]
                              : Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
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
              if (wiadomosc.tresc.isNotEmpty) ...[
                _buildTekstZOznaczeniami(
                  wiadomosc.tresc,
                  isDark: isDark,
                ),
                const SizedBox(height: 4),
              ],
              if (wiadomosc.imageUrl != null) ...[
                GestureDetector(
                  onTap: () => _pokazZdjeciePelnyEkran(context, wiadomosc.imageUrl!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      wiadomosc.imageUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return SizedBox(
                          height: 180,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded /
                                      (progress.expectedTotalBytes ?? 1)
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        height: 120,
                        color: Colors.black12,
                        child: const Center(
                          child: Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              const SizedBox(height: 2),
              // Pasek reakcji pod wiadomością
              if (wiadomosc.reakcje.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Wrap(
                    spacing: 4,
                    children: [
                      for (final entry in wiadomosc.reakcje.entries)
                        if (entry.value.isNotEmpty)
                          GestureDetector(
                            onTap: () => _toggleReakcja(wiadomosc, entry.key),
                            onLongPress: () => _pokazKtoZareagowalo(entry.key, entry.value),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: entry.value.contains(widget.aktualnyStrazak.id)
                                    ? (isDark ? Colors.blue[800] : Colors.blue[100])
                                    : (isDark ? Colors.grey[700] : Colors.grey[200]),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: entry.value.contains(widget.aktualnyStrazak.id)
                                      ? (isDark ? Colors.blue[300]! : Colors.blue)
                                      : (isDark ? Colors.grey[500]! : Colors.grey[400]!),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(entry.key, style: const TextStyle(fontSize: 16)),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${entry.value.length}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatter.format(wiadomosc.dataNadania),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (wiadomosc.edytowana) ...[
                    const SizedBox(width: 4),
                    Text(
                      '(edytowano)',
                      style: TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ],
              ),
              if (czyMoja && wiadomosc.przeczytanePrzezInicjaly.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Odczytali: ${wiadomosc.przeczytanePrzezInicjaly.join(', ')}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Align(
      alignment: czyMoja ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: czyNieprzeczytana
            ? BoxDecoration(
                border: Border(
                  left: BorderSide(color: Colors.orange.shade400, width: 3),
                ),
              )
            : null,
        child: _SwipeToReplyCard(
          czyMoja: czyMoja,
          onReply: () => setState(() => _odpowiedzNa = wiadomosc),
          child: card,
        ),
      ),
    );
  }

  Future<void> _oznaczPrzeczytane(WiadomoscCzatu wiadomosc) async {
    final userId = widget.aktualnyStrazak.id;
    if (wiadomosc.przeczytanePrzez.contains(userId)) return;

    final inicjaly = _inicjaly(widget.aktualnyStrazak.pelneImie);
    try {
      await _firestore.collection('czat_grupowy').doc(wiadomosc.id).update({
        'przeczytanePrzez': FieldValue.arrayUnion([userId]),
        'przeczytanePrzezInicjaly': FieldValue.arrayUnion([inicjaly]),
      });
    } catch (e) {
      debugPrint('Nie udało się zapisać odczytu: $e');
    }
  }

  String _inicjaly(String name) {
    final parts = name.trim().split(RegExp(r'\s+')); // imię nazwisko -> IN
    if (parts.isEmpty) return name.isNotEmpty ? name[0].toUpperCase() : '?';
    if (parts.length == 1) {
      return parts.first.isNotEmpty
          ? parts.first.characters.first.toUpperCase()
          : '?';
    }
    final a = parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '';
    final b = parts[1].isNotEmpty ? parts[1][0].toUpperCase() : '';
    return '$a$b';
  }

  /// Renderuje tekst z podświetlonymi oznaczeniami @Imię Nazwisko
  Widget _buildTekstZOznaczeniami(String tekst, {required bool isDark}) {
    // Dopasuj @Imię Nazwisko (litery, spacja, myślnik)
    final regex = RegExp(r'@[\w\sżźćńółęąśŻŹĆŃÓŁĘĄŚ\-]+');
    final spans = <TextSpan>[];
    int ostatni = 0;

    for (final match in regex.allMatches(tekst)) {
      if (match.start > ostatni) {
        spans.add(TextSpan(
          text: tekst.substring(ostatni, match.start),
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ));
      }
      final oznaczony = match.group(0)!;
      final jestStrazakiem = _wszyscyStrazacy.any(
        (n) => '@$n' == oznaczony.trimRight(),
      );
      spans.add(TextSpan(
        text: oznaczony,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: jestStrazakiem
              ? (isDark ? Colors.amber[300] : Colors.blue[800])
              : (isDark ? Colors.white : Colors.black87),
        ),
      ));
      ostatni = match.end;
    }

    if (ostatni < tekst.length) {
      spans.add(TextSpan(
        text: tekst.substring(ostatni),
        style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget obsługujący przesunięcie poziome jako skrót do odpowiedzi
// ─────────────────────────────────────────────────────────────────────────────
class _SwipeToReplyCard extends StatefulWidget {
  final Widget child;
  final bool czyMoja;
  final VoidCallback onReply;

  const _SwipeToReplyCard({
    required this.child,
    required this.czyMoja,
    required this.onReply,
  });

  @override
  State<_SwipeToReplyCard> createState() => _SwipeToReplyCardState();
}

class _SwipeToReplyCardState extends State<_SwipeToReplyCard>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  bool _triggered = false;
  late final AnimationController _snapController;
  late Animation<double> _snapAnimation;

  static const double _threshold = 56;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    // Lewe wiadomości: przesuwamy w prawo (+), prawe: w lewo (-)
    final delta = widget.czyMoja ? -d.delta.dx : d.delta.dx;
    if (delta < 0) return; // ignoruj ruch w złą stronę
    setState(() {
      _dragOffset = (_dragOffset + delta).clamp(0, _threshold * 1.4);
    });
    if (!_triggered && _dragOffset >= _threshold) {
      _triggered = true;
      HapticFeedback.mediumImpact();
    }
  }

  void _onDragEnd(DragEndDetails _) {
    if (_triggered) widget.onReply();
    _triggered = false;
    // Animacja snap-back
    final startOffset = _dragOffset;
    _snapAnimation =
        Tween<double>(begin: startOffset, end: 0).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.elasticOut),
    );
    _snapController.forward(from: 0);
    _snapAnimation.addListener(() {
      if (mounted) setState(() => _dragOffset = _snapAnimation.value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final offset =
        widget.czyMoja ? -_dragOffset : _dragOffset;
    final iconOpacity = (_dragOffset / _threshold).clamp(0.0, 1.0);
    final iconScale = 0.6 + 0.4 * iconOpacity;

    return GestureDetector(
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Ikona odpowiedzi pojawiająca się podczas przeciągania
          Positioned(
            top: 0,
            bottom: 0,
            left: widget.czyMoja ? null : -8,
            right: widget.czyMoja ? -8 : null,
            child: Center(
              child: Opacity(
                opacity: iconOpacity,
                child: Transform.scale(
                  scale: iconScale,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.blue[700],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.reply,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Karta przesuwa się wraz z palcem
          Transform.translate(
            offset: Offset(offset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
