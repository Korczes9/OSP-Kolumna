import 'package:flutter/material.dart';
import '../services/serwis_autentykacji_nowy.dart';
import '../models/strazak.dart';
import 'ekran_oczekiwania_na_zatwierdzenie.dart';

/// Dialog rejestracji nowego użytkownika
class DialogRejestracji extends StatefulWidget {
  const DialogRejestracji({super.key});

  @override
  State<DialogRejestracji> createState() => _DialogRejestracjiState();
}

class _DialogRejestracjiState extends State<DialogRejestracji> {
  final _formKey = GlobalKey<FormState>();
  final _imieController = TextEditingController();
  final _nazwiskoController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonController = TextEditingController();
  final _hasloController = TextEditingController();
  final _potwierdzHasloController = TextEditingController();
  final _authService = AuthService();

  bool _ladowanie = false;

  @override
  void dispose() {
    _imieController.dispose();
    _nazwiskoController.dispose();
    _emailController.dispose();
    _telefonController.dispose();
    _hasloController.dispose();
    _potwierdzHasloController.dispose();
    super.dispose();
  }

  Future<void> _zarejestruj() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_hasloController.text != _potwierdzHasloController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hasła nie są identyczne'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _ladowanie = true);

    final wynik = await _authService.zarejestruj(
      imie: _imieController.text.trim(),
      nazwisko: _nazwiskoController.text.trim(),
      email: _emailController.text.trim(),
      numerTelefonu: _telefonController.text.trim(),
      haslo: _hasloController.text,
    );

    if (!mounted) return;

    if (wynik['success'] == true) {
      final strazak = wynik['strazak'] as Strazak;
      
      // Zamknij dialog
      Navigator.pop(context);
      
      // Pokaż ekran oczekiwania na zatwierdzenie
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EkranOczekiwaniaNaZatwierdzenie(strazak: strazak),
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
      title: Row(
        children: [
          Icon(Icons.person_add, color: Colors.red[700]),
          const SizedBox(width: 8),
          const Text('Utwórz konto'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _imieController,
                decoration: const InputDecoration(
                  labelText: 'Imię *',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Wprowadź imię' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nazwiskoController,
                decoration: const InputDecoration(
                  labelText: 'Nazwisko *',
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
                  labelText: 'Email *',
                  prefixIcon: Icon(Icons.email),
                  helperText: 'Będzie używany do logowania',
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
                  labelText: 'Numer telefonu *',
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
                  labelText: 'Hasło *',
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
              TextFormField(
                controller: _potwierdzHasloController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Potwierdź hasło *',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Potwierdź hasło';
                  return null;
                },
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
          onPressed: _ladowanie ? null : _zarejestruj,
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
              : const Text('Zarejestruj'),
        ),
      ],
    );
  }
}
