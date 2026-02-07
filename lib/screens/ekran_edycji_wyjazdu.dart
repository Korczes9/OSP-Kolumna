import 'package:flutter/material.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wyjazd.dart';
import '../models/strazak.dart';
import '../services/serwis_wyjazdow.dart';
import '../services/serwis_autentykacji_nowy.dart';

const String _googleApiKey = 'AIzaSyAqTJGSPMNS5jAquRA6oQlLq8Y6DHOKYK0';

/// Ekran edycji wyjazdu
class EkranEdycjiWyjazdu extends StatefulWidget {
  final Wyjazd wyjazd;
  final Strazak aktualnyStrazak;

  const EkranEdycjiWyjazdu({
    super.key,
    required this.wyjazd,
    required this.aktualnyStrazak,
  });

  @override
  State<EkranEdycjiWyjazdu> createState() => _EkranEdycjiWyjazduState();
}

class _EkranEdycjiWyjazduState extends State<EkranEdycjiWyjazdu> {
  final _formKey = GlobalKey<FormState>();
  final _tytulController = TextEditingController();
  final _opisController = TextEditingController();
  final _lokalizacjaController = TextEditingController();
  final _serwisWyjazdow = SerwisWyjazdow();
  final _authService = AuthService();

  late KategoriaWyjazdu _wybranaKategoria;
  late DateTime _dataWyjazdu;
  DateTime? _godzinaRozpoczecia;
  DateTime? _godzinaZakonczenia;
  bool _ladowanie = false;
  
  // Strażacy i wozy - do edycji
  List<Strazak> _wszyscyStrazacy = [];
  List<String> _wybraniStrazacy = [];
  String? _wybranyWoz;
  String? _wybranyWoz1;
  String? _wybranyWoz2;
  List<String> _woz1Strazacy = [];
  List<String> _woz2Strazacy = [];
  bool _dwieJednostki = false;

  @override
  void initState() {
    super.initState();
    _tytulController.text = widget.wyjazd.lokalizacja;
    _opisController.text = widget.wyjazd.opis;
    _lokalizacjaController.text = widget.wyjazd.lokalizacja;
    _wybranaKategoria = widget.wyjazd.kategoria;
    _dataWyjazdu = widget.wyjazd.dataWyjazdu;
    _godzinaRozpoczecia = widget.wyjazd.godzinaRozpoczecia;
    _godzinaZakonczenia = widget.wyjazd.godzinaZakonczenia;
    
    // Inicjalizacja danych o wozach i strażakach
    _pobierzStrazakow();
    
    // Sprawdź czy są dwie jednostki
    _dwieJednostki = widget.wyjazd.woz1Id != null && widget.wyjazd.woz2Id != null;
    
    if (_dwieJednostki) {
      _wybranyWoz1 = widget.wyjazd.woz1Id;
      _wybranyWoz2 = widget.wyjazd.woz2Id;
      _woz1Strazacy = List.from(widget.wyjazd.woz1StrazacyIds);
      _woz2Strazacy = List.from(widget.wyjazd.woz2StrazacyIds);
    } else {
      _wybranyWoz = widget.wyjazd.wozId;
      _wybraniStrazacy = List.from(widget.wyjazd.strazacyIds);
    }
  }

  Future<void> _pobierzStrazakow() async {
    _authService.pobierzWszystkichStrazakow().listen((strazacy) {
      setState(() {
        _wszyscyStrazacy = strazacy.where((s) => s.aktywny).toList();
      });
    });
  }

  void _wybierzStrazakow() {
    showDialog(
      context: context,
      builder: (context) => _DialogWyboruStrazakow(
        wszyscyStrazacy: _wszyscyStrazacy,
        wybraniStrazacy: _wybraniStrazacy,
        onZmiana: (wybrani) {
          setState(() => _wybraniStrazacy = wybrani);
        },
      ),
    );
  }

