import 'package:flutter/material.dart';
import '../models/strazak.dart';
import '../services/serwis_autentykacji_nowy.dart';
import 'ekran_logowania_nowy.dart';

/// Ekran wyświetlany gdy konto oczekuje na zatwierdzenie przez administratora
class EkranOczekiwaniaNaZatwierdzenie extends StatelessWidget {
  final Strazak strazak;

  const EkranOczekiwaniaNaZatwierdzenie({
    super.key,
    required this.strazak,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OSP Kolumna'),
        backgroundColor: Colors.orange[700],
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.hourglass_empty,
                size: 100,
                color: Colors.orange[700],
              ),
              const SizedBox(height: 32),
              Text(
                'Witaj, ${strazak.imie}!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Twoje konto oczekuje na zatwierdzenie przez administratora',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Card(
                color: Colors.orange[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange[700],
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Co dalej?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '1. Twoje konto zostało utworzone pomyślnie\n'
                        '2. Administrator OSP Kolumna otrzymał powiadomienie\n'
                        '3. Zweryfikuje Twoje dane\n'
                        '4. Po akceptacji otrzymasz dostęp do aplikacji\n\n'
                        'Zazwyczaj trwa to do 24 godzin.\n\n'
                        'W razie pytań skontaktuj się z administratorem.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () async {
                  // Wyloguj użytkownika
                  await AuthService().logout();
                  
                  if (!context.mounted) return;
                  
                  // Wróć do ekranu logowania
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const EkranLogowania()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout),
                label: const Text('Wróć do logowania'),
              ),
              const SizedBox(height: 16),
              Text(
                'Email: ${strazak.email}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
              Text(
                'Data rejestracji: ${_formatujDate(strazak.dataRejestracji)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatujDate(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}.${data.month.toString().padLeft(2, '0')}.${data.year} ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }
}
