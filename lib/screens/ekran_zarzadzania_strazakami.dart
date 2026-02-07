import 'package:flutter/material.dart';
import '../services/serwis_autentykacji_nowy.dart';
import '../models/strazak.dart';

/// Ekran zarządzania strażakami (tylko dla administratorów)
class EkranZarzadzaniaStrazakami extends StatefulWidget {
  final Strazak obecnyStrazak;

  const EkranZarzadzaniaStrazakami({super.key, required this.obecnyStrazak});

  @override
  State<EkranZarzadzaniaStrazakami> createState() =>
      _EkranZarzadzaniaStrazakamiState();
}

class _EkranZarzadzaniaStrazakamiState
    extends State<EkranZarzadzaniaStrazakami> {
  final _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zarządzanie Strażakami'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        actions: [
          if (widget.obecnyStrazak.jestAdministratorem)
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              tooltip: 'Aktywuj wszystkich',
              onPressed: _aktywujWszystkich,
            ),
        ],
      ),
      body: StreamBuilder<List<Strazak>>(
        stream: _authService.pobierzWszystkichStrazakow(),
        initialData: const <Strazak>[],
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text('Błąd: ${snapshot.error}'),
                ],
              ),
            );
          }

          final strazacy = snapshot.data ?? [];

          if (strazacy.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Brak strażaków w systemie',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: strazacy.length,
            itemBuilder: (context, index) {
              final strazak = strazacy[index];
              return _strazakCard(strazak);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _pokazFormularzDodawania(),
        backgroundColor: Colors.red[700],
        icon: const Icon(Icons.person_add),
        label: const Text('Dodaj strażaka'),
      ),
    );
  }

  Widget _strazakCard(Strazak strazak) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: strazak.aktywny ? Colors.green : Colors.grey,
          child: Text(
            '${strazak.imie[0]}${strazak.nazwisko[0]}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          strazak.pelneImie,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strazak.email),
            Text(
              '${strazak.numerTelefonu} • ${strazak.rola.nazwa}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 10,
                  color: strazak.jestOnline ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  strazak.statusOnline,
                  style: TextStyle(
                    fontSize: 11,
                    color: strazak.jestOnline ? Colors.green : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _obsluzAkcje(value, strazak),
          itemBuilder: (context) => [
            if (widget.obecnyStrazak.jestAdministratorem)
              PopupMenuItem(
                value: 'rola',
                child: Row(
                  children: const [
                    Icon(Icons.admin_panel_settings, size: 20),
                    SizedBox(width: 8),
                    Text('Zmień rolę'),
                  ],
                ),
              ),
            PopupMenuItem(
              value: 'toggle',
              child: Row(
                children: [
                  Icon(
                    strazak.aktywny ? Icons.block : Icons.check_circle,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(strazak.aktywny ? 'Dezaktywuj' : 'Aktywuj'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Usuń', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Future<void> _obsluzAkcje(String akcja, Strazak strazak) async {
    switch (akcja) {
      case 'rola':
        _pokazDialogZmianyRoli(strazak);
        break;
      case 'edytuj_nazwe':
        _pokazDialogZmianyNazwy(strazak);
        break;
      case 'toggle':
        final sukces = await _authService.aktualizujStatusStrazaka(
          strazak.id,
          !strazak.aktywny,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                sukces
                    ? '${strazak.pelneImie} ${strazak.aktywny ? "dezaktywowany" : "aktywowany"}'
                    : 'Błąd zmiany statusu',
              ),
              backgroundColor: sukces ? Colors.green : Colors.red,
            ),
          );
        }
        break;

      case 'delete':
        final potwierdz = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Potwierdzenie'),
            content: Text(
              'Czy na pewno chcesz usunąć strażaka ${strazak.pelneImie}?',
            ),
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
          final sukces = await _authService.usunStrazaka(strazak.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  sukces
                      ? '${strazak.pelneImie} został usunięty'
                      : 'Błąd usuwania strażaka',
                ),
                backgroundColor: sukces ? Colors.green : Colors.red,
              ),
            );
          }
        }
        break;
    }
  }

  void _pokazDialogZmianyRoli(Strazak strazak) {
    showDialog(
      context: context,
      builder: (context) {
        List<RolaStrazaka> wybraneRole = List.from(strazak.role);
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Zmień role: ${strazak.pelneImie}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Zaznacz wszystkie role użytkownika:',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    ...RolaStrazaka.values.map((rola) {
                      final czyZaznaczone = wybraneRole.contains(rola);
                      return CheckboxListTile(
                        title: Text(rola.nazwa),
                        subtitle: Text('Poziom ${rola.poziom}'),
                        value: czyZaznaczone,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              wybraneRole.add(rola);
                            } else {
                              wybraneRole.remove(rola);
                            }
                          });
                        },
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Anuluj'),
                ),
                ElevatedButton(
                  onPressed: wybraneRole.isEmpty
                      ? null
                      : () async {
                          Navigator.pop(context);
                          final sukces = await _authService.aktualizujRoleStrazaka(
                            strazak.id,
                            wybraneRole.map((r) => r.name).toList(),
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  sukces
                                      ? 'Zmieniono role na ${wybraneRole.map((r) => r.nazwa).join(", ")}'
                                      : 'Błąd zmiany ról',
                                ),
                                backgroundColor: sukces ? Colors.green : Colors.red,
                              ),
                            );
                          }
                        },
                  child: const Text('Zapisz'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _pokazDialogZmianyNazwy(Strazak strazak) {
    final kontrolerImie = TextEditingController(text: strazak.imie);
    final kontrolerNazwisko = TextEditingController(text: strazak.nazwisko);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zmień nazwę'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: kontrolerImie,
              decoration: const InputDecoration(
                labelText: 'Imię',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: kontrolerNazwisko,
              decoration: const InputDecoration(
                labelText: 'Nazwisko',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (kontrolerImie.text.isEmpty || kontrolerNazwisko.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Wypełnij oba pola')),
                );
                return;
              }
              
              Navigator.pop(context);
              final sukces = await _authService.aktualizujNazweStrazaka(
                strazak.id,
                kontrolerImie.text.trim(),
                kontrolerNazwisko.text.trim(),
              );
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      sukces
                          ? 'Zmieniono nazwę na ${kontrolerImie.text} ${kontrolerNazwisko.text}'
                          : 'Błąd zmiany nazwy',
                    ),
                    backgroundColor: sukces ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
  }

  void _pokazFormularzDodawania() {
    showDialog(
      context: context,
      builder: (context) => const DialogDodajStrazaka(),
    );
  }

  Future<void> _aktywujWszystkich() async {
    final potwierdz = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aktywuj wszystkich strażaków'),
        content: const Text(
          'Czy na pewno chcesz aktywować wszystkich strażaków w systemie? '
          'Po aktywacji będą mogli logować się do aplikacji.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Aktywuj'),
          ),
        ],
      ),
    );

    if (potwierdz != true) return;

    // Pokaż dialog ładowania
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Aktywuję użytkowników...'),
              ],
            ),
          ),
        ),
      ),
    );

    final wynik = await _authService.aktywujWszystkichStrazakow();

    if (!mounted) return;
    Navigator.pop(context); // Zamknij dialog ładowania

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wynik['success'] == true
              ? 'Aktywowano ${wynik['aktywowanych']} strażaków (${wynik['juzAktywnych']} już było aktywnych)'
              : wynik['error'] as String,
        ),
        backgroundColor: wynik['success'] == true ? Colors.green : Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