  void _wybierzWoz() {
    showDialog(
      context: context,
      builder: (context) => _DialogWyboruWozu(
        wybranyWozId: _wybranyWoz,
        onWybor: (wozId) {
          setState(() => _wybranyWoz = wozId);
        },
      ),
    );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edycja wyjazdu'),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Tytuł
            TextFormField(
              controller: _tytulController,
              decoration: const InputDecoration(
                labelText: 'Tytuł *',
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Wprowadź tytuł' : null,
            ),
            const SizedBox(height: 16),

            // Kategoria
            DropdownButtonFormField<KategoriaWyjazdu>(
              initialValue: _wybranaKategoria,
              decoration: const InputDecoration(
                labelText: 'Kategoria *',
                prefixIcon: Icon(Icons.category),
                border: OutlineInputBorder(),
              ),
              items: KategoriaWyjazdu.values.map((kategoria) {
                return DropdownMenuItem(
                  value: kategoria,
                  child: Text(kategoria.nazwa),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _wybranaKategoria = value!);
              },
            ),
            const SizedBox(height: 16),

            // Data
            InkWell(
              onTap: () async {
                final data = await showDatePicker(
                  context: context,
                  initialDate: _dataWyjazdu,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (data != null) {
                  setState(() => _dataWyjazdu = data);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data wyjazdu',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                child: Text(_formatujDate(_dataWyjazdu)),
              ),
            ),
            const SizedBox(height: 16),

            // Lokalizacja z autocomplete
            GooglePlaceAutoCompleteTextField(
              textEditingController: _lokalizacjaController,
              googleAPIKey: _googleApiKey,
              inputDecoration: const InputDecoration(
                labelText: 'Lokalizacja',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
                helperText: 'Zacznij pisać adres aby zobaczyć sugestie',
              ),
              debounceTime: 600,
              countries: const ['pl'],
              isLatLngRequired: false,
              getPlaceDetailWithLatLng: (Prediction prediction) {
                setState(() {
                  _lokalizacjaController.text = prediction.description ?? '';
                });
              },
              itemClick: (Prediction prediction) {
                setState(() {
                  _lokalizacjaController.text = prediction.description ?? '';
                });
              },
              seperatedBuilder: const Divider(),
              containerHorizontalPadding: 10,
              itemBuilder: (context, index, Prediction prediction) {
                return Container(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          prediction.description ?? '',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                );
              },
              isCrossBtnShown: true,
            ),
            const SizedBox(height: 16),

            // Opis
            TextFormField(
              controller: _opisController,
              decoration: const InputDecoration(
                labelText: 'Opis',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Godziny
            const Text(
              'Czas trwania',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Godzina rozpoczęcia
            Card(
              color: Colors.green[50],
              child: ListTile(
                leading: const Icon(Icons.play_arrow, color: Colors.green),
                title: const Text('Godzina rozpoczęcia'),
                subtitle: Text(_godzinaRozpoczecia != null
                    ? _formatujGodzine(_godzinaRozpoczecia!)
                    : 'Nie ustawiono'),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final czas = await showTimePicker(
                    context: context,
                    initialTime: _godzinaRozpoczecia != null
                        ? TimeOfDay.fromDateTime(_godzinaRozpoczecia!)
                        : TimeOfDay.now(),
                  );
                  if (czas != null) {
                    setState(() {
                      _godzinaRozpoczecia = DateTime(
                        _dataWyjazdu.year,
                        _dataWyjazdu.month,
                        _dataWyjazdu.day,
                        czas.hour,
                        czas.minute,
                      );
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 8),

            // Godzina zakończenia
            Card(
              color: Colors.red[50],
              child: ListTile(
                leading: const Icon(Icons.stop, color: Colors.red),
                title: const Text('Godzina zakończenia'),
                subtitle: Text(_godzinaZakonczenia != null
                    ? _formatujGodzine(_godzinaZakonczenia!)
                    : 'Nie ustawiono'),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final czas = await showTimePicker(
                    context: context,
                    initialTime: _godzinaZakonczenia != null
                        ? TimeOfDay.fromDateTime(_godzinaZakonczenia!)
                        : TimeOfDay.now(),
                  );
                  if (czas != null) {
                    setState(() {
                      _godzinaZakonczenia = DateTime(
                        _dataWyjazdu.year,
                        _dataWyjazdu.month,
                        _dataWyjazdu.day,
                        czas.hour,
                        czas.minute,
                      );
                    });
                  }
                },
              ),
            ),

            // Podsumowanie czasu i ekwiwalentu
            if (_godzinaRozpoczecia != null && _godzinaZakonczenia != null)
              Card(
                color: Colors.blue[50],
                margin: const EdgeInsets.only(top: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Czas trwania:'),
                          Text(
                            '${_obliczCzasTrwania()} min (${_obliczGodzinyZaokraglone()} h)',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Ekwiwalent:'),
                          Text(
                            '${_obliczEkwiwalent()} PLN',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Przełącznik trybu dwóch jednostek
            Card(
              child: SwitchListTile(
                title: const Text('Dwie jednostki'),
                subtitle: const Text('Włącz aby przypisać dwa wozy z osobnymi załogami'),
                value: _dwieJednostki,
                onChanged: (value) {
                  setState(() {
                    _dwieJednostki = value;
                    if (!value) {
                      // Reset wyboru jednostek
                      _wybranyWoz1 = null;
                      _wybranyWoz2 = null;
                      _woz1Strazacy = [];
                      _woz2Strazacy = [];
                    } else {
                      _wybranyWoz = null;
                      _wybraniStrazacy = [];
                    }
                  });
                },
                secondary: const Icon(Icons.fire_truck, color: Colors.orange),
              ),
            ),
            const SizedBox(height: 8),

            // Tryb pojedynczego wozu
            if (!_dwieJednostki) ...[
              // Strażacy
              Card(
                child: ListTile(
                  leading: const Icon(Icons.group, color: Colors.green),
                  title: const Text('Strażacy'),
                  subtitle: Text(
                    _wybraniStrazacy.isEmpty
                        ? 'Nie przypisano'
                        : '${_wybraniStrazacy.length} strażaków',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _wybierzStrazakow,
                ),
              ),
              const SizedBox(height: 8),

              // Wóz
              Card(
                child: ListTile(
                  leading: const Icon(Icons.local_fire_department, color: Colors.red),
                  title: const Text('Wóz strażacki'),
                  subtitle: Text(
                    _wybranyWoz ?? 'Nie przypisano',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _wybierzWoz,
                ),
              ),
            ],

            // Tryb dwóch wozów
            if (_dwieJednostki) ...[
              // Wóz 1
              Card(
                color: Colors.blue[50],
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.local_fire_department, color: Colors.blue),
                      title: const Text('Wóz 1'),
                      subtitle: Text(_wybranyWoz1 ?? 'Nie przypisano'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => _DialogWyboruWozu(
                            wybranyWozId: _wybranyWoz1,
                            onWybor: (wozId) {
                              setState(() => _wybranyWoz1 = wozId);
                            },
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.group, color: Colors.blue),
                      title: const Text('Załoga wozu 1'),
                      subtitle: Text(
                        _woz1Strazacy.isEmpty
                            ? 'Nie przypisano'
                            : '${_woz1Strazacy.length} strażaków',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => _DialogWyboruStrazakow(
                            wszyscyStrazacy: _wszyscyStrazacy,
                            wybraniStrazacy: _woz1Strazacy,
                            onZmiana: (wybrani) {
                              setState(() => _woz1Strazacy = wybrani);
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Wóz 2
              Card(
                color: Colors.orange[50],
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.local_fire_department, color: Colors.orange),
                      title: const Text('Wóz 2'),
                      subtitle: Text(_wybranyWoz2 ?? 'Nie przypisano'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => _DialogWyboruWozu(
                            wybranyWozId: _wybranyWoz2,
                            onWybor: (wozId) {
                              setState(() => _wybranyWoz2 = wozId);
                            },
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.group, color: Colors.orange),
                      title: const Text('Załoga wozu 2'),
                      subtitle: Text(
                        _woz2Strazacy.isEmpty
                            ? 'Nie przypisano'
                            : '${_woz2Strazacy.length} strażaków',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => _DialogWyboruStrazakow(
                            wszyscyStrazacy: _wszyscyStrazacy,
                            wybraniStrazacy: _woz2Strazacy,
                            onZmiana: (wybrani) {
                              setState(() => _woz2Strazacy = wybrani);
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Przycisk zapisu
            ElevatedButton.icon(
              onPressed: _ladowanie ? null : _zapiszZmiany,
              icon: _ladowanie
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('ZAPISZ ZMIANY'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _obliczCzasTrwania() {
    if (_godzinaRozpoczecia == null || _godzinaZakonczenia == null) return 0;
    return _godzinaZakonczenia!.difference(_godzinaRozpoczecia!).inMinutes;
  }

  int _obliczGodzinyZaokraglone() {
    final minuty = _obliczCzasTrwania();
    if (minuty == 0) return 0;
    return (minuty / 60).ceil();
  }

  int _obliczEkwiwalent() {
    final godziny = _obliczGodzinyZaokraglone();
    if (godziny == 0) return 0;

    int stawka;
    switch (_wybranaKategoria) {
      case KategoriaWyjazdu.pozar:
      case KategoriaWyjazdu.miejscoweZagrozenie:
      case KategoriaWyjazdu.alarmFalszywy:
        stawka = 19;
        break;
      case KategoriaWyjazdu.zabezpieczenieRejonu:
      case KategoriaWyjazdu.zPoleceniaBurmistrza:
        stawka = 9;
        break;
      case KategoriaWyjazdu.cwiczenia:
        stawka = 6;
        break;
    }

    return godziny * stawka;
  }

  String _formatujDate(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}.${data.month.toString().padLeft(2, '0')}.${data.year}';
  }

  String _formatujGodzine(DateTime data) {
    return '${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _zapiszZmiany() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _ladowanie = true);

    try {
      await _serwisWyjazdow.edytujWyjazd(
        wyjazdId: widget.wyjazd.id,
        lokalizacja: _lokalizacjaController.text.trim(),
        opis: _opisController.text.trim(),
        kategoria: _wybranaKategoria,
        dataWyjazdu: _dataWyjazdu,
        godzinaRozpoczecia: _godzinaRozpoczecia,
        godzinaZakonczenia: _godzinaZakonczenia,
        // Użyj wybranych wartości zamiast zachowywać stare
        dowodcaId: widget.wyjazd.dowodcaId,
        strazacyIds: _dwieJednostki ? [] : _wybraniStrazacy,
        wozId: _dwieJednostki ? null : _wybranyWoz,
        woz1Id: _dwieJednostki ? _wybranyWoz1 : null,
        woz2Id: _dwieJednostki ? _wybranyWoz2 : null,
        woz1StrazacyIds: _dwieJednostki ? _woz1Strazacy : [],
        woz2StrazacyIds: _dwieJednostki ? _woz2Strazacy : [],
        uwagi: widget.wyjazd.uwagi,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wyjazd zaktualizowany'),
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

/// Dialog wyboru strażaków
class _DialogWyboruStrazakow extends StatefulWidget {
  final List<Strazak> wszyscyStrazacy;
  final List<String> wybraniStrazacy;
  final Function(List<String>) onZmiana;

  const _DialogWyboruStrazakow({
    required this.wszyscyStrazacy,
    required this.wybraniStrazacy,
    required this.onZmiana,
  });

  @override
  State<_DialogWyboruStrazakow> createState() => _DialogWyboruStrazakowState();
}

class _DialogWyboruStrazakowState extends State<_DialogWyboruStrazakow> {
  late List<String> _tymczasowoWybrani;

  @override
  void initState() {
    super.initState();
    _tymczasowoWybrani = List.from(widget.wybraniStrazacy);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Wybierz strażaków'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.wszyscyStrazacy.length,
          itemBuilder: (context, index) {
            final strazak = widget.wszyscyStrazacy[index];
            final wybrany = _tymczasowoWybrani.contains(strazak.id);

            return CheckboxListTile(
              title: Text(strazak.pelneImie),
              subtitle: Text(strazak.rola.nazwa),
              value: wybrany,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _tymczasowoWybrani.add(strazak.id);
                  } else {
                    _tymczasowoWybrani.remove(strazak.id);
                  }
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onZmiana(_tymczasowoWybrani);
            Navigator.pop(context);
          },
          child: const Text('Zatwierdź'),
        ),
      ],
    );
  }
}

/// Dialog wyboru wozu strażackiego
class _DialogWyboruWozu extends StatelessWidget {
  final String? wybranyWozId;
  final Function(String?) onWybor;

  const _DialogWyboruWozu({
    required this.wybranyWozId,
    required this.onWybor,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Wybierz wóz strażacki'),
      content: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('wozy')
            .where('aktywny', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text('Błąd: ${snapshot.error}');
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final wozy = snapshot.data!.docs;

          if (wozy.isEmpty) {
            return const Text('Brak wozów strażackich w bazie danych.');
          }

          // Sortowanie po stronie klienta
          wozy.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aNazwa = (aData['nazwa'] ?? '').toString().toLowerCase();
            final bNazwa = (bData['nazwa'] ?? '').toString().toLowerCase();
            return aNazwa.compareTo(bNazwa);
          });

          return SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  title: const Text('Nie przypisuj wozu'),
                  leading: Radio<String?>(
                    value: null,
                    groupValue: wybranyWozId,
                    onChanged: (value) {
                      onWybor(value);
                      Navigator.pop(context);
                    },
                  ),
                ),
                ...wozy.map((doc) {
                  final woz = doc.data() as Map<String, dynamic>;
                  final nazwa = woz['nazwa'] ?? '';
                  final nr = woz['numerRejestracyjny'] ?? '';
                  
                  return ListTile(
                    title: Text(nazwa),
                    subtitle: nr.isNotEmpty ? Text(nr) : null,
                    leading: Radio<String>(
                      value: doc.id,
                      groupValue: wybranyWozId,
                      onChanged: (value) {
                        onWybor(value);
                        Navigator.pop(context);
                      },
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}
