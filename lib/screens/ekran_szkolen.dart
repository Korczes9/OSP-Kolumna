import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/szkolenie.dart';
import '../models/strazak.dart';

/// Ekran zarządzania szkoleniami
class EkranSzkolen extends StatefulWidget {
  final Strazak aktualnyStrazak;

  const EkranSzkolen({super.key, required this.aktualnyStrazak});

  @override
  State<EkranSzkolen> createState() => _EkranSzkolenState();
}

class _EkranSzkolenState extends State<EkranSzkolen> {
  final _firestore = FirebaseFirestore.instance;
  String? _wybranyStrazakId;
  TypSzkolenia? _wybranyTyp;
  final RegExp _regexDowodca = RegExp(r'dow[oó]dc', caseSensitive: false);

  Future<DateTime?> _wybierzDate(DateTime? poczatkowa) async {
    final teraz = DateTime.now();
    final start = DateTime(2000, 1, 1);
    final initial = poczatkowa ?? teraz;

    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: start,
      lastDate: DateTime(teraz.year + 10),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Szkolenia'),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _pokazFiltry,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _pobierzSzkolenia(),
        initialData: null,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Błąd: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final szkolenia = snapshot.data!.docs
              .map((doc) =>
                  Szkolenie.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();

          if (szkolenia.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Brak szkoleń',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          // Grupowanie szkoleń
          final wazne = szkolenia.where((s) => s.jestWazny).toList();
          final wygasajace =
              szkolenia.where((s) => s.wymagaOdnowienia).toList();
          final przeterminowane = szkolenia.where((s) => !s.jestWazny).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Podsumowanie
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Ważne',
                      wazne.length.toString(),
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryCard(
                      'Wygasające',
                      wygasajace.length.toString(),
                      Icons.warning,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryCard(
                      'Przeterminowane',
                      przeterminowane.length.toString(),
                      Icons.error,
                      Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Lista wygasających (priorytet)
              if (wygasajace.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      'Wymagają odnowienia (${wygasajace.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...wygasajace.map((s) => _buildSzkolenieCard(s, Colors.orange)),
                const SizedBox(height: 24),
              ],

              // Lista przeterminowanych
              if (przeterminowane.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      'Przeterminowane (${przeterminowane.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...przeterminowane
                    .map((s) => _buildSzkolenieCard(s, Colors.red)),
                const SizedBox(height: 24),
              ],

              // Lista ważnych
              if (wazne.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Aktualne (${wazne.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...wazne.map((s) => _buildSzkolenieCard(s, Colors.green)),
              ],
            ],
          );
        },
      ),
      floatingActionButton: widget.aktualnyStrazak.jestModeratorem
          ? FloatingActionButton(
              onPressed: _dodajSzkolenie,
              backgroundColor: Colors.indigo[700],
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildSummaryCard(
      String label, String wartosc, IconData ikona, Color kolor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(ikona, color: kolor, size: 32),
            const SizedBox(height: 4),
            Text(
              wartosc,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: kolor,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSzkolenieCard(Szkolenie szkolenie, Color akcentColor) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('strazacy').doc(szkolenie.strazakId).get(),
      builder: (context, snapshot) {
        final strazak = snapshot.hasData
            ? Strazak.fromMap(
                snapshot.data!.data() as Map<String, dynamic>,
                snapshot.data!.id,
              )
            : null;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: akcentColor,
              child: Icon(
                _ikonaTypu(szkolenie.typ),
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              szkolenie.nazwa,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (strazak != null) Text(strazak.pelneImie),
                Text('Typ: ${szkolenie.typ.nazwa}'),
                Text('Odbyto: ${_formatujDate(szkolenie.dataOdbycia)}'),
                if (szkolenie.dataWaznosci != null) ...[
                  Text(
                    'Ważne do: ${_formatujDate(szkolenie.dataWaznosci!)}',
                    style: TextStyle(
                      color: akcentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (szkolenie.dniDoWygasniecia != null)
                    Text(
                      '${szkolenie.dniDoWygasniecia} dni',
                      style: TextStyle(fontSize: 12, color: akcentColor),
                    ),
                ],
                if (szkolenie.numerCertyfikatu != null)
                  Text('Certyfikat: ${szkolenie.numerCertyfikatu}'),
              ],
            ),
            trailing: widget.aktualnyStrazak.jestModeratorem
                ? PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _edytujSzkolenie(szkolenie);
                      } else if (value == 'delete') {
                        _usunSzkolenie(szkolenie.id);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, color: Colors.indigo),
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
        );
      },
    );
  }

  IconData _ikonaTypu(TypSzkolenia typ) {
    switch (typ) {
      case TypSzkolenia.podstawowe:
        return Icons.school;
      case TypSzkolenia.specjalistyczne:
        return Icons.stars;
      case TypSzkolenia.kierowca:
        return Icons.local_shipping;
      case TypSzkolenia.ratownictwo:
        return Icons.health_and_safety;
      case TypSzkolenia.medyczne:
        return Icons.medical_services;
      case TypSzkolenia.techniczne:
        return Icons.build;
      case TypSzkolenia.inne:
        return Icons.more_horiz;
    }
  }

  Stream<QuerySnapshot> _pobierzSzkolenia() {
    Query query = _firestore.collection('szkolenia');

    if (_wybranyStrazakId != null) {
      query = query.where('strazakId', isEqualTo: _wybranyStrazakId);
    }

    if (_wybranyTyp != null) {
      query = query.where('typ', isEqualTo: _wybranyTyp!.name);
    }

    return query.orderBy('dataOdbycia', descending: true).snapshots();
  }

  void _pokazFiltry() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Filtr po strażaku będzie dostępny po wybraniu z listy
            const Text('Wybierz typ szkolenia:'),
            const SizedBox(height: 8),
            ...TypSzkolenia.values.map((typ) {
              return RadioListTile<TypSzkolenia?>(
                title: Text(typ.nazwa),
                value: typ,
                groupValue: _wybranyTyp,
                onChanged: (value) {
                  setState(() => _wybranyTyp = value);
                  Navigator.pop(context);
                },
              );
            }),
            RadioListTile<TypSzkolenia?>(
              title: const Text('Wszystkie'),
              value: null,
              groupValue: _wybranyTyp,
              onChanged: (value) {
                setState(() => _wybranyTyp = null);
                Navigator.pop(context);
              },
            ),
          ],
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

  Future<void> _dodajSzkolenie() async {
    final wynik = await _pokazFormularzSzkolenia();
    if (wynik == null) return;

    final szkolenie = Szkolenie(
      id: '',
      strazakId: wynik.strazakId,
      nazwa: wynik.nazwa,
      typ: wynik.typ,
      dataOdbycia: wynik.dataOdbycia,
      dataWaznosci: wynik.dataWaznosci,
      numerCertyfikatu: wynik.numerCertyfikatu,
      instytucja: wynik.instytucja,
      uwagi: wynik.uwagi,
    );

    await _firestore.collection('szkolenia').add(szkolenie.toMap());

    await _oznaczDowodcePoSzkoleniu(wynik.nazwa, wynik.strazakId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Szkolenie dodane'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _edytujSzkolenie(Szkolenie szkolenie) async {
    final wynik = await _pokazFormularzSzkolenia(szkolenie: szkolenie);
    if (wynik == null) return;

    final zaktualizowane = Szkolenie(
      id: szkolenie.id,
      strazakId: wynik.strazakId,
      nazwa: wynik.nazwa,
      typ: wynik.typ,
      dataOdbycia: wynik.dataOdbycia,
      dataWaznosci: wynik.dataWaznosci,
      numerCertyfikatu: wynik.numerCertyfikatu,
      instytucja: wynik.instytucja,
      uwagi: wynik.uwagi,
    );

    await _firestore
        .collection('szkolenia')
        .doc(szkolenie.id)
        .update(zaktualizowane.toMap());

    await _oznaczDowodcePoSzkoleniu(wynik.nazwa, wynik.strazakId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Szkolenie zaktualizowane'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<_SzkolenieFormData?> _pokazFormularzSzkolenia({
    Szkolenie? szkolenie,
  }) async {
    final formKey = GlobalKey<FormState>();
    final nazwaController = TextEditingController(text: szkolenie?.nazwa ?? '');
    final numerCertyfikatuController =
        TextEditingController(text: szkolenie?.numerCertyfikatu ?? '');
    final instytucjaController =
        TextEditingController(text: szkolenie?.instytucja ?? '');
    final uwagiController = TextEditingController(text: szkolenie?.uwagi ?? '');

    String? strazakId = szkolenie?.strazakId;
    TypSzkolenia typ = szkolenie?.typ ?? TypSzkolenia.podstawowe;
    DateTime? dataOdbycia = szkolenie?.dataOdbycia;
    DateTime? dataWaznosci = szkolenie?.dataWaznosci;
    bool bezterminowe = dataWaznosci == null;

    final wynik = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title:
              Text(szkolenie == null ? 'Dodaj szkolenie' : 'Edytuj szkolenie'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FutureBuilder<QuerySnapshot>(
                      future: _firestore
                          .collection('strazacy')
                          .where('aktywny', isEqualTo: true)
                          .get(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: LinearProgressIndicator(),
                          );
                        }

                        final strazacy = snapshot.data!.docs
                            .map((doc) => Strazak.fromMap(
                                  doc.data() as Map<String, dynamic>,
                                  doc.id,
                                ))
                            .toList();

                        return DropdownButtonFormField<String>(
                          value: strazakId,
                          decoration: const InputDecoration(
                            labelText: 'Strażak',
                          ),
                          items: strazacy
                              .map((s) => DropdownMenuItem(
                                    value: s.id,
                                    child: Text(s.pelneImie),
                                  ))
                              .toList(),
                          onChanged: (value) => setStateDialog(() {
                            strazakId = value;
                          }),
                          validator: (value) =>
                              value == null ? 'Wybierz strażaka' : null,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nazwaController,
                      decoration: const InputDecoration(
                        labelText: 'Nazwa szkolenia',
                      ),
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Podaj nazwę'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<TypSzkolenia>(
                      value: typ,
                      decoration: const InputDecoration(
                        labelText: 'Typ szkolenia',
                      ),
                      items: TypSzkolenia.values
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t.nazwa),
                              ))
                          .toList(),
                      onChanged: (value) => setStateDialog(() {
                        if (value != null) {
                          typ = value;
                        }
                      }),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        dataOdbycia == null
                            ? 'Data odbycia'
                            : 'Odbyto: ${_formatujDate(dataOdbycia!)}',
                      ),
                      trailing: const Icon(Icons.date_range),
                      onTap: () async {
                        final wybrana = await _wybierzDate(dataOdbycia);
                        if (wybrana != null) {
                          setStateDialog(() {
                            dataOdbycia = wybrana;
                          });
                        }
                      },
                    ),
                    if (dataOdbycia == null)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Wybierz datę odbycia',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: bezterminowe,
                      title: const Text('Bezterminowe'),
                      onChanged: (value) => setStateDialog(() {
                        bezterminowe = value;
                        if (bezterminowe) {
                          dataWaznosci = null;
                        }
                      }),
                    ),
                    if (!bezterminowe) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          dataWaznosci == null
                              ? 'Data ważności'
                              : 'Ważne do: ${_formatujDate(dataWaznosci!)}',
                        ),
                        trailing: const Icon(Icons.event_available),
                        onTap: () async {
                          final wybrana = await _wybierzDate(dataWaznosci);
                          if (wybrana != null) {
                            setStateDialog(() {
                              dataWaznosci = wybrana;
                            });
                          }
                        },
                      ),
                      if (dataWaznosci == null)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Wybierz datę ważności',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                    ],
                    TextFormField(
                      controller: numerCertyfikatuController,
                      decoration: const InputDecoration(
                        labelText: 'Numer certyfikatu (opcjonalnie)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: instytucjaController,
                      decoration: const InputDecoration(
                        labelText: 'Instytucja (opcjonalnie)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: uwagiController,
                      decoration: const InputDecoration(
                        labelText: 'Uwagi (opcjonalnie)',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Anuluj'),
            ),
            ElevatedButton(
              onPressed: () {
                final valid = formKey.currentState?.validate() ?? false;
                if (!valid || dataOdbycia == null) {
                  return;
                }
                if (!bezterminowe && dataWaznosci == null) {
                  return;
                }
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo[700],
                foregroundColor: Colors.white,
              ),
              child: const Text('Zapisz'),
            ),
          ],
        ),
      ),
    );

    if (wynik != true || strazakId == null || dataOdbycia == null) {
      nazwaController.dispose();
      numerCertyfikatuController.dispose();
      instytucjaController.dispose();
      uwagiController.dispose();
      return null;
    }

    final data = _SzkolenieFormData(
      strazakId: strazakId!,
      nazwa: nazwaController.text.trim(),
      typ: typ,
      dataOdbycia: dataOdbycia!,
      dataWaznosci: dataWaznosci,
      numerCertyfikatu: numerCertyfikatuController.text.trim().isEmpty
          ? null
          : numerCertyfikatuController.text.trim(),
      instytucja: instytucjaController.text.trim().isEmpty
          ? null
          : instytucjaController.text.trim(),
      uwagi: uwagiController.text.trim().isEmpty
          ? null
          : uwagiController.text.trim(),
    );

    nazwaController.dispose();
    numerCertyfikatuController.dispose();
    instytucjaController.dispose();
    uwagiController.dispose();

    return data;
  }

  Future<void> _oznaczDowodcePoSzkoleniu(
      String nazwaSzkolenia, String strazakId) async {
    if (!_regexDowodca.hasMatch(nazwaSzkolenia)) return;

    final doc = await _firestore.collection('strazacy').doc(strazakId).get();
    final data = doc.data() ?? {};
    final role =
        (data['role'] as List<dynamic>?)?.map((r) => r.toString()).toList() ??
            <String>[];

    if (role.isEmpty && data['rola'] != null) {
      role.add(data['rola'].toString());
    }

    if (!role.contains(RolaStrazaka.dowodca.name)) {
      role.add(RolaStrazaka.dowodca.name);
      await _firestore.collection('strazacy').doc(strazakId).update({
        'role': role,
      });
    }
  }

  Future<void> _usunSzkolenie(String id) async {
    final potwierdz = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potwierdzenie'),
        content: const Text('Czy na pewno chcesz usunąć to szkolenie?'),
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
      await _firestore.collection('szkolenia').doc(id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Szkolenie usunięte'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  String _formatujDate(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}.${data.month.toString().padLeft(2, '0')}.${data.year}';
  }
}

class _SzkolenieFormData {
  final String strazakId;
  final String nazwa;
  final TypSzkolenia typ;
  final DateTime dataOdbycia;
  final DateTime? dataWaznosci;
  final String? numerCertyfikatu;
  final String? instytucja;
  final String? uwagi;

  _SzkolenieFormData({
    required this.strazakId,
    required this.nazwa,
    required this.typ,
    required this.dataOdbycia,
    required this.dataWaznosci,
    required this.numerCertyfikatu,
    required this.instytucja,
    required this.uwagi,
  });
}
