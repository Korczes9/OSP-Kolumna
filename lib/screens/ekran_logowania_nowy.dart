import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/serwis_autentykacji_nowy.dart';
import '../models/strazak.dart';
import 'ekran_domowy_osp.dart';
import 'dialog_rejestracji.dart';
import 'ekran_pierwszego_konta.dart';
import 'ekran_debug_logowania.dart';

/// Ekran logowania z weryfikacją konta
class EkranLogowania extends StatefulWidget {
  const EkranLogowania({super.key});

  @override
  State<EkranLogowania> createState() => _EkranLogowaniaState();
}

class _EkranLogowaniaState extends State<EkranLogowania> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _hasloController = TextEditingController();
  final _authService = AuthService();
  
  bool _ladowanie = false;
  String? _bladWiadomosc;

  @override
  void dispose() {
    _emailController.dispose();
    _hasloController.dispose();
    super.dispose();
  }

  Future<void> _zaloguj() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Sprawdź połączenie internetowe
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      setState(() {
        _bladWiadomosc = 'Brak połączenia z internetem. Sprawdź swoje połączenie i spróbuj ponownie.';
      });
      return;
    }

    setState(() {
      _ladowanie = true;
      _bladWiadomosc = null;
    });

    try {
      final wynik = await _authService.login(
        email: _emailController.text.trim(),
        password: _hasloController.text,
      );

      if (!mounted) return;

      if (wynik['success'] == true) {
        final strazak = wynik['strazak'] as Strazak;
        
        // Przekieruj do ekranu głównego
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EkranDomowyOSP(strazak: strazak),
          ),
        );
      } else {
        setState(() {
          _bladWiadomosc = wynik['error'] as String?;
          _ladowanie = false;
        });
      }
    } catch (e) {
      setState(() {
        _bladWiadomosc = 'Wystąpił nieoczekiwany błąd: $e';
        _ladowanie = false;
      });
    }
  }

  Future<void> _resetujHaslo() async {
    final emailLubTelefon = _emailController.text.trim();
    
    if (emailLubTelefon.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wprowadź adres email lub numer telefonu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Sprawdź połączenie internetowe
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Brak połączenia z internetem. Sprawdź swoje połączenie i spróbuj ponownie.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }
    
    final email = await _authService.pobierzEmailPoIdentyfikatorze(emailLubTelefon);

    if (email == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nie znaleziono konta o tym numerze telefonu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final wynik = await _authService.resetujHaslo(email);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wynik['success'] == true
              ? wynik['message'] as String
              : wynik['error'] as String,
        ),
        backgroundColor: wynik['success'] == true ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Wskaźnik połączenia
            StreamBuilder<List<ConnectivityResult>>(
              stream: Connectivity().onConnectivityChanged,
              initialData: const [ConnectivityResult.wifi],
              builder: (context, snapshot) {
                final connectivityResults = snapshot.data ?? [];
                final isOffline = connectivityResults.contains(ConnectivityResult.none);
                
                if (isOffline) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    color: Colors.red[700],
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.cloud_off, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Brak połączenia z internetem',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            // Reszta ekranu
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo OSP
                        Image.asset(
                          'assets/images/logo_osp_kolumna.png',
                          height: 120,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.local_fire_department,
                              size: 100,
                              color: Colors.red[700],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Tytuł
                        Text(
                          'OSP Kolumna',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'System Zarządzania Alarmami',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Pole email lub telefon
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.text,
                          decoration: InputDecoration(
                            labelText: 'Email lub numer telefonu',
                            hintText: 'np. jan@example.com lub 123456789',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Wprowadź email lub numer telefonu';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Pole hasło
                        TextFormField(
                          controller: _hasloController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Hasło',
                            prefixIcon: const Icon(Icons.lock),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Wprowadź hasło';
                            }
                            if (value.length < 6) {
                              return 'Hasło musi mieć min. 6 znaków';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Komunikat błędu
                        if (_bladWiadomosc != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red[300]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red[700]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _bladWiadomosc!,
                                    style: TextStyle(color: Colors.red[700]),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Przycisk logowania
                        ElevatedButton(
                          onPressed: _ladowanie ? null : _zaloguj,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
                              : const Text(
                                  'Zaloguj się',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),

                        // Link resetowania hasła
                        TextButton(
                          onPressed: _ladowanie ? null : _resetujHaslo,
                          child: const Text(
                            'Zapomniałeś hasła?',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Info dla nowych użytkowników
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue[700]),
                              const SizedBox(height: 8),
                              Text(
                                'Nie masz konta?',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[900],
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final rezultat = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => const DialogRejestracji(),
                                  );
                                  
                                  // Po udanej rejestracji email już będzie wypełniony
                                  if (rezultat == true) {
                                    // Użytkownik może się teraz zalogować
                                  }
                                },
                                icon: const Icon(Icons.person_add),
                                label: const Text('Utwórz konto'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[700],
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Przycisk do tworzenia pierwszego konta (Administrator)
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const EkranPierwszegoKonta(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.admin_panel_settings, size: 16),
                          label: const Text(
                            'Pierwsze uruchomienie? Utwórz konto Administratora',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Przycisk debug (dla administratora/deweloperów)
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const EkranDebugLogowania(),
                              ),
                            );
                          },
                          icon: Icon(Icons.bug_report, size: 16, color: Colors.orange[700]),
                          label: Text(
                            '🔍 Nie możesz się zalogować? Sprawdź konto',
                            style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
