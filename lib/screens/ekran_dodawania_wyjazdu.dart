import 'package:flutter/material.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wyjazd.dart';
import '../models/strazak.dart';
import '../services/serwis_wyjazdow.dart';
import '../services/serwis_autentykacji_nowy.dart';
import '../services/serwis_ekwiwalentow.dart';

const String _googleApiKey = 'AIzaSyAqTJGSPMNS5jAquRA6oQlLq8Y6DHOKYK0';

/// Ekran dodawania nowego wyjazdu
class EkranDodawaniaWyjazdu extends StatefulWidget {
  final Strazak aktualnyStrazak;

  const EkranDodawaniaWyjazdu({
    super.key,
    required this.aktualnyStrazak,
  });

  @override
  State<EkranDodawaniaWyjazdu> createState() => _EkranDodawaniaWyjazduState();
}

class _EkranDodawaniaWyjazduState extends State<EkranDodawaniaWyjazdu> {
  final _formKey = GlobalKey<FormState>();
  final _lokalizacjaController = TextEditingController();
  final _opisController = TextEditingController();
  final _uwagiController = TextEditingController();
  final _serwisWyjazdow = SerwisWyjazdow();
  final _authService = AuthService();

  KategoriaWyjazdu _wybranaKategoria = KategoriaWyjazdu.miejscoweZagrozenie;
  List<Strazak> _wszyscyStrazacy = [];
  List<String> _wybraniStrazacy = [];
  String? _wybranyDowodca;
  String? _wybranyWoz;
  String? _wybranyWoz1;
  String? _wybranyWoz2;
  List<String> _woz1Strazacy = [];
  List<String> _woz2Strazacy = [];
  bool _dwieJednostki = false; // Przełącznik trybu dwóch wozów
  bool _ladowanie = false;
  DateTime _wybranaData = DateTime.now(); // Data wyjazdu
  DateTime? _godzinaRozpoczecia;
  DateTime? _godzinaZakonczenia;

  @override
  void initState() {
    super.initState();
    _pobierzStrazakow();
  }

  @override
  void dispose() {
    _lokalizacjaController.dispose();
    _opisController.dispose();
    _uwagiController.dispose();
    super.dispose();
  }

  Future<void> _pobierzStrazakow() async {
    _authService.pobierzWszystkichStrazakow().listen((strazacy) {
      setState(() {
        _wszyscyStrazacy = strazacy.where((s) => s.aktywny).toList();
      });
    });
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

  double _obliczEkwiwalent() {
    final godziny = _obliczGodzinyZaokraglone();
    if (godziny == 0) return 0.0;
    
    double stawka = 0.0;
    switch (_wybranaKategoria) {
      case KategoriaWyjazdu.pozar:
      case KategoriaWyjazdu.miejscoweZagrozenie:
      case KategoriaWyjazdu.alarmFalszywy:
        stawka = SerwisEkwiwalentow.stawkaPozarMiejscoweAlarm;
        break;
      case KategoriaWyjazdu.zabezpieczenieRejonu:
      case KategoriaWyjazdu.zPoleceniaBurmistrza:
        stawka = SerwisEkwiwalentow.stawkaZabezpieczeniePolecenie;
        break;
      case KategoriaWyjazdu.cwiczenia:
        stawka = SerwisEkwiwalentow.stawkaCwiczenia;
        break;
    }
    
    return godziny * stawka;
  }

  Future<void> _dodajWyjazd() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _ladowanie = true);

    final wynik = await _serwisWyjazdow.dodajWyjazd(
      kategoria: _wybranaKategoria,
      lokalizacja: _lokalizacjaController.text.trim(),
      opis: _opisController.text.trim(),
      utworzonePrzez: widget.aktualnyStrazak.id,
      dataWyjazdu: _wybranaData, // Przekazanie wybranej daty
      dowodcaId: _wybranyDowodca,
      strazacyIds: _dwieJednostki ? [] : _wybraniStrazacy,
      wozId: _dwieJednostki ? null : _wybranyWoz,
      woz1Id: _dwieJednostki ? _wybranyWoz1 : null,
      woz2Id: _dwieJednostki ? _wybranyWoz2 : null,
      woz1StrazacyIds: _dwieJednostki ? _woz1Strazacy : [],
      woz2StrazacyIds: _dwieJednostki ? _woz2Strazacy : [],
      uwagi: _uwagiController.text.trim(),
      godzinaRozpoczecia: _godzinaRozpoczecia,
      godzinaZakonczenia: _godzinaZakonczenia,
    );

    if (!mounted) return;

