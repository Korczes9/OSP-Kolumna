import 'package:flutter/material.dart';
import '../services/serwis_importu_eremiza.dart';

/// Ekran do prostego importu alarmów z eRemiza
class EkranImportuEremiza extends StatefulWidget {
  const EkranImportuEremiza({super.key});

  @override
  State<EkranImportuEremiza> createState() => _EkranImportuEremizaState();
}

class _EkranImportuEremizaState extends State<EkranImportuEremiza> {
  final _serwis = SerwisImportuEremiza();
  final _emailController = TextEditingController();
  final _hasloController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _ladowanie = false;
  bool _zalogowany = false;
  String? _wynikImportu;

  @override
  void dispose() {
    _emailController.dispose();
    _hasloController.dispose();
    super.dispose();
  }

  Future<void> _zaloguj() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _ladowanie = true;
      _wynikImportu = null;
    });

    try {
      final sukces = await _serwis.zaloguj(
        _emailController.text.trim(),
        _hasloController.text,
      );

      if (sukces) {
        setState(() {
          _zalogowany = true;
          _wynikImportu = '✅ Zalogowano pomyślnie';
        });
      } else {
        setState(() {
          _wynikImportu = '❌ Błąd logowania. Sprawdź email i hasło.';
        });
      }
    } catch (e) {
      setState(() {
        _wynikImportu = '❌ Błąd: $e';
      });
    } finally {
      setState(() => _ladowanie = false);
    }
  }

  Future<void> _importuj() async {
    setState(() {
      _ladowanie = true;
      _wynikImportu = null;
    });

    try {
      final wynik = await _serwis.importujAlarmy();
      
      setState(() {
        _wynikImportu = 
            '✅ Import zakończony!\n\n'
            'Dodano: ${wynik['dodano']} alarmów\n'
            'Pominięto: ${wynik['pominieto']} (duplikaty lub spoza SK KP)';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Zaimportowano ${wynik['dodano']} alarmów z SK KP'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _wynikImportu = '❌ Błąd importu: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Błąd importu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _ladowanie = false);
    }
  }

  Future<void> _wyloguj() async {
    await _serwis.wyloguj();
    setState(() {
      _zalogowany = false;
      _emailController.clear();
      _hasloController.clear();
      _wynikImportu = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import z eRemiza'),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        actions: [
          if (_zalogowany)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _wyloguj,
              tooltip: 'Wyloguj',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Informacja
              Card(
                color: isDark ? Colors.blue[900] : Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          const Text(
                            'Import alarmów z eRemiza',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ta funkcja pobiera alarmy bezpośrednio ze strony eRemiza.\n\n'
                        '• Importowane są tylko alarmy z SK KP\n'
                        '• Duplikaty są automatycznie pomijane\n'
                        '• Wymagane logowanie do konta eRemiza',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (!_zalogowany) ...[
                // Formularz logowania
                const Text(
                  'Dane logowania do eRemiza',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Wprowadź email' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _hasloController,
                  decoration: const InputDecoration(
                    labelText: 'Hasło',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Wprowadź hasło' : null,
                ),
                const SizedBox(height: 24),

                ElevatedButton.icon(
                  onPressed: _ladowanie ? null : _zaloguj,
                  icon: _ladowanie
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.login),
                  label: Text(_ladowanie ? 'Logowanie...' : 'Zaloguj'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],

              if (_zalogowany) ...[
                // Przycisk importu
                Card(
                  color: isDark ? Colors.green[900] : Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Zalogowano pomyślnie',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton.icon(
                  onPressed: _ladowanie ? null : _importuj,
                  icon: _ladowanie
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download),
                  label: Text(_ladowanie ? 'Importowanie...' : 'Importuj alarmy z SK KP'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],

              // Wynik operacji
              if (_wynikImportu != null) ...[
                const SizedBox(height: 24),
                Card(
                  color: _wynikImportu!.startsWith('✅')
                      ? (isDark ? Colors.green[900] : Colors.green[50])
                      : (isDark ? Colors.red[900] : Colors.red[50]),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _wynikImportu!,
                      style: TextStyle(
                        fontSize: 14,
                        color: _wynikImportu!.startsWith('✅')
                            ? (isDark ? Colors.green[100] : Colors.green[900])
                            : (isDark ? Colors.red[100] : Colors.red[900]),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