/// Dialog do dodawania nowego strażaka
class DialogDodajStrazaka extends StatefulWidget {
  const DialogDodajStrazaka({super.key});

  @override
  State<DialogDodajStrazaka> createState() => _DialogDodajStrazakaState();
}

class _DialogDodajStrazakaState extends State<DialogDodajStrazaka> {
  final _formKey = GlobalKey<FormState>();
  final _imieController = TextEditingController();
  final _nazwiskoController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonController = TextEditingController();
  final _hasloController = TextEditingController();
  final _authService = AuthService();

  RolaStrazaka _wybranaRola = RolaStrazaka.strazak;
  bool _ladowanie = false;

  @override
  void dispose() {
    _imieController.dispose();
    _nazwiskoController.dispose();
    _emailController.dispose();
    _telefonController.dispose();
    _hasloController.dispose();
    super.dispose();
  }

  Future<void> _dodajStrazaka() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _ladowanie = true);

    final wynik = await _authService.dodajStrazaka(
      imie: _imieController.text.trim(),
      nazwisko: _nazwiskoController.text.trim(),
      email: _emailController.text.trim(),
      numerTelefonu: _telefonController.text.trim(),
      haslo: _hasloController.text,
      rola: _wybranaRola,
    );

    if (!mounted) return;

    if (wynik['success'] == true) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dodano strażaka: ${wynik['strazak'].pelneImie}'),
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Dodaj nowego strażaka'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _imieController,
                decoration: const InputDecoration(
                  labelText: 'Imię',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Wprowadź imię' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nazwiskoController,
                decoration: const InputDecoration(
                  labelText: 'Nazwisko',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Wprowadź nazwisko' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Wprowadź email';
                  if (!v.contains('@')) return 'Nieprawidłowy format email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telefonController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Numer telefonu',
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Wprowadź numer telefonu' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _hasloController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Hasło',
                  prefixIcon: Icon(Icons.lock),
                  helperText: 'Min. 6 znaków',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Wprowadź hasło';
                  if (v.length < 6) return 'Hasło musi mieć min. 6 znaków';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<RolaStrazaka>(
                initialValue: _wybranaRola,
                decoration: const InputDecoration(
                  labelText: 'Rola',
                  prefixIcon: Icon(Icons.badge),
                ),
                items: RolaStrazaka.values.map((rola) {
                  return DropdownMenuItem(
                    value: rola,
                    child: Text(rola.nazwa),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _wybranaRola = v!),
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
          onPressed: _ladowanie ? null : _dodajStrazaka,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[700],
            foregroundColor: Colors.white,
          ),
          child: _ladowanie
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Dodaj'),
        ),
      ],
    );
  }
}