    if (wynik['success'] == true) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wyjazd dodany pomyślnie'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() => _ladowanie = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(wynik['error'] as String),
          backgroundColor: Colors.red,
        ),
      );
    }
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nowy Wyjazd'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Kategoria
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kategoria wyjazdu',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...KategoriaWyjazdu.values.map((kategoria) {
                        return RadioListTile<KategoriaWyjazdu>(
                          title: Text(kategoria.nazwa),
                          value: kategoria,
                          groupValue: _wybranaKategoria,
                          onChanged: (value) {
                            setState(() => _wybranaKategoria = value!);
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Lokalizacja z autocomplete
              GooglePlaceAutoCompleteTextField(
                textEditingController: _lokalizacjaController,
                googleAPIKey: _googleApiKey,
                inputDecoration: const InputDecoration(
                  labelText: 'Lokalizacja *',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                  helperText: 'Zacznij pisać adres aby zobaczyć sugestie',
                ),
                debounceTime: 600,
                countries: const ['pl'],
                isLatLngRequired: false,
                getPlaceDetailWithLatLng: (Prediction prediction) {
                  // Po wybraniu miejsca z listy
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
                  labelText: 'Opis zdarzenia *',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Wprowadź opis' : null,
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Data wyjazdu
              Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_today, color: Colors.blue),
                  title: const Text('Data wyjazdu'),
                  subtitle: Text(
                    '${_wybranaData.day}.${_wybranaData.month}.${_wybranaData.year}',
                  ),
                  trailing: const Icon(Icons.edit),
                  onTap: () async {
                    final data = await showDatePicker(
                      context: context,
                      initialDate: _wybranaData,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 7)),
                    );
                    if (data != null) {
                      setState(() => _wybranaData = data);
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Godziny
              Row(
                children: [
                  Expanded(
                    child: Card(
                      child: ListTile(
                        leading: const Icon(Icons.access_time, color: Colors.green),
                        title: const Text('Rozpoczęcie'),
                        subtitle: Text(
                          _godzinaRozpoczecia != null
                              ? '${_godzinaRozpoczecia!.hour.toString().padLeft(2, '0')}:${_godzinaRozpoczecia!.minute.toString().padLeft(2, '0')}'
                              : 'Wybierz godzinę',
                        ),
                        onTap: () async {
                          final czas = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (czas != null) {
                            setState(() {
                              final teraz = DateTime.now();
                              _godzinaRozpoczecia = DateTime(
                                teraz.year,
                                teraz.month,
                                teraz.day,
                                czas.hour,
                                czas.minute,
                              );
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Card(
                      child: ListTile(
                        leading: const Icon(Icons.access_time_filled, color: Colors.red),
                        title: const Text('Zakończenie'),
                        subtitle: Text(
                          _godzinaZakonczenia != null
                              ? '${_godzinaZakonczenia!.hour.toString().padLeft(2, '0')}:${_godzinaZakonczenia!.minute.toString().padLeft(2, '0')}'
                              : 'Wybierz godzinę',
                        ),
                        onTap: () async {
                          final czas = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (czas != null) {
                            setState(() {
                              final teraz = DateTime.now();
                              _godzinaZakonczenia = DateTime(
                                teraz.year,
                                teraz.month,
                                teraz.day,
                                czas.hour,
                                czas.minute,
                              );
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              
              // Podsumowanie czasu i ekwiwalentu
              if (_godzinaRozpoczecia != null && _godzinaZakonczenia != null)
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Czas trwania: ${_obliczCzasTrwania()} min (${_obliczGodzinyZaokraglone()}h zaokrąglone)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ekwiwalent: ${_obliczEkwiwalent().toStringAsFixed(2)} PLN',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Dowódca
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_pin, color: Colors.orange),
                  title: const Text('Dowódca akcji'),
                  subtitle: Text(
                    _wybranyDowodca != null
                        ? _wszyscyStrazacy
                            .firstWhere((s) => s.id == _wybranyDowodca)
                            .pelneImie
                        : 'Nie przypisano',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => _DialogWyboruDowodcy(
                        strazacy: _wszyscyStrazacy
                          .where((s) => s.jestModeratorem || s.jestDowodca)
                          .toList(),
                        wybranyId: _wybranyDowodca,
                        onWybor: (id) {
                          setState(() => _wybranyDowodca = id);
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),

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
              const SizedBox(height: 16),

              // Uwagi
              TextFormField(
                controller: _uwagiController,
                decoration: const InputDecoration(
                  labelText: 'Uwagi (opcjonalne)',
                  prefixIcon: Icon(Icons.note),
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // Przycisk zapisu
              ElevatedButton(
                onPressed: _ladowanie ? null : _dodajWyjazd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _ladowanie
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Dodaj wyjazd',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              
              const SizedBox(height: 32),
              const Divider(),
              
              // Podgląd ostatnio dodanych wyjazdów
              const Text(
                'Ostatnie wyjazdy',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              StreamBuilder(
                stream: _serwisWyjazdow.pobierzWyjazdy(limit: 5),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final wyjazdy = snapshot.data!;
                  
                  if (wyjazdy.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Brak wyjazdów'),
                      ),
                    );
                  }
                  
                  return Column(
                    children: wyjazdy.map((wyjazd) {
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            Icons.local_fire_department,
                            color: wyjazd.kategoria == KategoriaWyjazdu.pozar
                                ? Colors.red
                                : Colors.orange,
                          ),
                          title: Text(wyjazd.lokalizacja),
                          subtitle: Text(
                            '${wyjazd.kategoria.nazwa} • ${wyjazd.dataWyjazdu.day}.${wyjazd.dataWyjazdu.month}.${wyjazd.dataWyjazdu.year}',
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
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

/// Dialog wyboru dowódcy
class _DialogWyboruDowodcy extends StatelessWidget {
  final List<Strazak> strazacy;
  final String? wybranyId;
  final Function(String?) onWybor;

  const _DialogWyboruDowodcy({
    required this.strazacy,
    required this.wybranyId,
    required this.onWybor,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Wybierz dowódcę'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('Brak dowódcy'),
              leading: Radio<String?>(
                value: null,
                groupValue: wybranyId,
                onChanged: (value) {
                  onWybor(value);
                  Navigator.pop(context);
                },
              ),
            ),
            ...strazacy.map((strazak) {
              return ListTile(
                title: Text(strazak.pelneImie),
                subtitle: Text(strazak.rola.nazwa),
                leading: Radio<String>(
                  value: strazak.id,
                  groupValue: wybranyId,
                  onChanged: (value) {
                    onWybor(value);
                    Navigator.pop(context);
                  },
                ),
              );
            }),
          ],
        ),
      ),
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
