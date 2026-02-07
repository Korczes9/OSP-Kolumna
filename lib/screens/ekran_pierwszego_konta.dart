import 'package:flutter/material.dart';
import '../services/serwis_autentykacji_nowy.dart';
import '../models/strazak.dart';

/// Pomocniczy ekran do utworzenia pierwszego konta Administratora
/// Użyj tylko raz do inicjalizacji systemu
class EkranPierwszegoKonta extends StatefulWidget {
  const EkranPierwszegoKonta({super.key});

  @override
  State<EkranPierwszegoKonta> createState() => _EkranPierwszegoKontaState();
}

class _EkranPierwszegoKontaState extends State<EkranPierwszegoKonta> {
  final _formKey = GlobalKey<FormState>();
  final _emailController =
      TextEditingController(text: 'administrator@ospkolumna.pl');
  final _hasloController = TextEditingController(text: 'admin123');
  final _authService = AuthService();
  bool _ladowanie = false;

  @override
  void dispose() {
    _emailController.dispose();
    _hasloController.dispose();
    super.dispose();
  }

  Future<void> _utworzAdministratora() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _ladowanie = true);

    // Utwórz konto Administratora
    final wynik = await _authService.dodajStrazaka(
      imie: 'OSP',
      nazwisko: 'Kolumna',
      email: _emailController.text.trim(),
      numerTelefonu: '123456789',
      haslo: _hasloController.text,
      rola: RolaStrazaka.administrator,
    );

    if (!mounted) return;

    if (wynik['success'] == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Sukces!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Konto Administratora zostało utworzone!'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dane do logowania:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('Email: ${_emailController.text}'),
                    Text('Hasło: ${_hasloController.text}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Zapisz te dane! Możesz teraz wrócić i się zalogować.',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Zamknij dialog
                Navigator.pop(context); // Wróć do logowania
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('OK, przejdź do logowania'),
            ),
          ],
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pierwsze konto - Administrator'),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  size: 80,
                  color: Colors.orange[700],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Utworzenie pierwszego konta',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'To konto będzie miało rolę Administratora\nz pełnymi uprawnieniami',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      SizedBox(height: 8),
                      Text(
                        'Dane domyślne - możesz je zmienić',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Imię: OSP Kolumna\nTelefon: 691837009',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email (login)',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Wprowadź email';
                    if (!v.contains('@')) return 'Nieprawidłowy email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _hasloController,
                  decoration: const InputDecoration(
                    labelText: 'Hasło',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                    helperText: 'Min. 6 znaków',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Wprowadź hasło';
                    if (v.length < 6) return 'Min. 6 znaków';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _ladowanie ? null : _utworzAdministratora,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _ladowanie
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Utwórz konto Administratora',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Anuluj i wróć'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
