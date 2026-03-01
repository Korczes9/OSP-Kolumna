import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wydarzenie.dart';
import '../models/strazak.dart';
import '../services/serwis_powiadomien.dart';

/// Ekran terminarza z wydarzeniami
class EkranTerminarza extends StatefulWidget {
  final Strazak aktualnyStrazak;

  const EkranTerminarza({super.key, required this.aktualnyStrazak});

  @override
  State<EkranTerminarza> createState() => _EkranTerminarzaState();
}

class _EkranTerminarzaState extends State<EkranTerminarza> {
  final _firestore = FirebaseFirestore.instance;
  DateTime _wybranyMiesiac = DateTime.now();
  TypWydarzenia? _filtrTypu;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terminarz OSP'),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<TypWydarzenia?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (typ) {
              setState(() => _filtrTypu = typ);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('Wszystkie'),
              ),
              ...TypWydarzenia.values.map((typ) {
                return PopupMenuItem(
                  value: typ,
                  child: Text(typ.nazwa),
                );
              }),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Wybór miesiąca
          Container(
            color: isDark ? Colors.orange[900] : Colors.orange[50],
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _wybranyMiesiac = DateTime(
                        _wybranyMiesiac.year,
                        _wybranyMiesiac.month - 1,
                      );
                    });
                  },
                ),
                Text(
                  _formatujMiesiac(_wybranyMiesiac),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _wybranyMiesiac = DateTime(
                        _wybranyMiesiac.year,
                        _wybranyMiesiac.month + 1,
                      );
                    });
                  },
                ),
              ],
            ),
          ),

          // Lista wydarzeń
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _pobierzWydarzenia(),
              initialData: null,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Błąd: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final wydarzenia = snapshot.data!.docs
                    .map((doc) => Wydarzenie.fromMap(
                          doc.data() as Map<String, dynamic>,
                          doc.id,
                        ))
                    .toList();

                if (wydarzenia.isEmpty) {
                  return const Center(
                    child: Text('Brak wydarzeń w tym miesiącu'),
                  );
                }

                return ListView.builder(
                  itemCount: wydarzenia.length,
                  itemBuilder: (context, index) {
                    return _buildWydarzenieCard(wydarzenia[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: widget.aktualnyStrazak.czyMozeEdytowacKalendarz
          ? FloatingActionButton(
              onPressed: _pokazFormularzDodawania,
              backgroundColor: Colors.orange[700],
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Stream<QuerySnapshot> _pobierzWydarzenia() {
    final poczatekMiesiaca =
        DateTime(_wybranyMiesiac.year, _wybranyMiesiac.month, 1);
    final koniecMiesiaca =
        DateTime(_wybranyMiesiac.year, _wybranyMiesiac.month + 1, 0);

    Query query = _firestore
        .collection('wydarzenia')
        .where('dataRozpoczecia',
            isGreaterThanOrEqualTo: Timestamp.fromDate(poczatekMiesiaca))
        .where('dataRozpoczecia',
            isLessThanOrEqualTo: Timestamp.fromDate(koniecMiesiaca))
        .orderBy('dataRozpoczecia');

    if (_filtrTypu != null) {
      query = query.where('typ', isEqualTo: _filtrTypu!.name);
    }

    // Filtrowanie po stronie klienta dla rezerwacji sali
    return query.snapshots().map((snapshot) {
      final filtrowaneDocs = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final typ = TypWydarzenia.fromString(data['typ'] ?? 'inne');
        
        // Rezerwacja sali widoczna tylko dla gospodarza+
        if (typ == TypWydarzenia.rezerwacjaSali) {
          return widget.aktualnyStrazak.czyMozeRezerwowacSale;
        }
        
        // Pozostałe wydarzenia widoczne dla wszystkich lub według flagi
        final widoczne = data['widoczneDlaWszystkich'] ?? true;
        return widoczne || widget.aktualnyStrazak.jestModeratorem;
      }).toList();

      // Tworzymy nowy QuerySnapshot z przefiltrowanymi dokumentami
      return _FakeQuerySnapshot(filtrowaneDocs);
    });
  }

  Future<void> _pokazListeUczestnikow(Wydarzenie wydarzenie) async {
    // Pobierz dane strażaków
    final strazacySnapshot = await _firestore
        .collection('strazacy')
        .where(FieldPath.documentId, whereIn: wydarzenie.uczestnicyIds)
        .get();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.people, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Uczestnicy: ${wydarzenie.tytul}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: strazacySnapshot.docs.isEmpty
              ? const Text('Brak uczestników')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: strazacySnapshot.docs.length,
                  itemBuilder: (context, index) {
                    final strazak = Strazak.fromMap(
                      strazacySnapshot.docs[index].data(),
                      strazacySnapshot.docs[index].id,
                    );
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange,
                        child: Text(
                          '${strazak.imie[0]}${strazak.nazwisko[0]}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(strazak.pelneImie),
                      subtitle: Text(strazak.numerTelefonu),
                      dense: true,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zamknij'),
          ),
        ],
      ),
    );
  }

  Future<void> _ustawStatusWydarzeniaId(String wydarzenieId, String? status) async {
    try {
      final docRef = _firestore.collection('wydarzenia').doc(wydarzenieId);
      final userId = widget.aktualnyStrazak.id;

      // Najpierw usuń użytkownika ze wszystkich list
      await docRef.update({
        'uczestnicyIds': FieldValue.arrayRemove([userId]),
        'nieBedzieIds': FieldValue.arrayRemove([userId]),
        'jeszczeNieWiemIds': FieldValue.arrayRemove([userId]),
      });

      // Następnie dodaj do wybranej listy (jeśli podano status)
      if (status != null) {
        String komunikat;
        Map<String, dynamic> update = {};

        if (status == 'bedzie') {
          update['uczestnicyIds'] = FieldValue.arrayUnion([userId]);
          komunikat = 'Zaznaczono: będę na wydarzeniu';
        } else if (status == 'nie_bedzie') {
          update['nieBedzieIds'] = FieldValue.arrayUnion([userId]);
          komunikat = 'Zaznaczono: nie będzie mnie';
        } else {
          update['jeszczeNieWiemIds'] = FieldValue.arrayUnion([userId]);
          komunikat = 'Zaznaczono: jeszcze nie wiem';
        }

        await docRef.update(update);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(komunikat),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Wyczyszczono Twój status na wydarzeniu'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Błąd: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildWydarzenieCard(Wydarzenie wydarzenie) {
    final userId = widget.aktualnyStrazak.id;
    final czyJestZapisany = wydarzenie.uczestnicyIds.contains(userId);
    final czyNieBedzie = wydarzenie.nieBedzieIds.contains(userId);
    final czyJeszczeNieWiem = wydarzenie.jeszczeNieWiemIds.contains(userId);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: _kolorTypu(wydarzenie.typ),
              child: Icon(_ikonaTypu(wydarzenie.typ), color: Colors.white),
            ),
            title: Text(
              wydarzenie.tytul,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_formatujDate(wydarzenie.dataRozpoczecia)),
                if (wydarzenie.opis != null)
                  Text(
                    wydarzenie.opis!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (wydarzenie.lokalizacja != null)
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14),
                      const SizedBox(width: 4),
                      Text(wydarzenie.lokalizacja!),
                    ],
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.people, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${wydarzenie.uczestnicyIds.length} osób',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            trailing: widget.aktualnyStrazak.czyMozeEdytowacKalendarz
                ? PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        _usunWydarzenie(wydarzenie.id);
                      } else if (value == 'edit') {
                        _edytujWydarzenie(wydarzenie);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Edytuj'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Usuń'),
                          ],
                        ),
                      ),
                    ],
                  )
                : null,
            isThreeLine: true,
          ),
          // Status obecności i lista uczestników
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.people, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${wydarzenie.uczestnicyIds.length} zapisanych',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const Spacer(),
                    if (wydarzenie.uczestnicyIds.isNotEmpty)
                      IconButton(
                        onPressed: () => _pokazListeUczestnikow(wydarzenie),
                        icon: Badge(
                          label: Text('${wydarzenie.uczestnicyIds.length}'),
                          child: const Icon(Icons.people),
                        ),
                        tooltip: 'Zobacz uczestników',
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Twój status:',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ChoiceChip(
                      label: const Text('Będę'),
                      selected: czyJestZapisany,
                      onSelected: (selected) =>
                          _ustawStatusWydarzeniaId(wydarzenie.id, selected ? 'bedzie' : null),
                      selectedColor: Colors.green,
                      labelStyle: TextStyle(
                        color: czyJestZapisany ? Colors.white : Colors.black,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('Nie będzie mnie'),
                      selected: czyNieBedzie,
                      onSelected: (selected) => _ustawStatusWydarzeniaId(
                          wydarzenie.id, selected ? 'nie_bedzie' : null),
                      selectedColor: Colors.red,
                      labelStyle: TextStyle(
                        color: czyNieBedzie ? Colors.white : Colors.black,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('Jeszcze nie wiem'),
                      selected: czyJeszczeNieWiem,
                      onSelected: (selected) => _ustawStatusWydarzeniaId(
                          wydarzenie.id, selected ? 'nie_wiem' : null),
                      selectedColor: Colors.orange,
                      labelStyle: TextStyle(
                        color:
                            czyJeszczeNieWiem ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _kolorTypu(TypWydarzenia typ) {
    switch (typ) {
      case TypWydarzenia.szkolenie:
        return Colors.blue;
      case TypWydarzenia.cwiczenia:
        return Colors.green;
      case TypWydarzenia.zebranie:
        return Colors.orange;
      case TypWydarzenia.swieto:
        return Colors.red;
      case TypWydarzenia.rezerwacjaSali:
        return Colors.purple;
      case TypWydarzenia.inne:
        return Colors.grey;
    }
  }

  IconData _ikonaTypu(TypWydarzenia typ) {
    switch (typ) {
      case TypWydarzenia.szkolenie:
        return Icons.school;
      case TypWydarzenia.cwiczenia:
        return Icons.fitness_center;
      case TypWydarzenia.zebranie:
        return Icons.groups;
      case TypWydarzenia.swieto:
        return Icons.celebration;
      case TypWydarzenia.rezerwacjaSali:
        return Icons.meeting_room;
      case TypWydarzenia.inne:
        return Icons.event;
    }
  }

  String _formatujMiesiac(DateTime data) {
    const miesiace = [
      'Styczeń',
      'Luty',
      'Marzec',
      'Kwiecień',
      'Maj',
      'Czerwiec',
      'Lipiec',
      'Sierpień',
      'Wrzesień',
      'Październik',
      'Listopad',
      'Grudzień'
    ];
    return '${miesiace[data.month - 1]} ${data.year}';
  }

  String _formatujDate(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}.${data.month.toString().padLeft(2, '0')}.${data.year} ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _usunWydarzenie(String id) async {
    final potwierdz = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potwierdzenie'),
        content: const Text('Czy na pewno chcesz usunąć to wydarzenie?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );

    if (potwierdz == true) {
      await _firestore.collection('wydarzenia').doc(id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wydarzenie usunięte'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _edytujWydarzenie(Wydarzenie wydarzenie) {
    showDialog(
      context: context,
      builder: (context) => _DialogEdytujWydarzenie(
        wydarzenie: wydarzenie,
      ),
    );
  }

  void _pokazFormularzDodawania() {
    showDialog(
      context: context,
      builder: (context) => _DialogDodajWydarzenie(
        strazakId: widget.aktualnyStrazak.id,
      ),
    );
  }
}

/// Dialog dodawania wydarzenia
class _DialogDodajWydarzenie extends StatefulWidget {
  final String strazakId;

  const _DialogDodajWydarzenie({required this.strazakId});

  @override
  State<_DialogDodajWydarzenie> createState() => _DialogDodajWydarzenieState();
}

class _DialogDodajWydarzenieState extends State<_DialogDodajWydarzenie> {
  final _formKey = GlobalKey<FormState>();
  final _tytulController = TextEditingController();
  final _opisController = TextEditingController();
  final _lokalizacjaController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;

  TypWydarzenia _wybranyTyp = TypWydarzenia.inne;
  DateTime _dataRozpoczecia = DateTime.now();
  bool _ladowanie = false;

  @override
  void dispose() {
    _tytulController.dispose();
    _opisController.dispose();
    _lokalizacjaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nowe wydarzenie'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _tytulController,
                decoration: const InputDecoration(
                  labelText: 'Tytuł *',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Wprowadź tytuł' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TypWydarzenia>(
                initialValue: _wybranyTyp,
                decoration: const InputDecoration(
                  labelText: 'Typ wydarzenia',
                  prefixIcon: Icon(Icons.category),
                ),
                items: TypWydarzenia.values.map((typ) {
                  return DropdownMenuItem(
                    value: typ,
                    child: Text(typ.nazwa),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _wybranyTyp = value!);
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Data i godzina'),
                subtitle: Text(_formatujDate(_dataRozpoczecia)),
                onTap: () async {
                  final data = await showDatePicker(
                    context: context,
                    initialDate: _dataRozpoczecia,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );

                  if (data != null && mounted) {
                    final czas = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_dataRozpoczecia),
                    );

                    if (czas != null) {
                      setState(() {
                        _dataRozpoczecia = DateTime(
                          data.year,
                          data.month,
                          data.day,
                          czas.hour,
                          czas.minute,
                        );
                      });
                    }
                  }
                },
              ),
              TextFormField(
                controller: _lokalizacjaController,
                decoration: const InputDecoration(
                  labelText: 'Lokalizacja',
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _opisController,
                decoration: const InputDecoration(
                  labelText: 'Opis',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _ladowanie ? null : () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        ElevatedButton(
          onPressed: _ladowanie ? null : _dodajWydarzenie,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[700],
            foregroundColor: Colors.white,
          ),
          child: _ladowanie
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Dodaj'),
        ),
      ],
    );
  }

  String _formatujDate(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}.${data.month.toString().padLeft(2, '0')}.${data.year} ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _dodajWydarzenie() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _ladowanie = true);

    try {
      // Ustal widoczność - rezerwacja sali tylko dla gospodarza+
      final widoczneDlaWszystkich = _wybranyTyp != TypWydarzenia.rezerwacjaSali;

      final wydarzenie = Wydarzenie(
        id: '',
        tytul: _tytulController.text.trim(),
        opis: _opisController.text.trim().isEmpty
            ? null
            : _opisController.text.trim(),
        dataRozpoczecia: _dataRozpoczecia,
        dataZakonczenia: null,
        typ: _wybranyTyp,
        lokalizacja: _lokalizacjaController.text.trim().isEmpty
            ? null
            : _lokalizacjaController.text.trim(),
        utworzonePrzez: widget.strazakId,
        dataUtworzenia: DateTime.now(),
        uczestnicyIds: [],
        widoczneDlaWszystkich: widoczneDlaWszystkich,
      );

      final docRef = await _firestore.collection('wydarzenia').add(wydarzenie.toMap());

      // Wyślij powiadomienie o nowym wydarzeniu (tylko jeśli widoczne dla wszystkich)
      if (widoczneDlaWszystkich) {
        await SerwisPowiadomien.wyslijPowiadomienieOWydarzeniu(
          wydarzenieId: docRef.id,
          tytul: wydarzenie.tytul,
          typWydarzenia: wydarzenie.typ.nazwa,
          dataRozpoczecia: wydarzenie.dataRozpoczecia,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wydarzenie dodane'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Błąd: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _ladowanie = false);
    }
  }
}

/// Dialog edycji wydarzenia
class _DialogEdytujWydarzenie extends StatefulWidget {
  final Wydarzenie wydarzenie;

  const _DialogEdytujWydarzenie({required this.wydarzenie});

  @override
  State<_DialogEdytujWydarzenie> createState() => _DialogEdytujWydarzenieState();
}

class _DialogEdytujWydarzenieState extends State<_DialogEdytujWydarzenie> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tytulController;
  late final TextEditingController _opisController;
  late final TextEditingController _lokalizacjaController;
  final _firestore = FirebaseFirestore.instance;

  late TypWydarzenia _wybranyTyp;
  late DateTime _dataRozpoczecia;
  bool _ladowanie = false;

  @override
  void initState() {
    super.initState();
    _tytulController = TextEditingController(text: widget.wydarzenie.tytul);
    _opisController = TextEditingController(text: widget.wydarzenie.opis ?? '');
    _lokalizacjaController = TextEditingController(text: widget.wydarzenie.lokalizacja ?? '');
    _wybranyTyp = widget.wydarzenie.typ;
    _dataRozpoczecia = widget.wydarzenie.dataRozpoczecia;
  }

  @override
  void dispose() {
    _tytulController.dispose();
    _opisController.dispose();
    _lokalizacjaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edytuj wydarzenie'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _tytulController,
                decoration: const InputDecoration(
                  labelText: 'Tytuł *',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Wprowadź tytuł' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TypWydarzenia>(
                value: _wybranyTyp,
                decoration: const InputDecoration(
                  labelText: 'Typ wydarzenia',
                  prefixIcon: Icon(Icons.category),
                ),
                items: TypWydarzenia.values.map((typ) {
                  return DropdownMenuItem(
                    value: typ,
                    child: Text(typ.nazwa),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _wybranyTyp = value!);
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Data i godzina'),
                subtitle: Text(_formatujDate(_dataRozpoczecia)),
                onTap: () async {
                  final data = await showDatePicker(
                    context: context,
                    initialDate: _dataRozpoczecia,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );

                  if (data != null && mounted) {
                    final czas = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_dataRozpoczecia),
                    );

                    if (czas != null) {
                      setState(() {
                        _dataRozpoczecia = DateTime(
                          data.year,
                          data.month,
                          data.day,
                          czas.hour,
                          czas.minute,
                        );
                      });
                    }
                  }
                },
              ),
              TextFormField(
                controller: _lokalizacjaController,
                decoration: const InputDecoration(
                  labelText: 'Lokalizacja',
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _opisController,
                decoration: const InputDecoration(
                  labelText: 'Opis',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _ladowanie ? null : () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        ElevatedButton(
          onPressed: _ladowanie ? null : _aktualizujWydarzenie,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[700],
            foregroundColor: Colors.white,
          ),
          child: _ladowanie
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Zapisz'),
        ),
      ],
    );
  }

  String _formatujDate(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}.${data.month.toString().padLeft(2, '0')}.${data.year} ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _aktualizujWydarzenie() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _ladowanie = true);

    try {
      await _firestore.collection('wydarzenia').doc(widget.wydarzenie.id).update({
        'tytul': _tytulController.text.trim(),
        'opis': _opisController.text.trim().isEmpty
            ? null
            : _opisController.text.trim(),
        'dataRozpoczecia': Timestamp.fromDate(_dataRozpoczecia),
        'typ': _wybranyTyp.name,
        'lokalizacja': _lokalizacjaController.text.trim().isEmpty
            ? null
            : _lokalizacjaController.text.trim(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wydarzenie zaktualizowane'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Błąd: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _ladowanie = false);
    }
  }
}

// Klasa pomocnicza do filtrowania QuerySnapshot
class _FakeQuerySnapshot implements QuerySnapshot {
  final List<QueryDocumentSnapshot> _docs;

  _FakeQuerySnapshot(this._docs);

  @override
  List<QueryDocumentSnapshot> get docs => _docs;

  @override
  List<DocumentChange> get docChanges => [];

  @override
  SnapshotMetadata get metadata => throw UnimplementedError();

  @override
  int get size => _docs.length;
}
