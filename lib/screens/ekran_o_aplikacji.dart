import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ekran informacji o aplikacji
class EkranOAplikacji extends StatelessWidget {
  const EkranOAplikacji({super.key});

  Future<void> _wyslijEmail(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'korczes9@gmail.com',
      queryParameters: {
        'subject': 'OSP Kolumna - Kontakt',
      },
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nie można otworzyć klienta email'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Błąd: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('O aplikacji'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Logo i nazwa
          Center(
            child: Column(
              children: [
                Image.asset(
                  'assets/images/logo_osp_kolumna.png',
                  height: 120,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.local_fire_department,
                    size: 120,
                    color: Colors.red[700],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'OSP Kolumna',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Wersja 1.0.4+5',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Opis aplikacji
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      const Text(
                        'O aplikacji',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Aplikacja mobilna dla Ochotniczej Straży Pożarnej Kolumna. '
                    'Umożliwia zarządzanie alarmami, dyżurami i komunikacją między strażakami.',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Funkcje aplikacji
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.featured_play_list, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      const Text(
                        'Główne funkcje',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildFunkcja(
                    Icons.local_fire_department,
                    'Zarządzanie wyjazdami',
                    'Historia i dokumentacja wszystkich akcji ratowniczych',
                  ),
                  _buildFunkcja(
                    Icons.directions_car,
                    'Obsada pojazdów',
                    'Zarządzanie wozami strażackimi i składem osobowym',
                  ),
                  _buildFunkcja(
                    Icons.calendar_month,
                    'Terminarz',
                    'Plan wydarzeń, szkoleń, ćwiczeń i dyżurów',
                  ),
                  _buildFunkcja(
                    Icons.attach_money,
                    'Raporty ekwiwalentów',
                    'Podsumowanie godzin i wypłat dla strażaków',
                  ),
                  _buildFunkcja(
                    Icons.bar_chart,
                    'Statystyki',
                    'Wykresy i analizy aktywności jednostki',
                  ),
                  _buildFunkcja(
                    Icons.picture_as_pdf,
                    'Generowanie raportów PDF',
                    'Tworzenie dokumentów do druku i wysyłania',
                  ),
                  _buildFunkcja(
                    Icons.map,
                    'Mapa wyjazdów',
                    'Wizualizacja historii akcji na mapie',
                  ),
                  _buildFunkcja(
                    Icons.warning_amber,
                    'Zagrożenia w rejonie',
                    'CBRN, hydranty, ostrzeżenia IMGW, drogi zamknięte',
                  ),
                  _buildFunkcja(
                    Icons.public,
                    'Wyje w powiecie (Pro)',
                    'Powiadomienia Discord o wyjazdach w całym powiecie',
                  ),
                  _buildFunkcja(
                    Icons.school,
                    'Szkolenia',
                    'Zarządzanie certyfikatami i uprawnieniami',
                  ),
                  _buildFunkcja(
                    Icons.inventory_2,
                    'Inwentaryzacja sprzętu',
                    'Ewidencja wyposażenia i przeglądy',
                  ),
                  _buildFunkcja(
                    Icons.sync,
                    'Integracja eRemiza',
                    'Automatyczna synchronizacja alarmów z systemem krajowym',
                  ),
                  _buildFunkcja(
                    Icons.notifications_active,
                    'Powiadomienia push',
                    'Natychmiastowe alerty o alarmach i wydarzeniach',
                  ),
                  _buildFunkcja(
                    Icons.offline_bolt,
                    'Tryb offline',
                    'Działanie bez połączenia z internetem',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Informacje o autorze
          Card(
            color: Colors.red[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, color: Colors.red[700]),
                      const SizedBox(width: 8),
                      const Text(
                        'Autor aplikacji',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Sebastian Grochulski',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.email, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _wyslijEmail(context),
                          child: Text(
                            'korczes9@gmail.com',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue[700],
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _wyslijEmail(context),
                    icon: const Icon(Icons.email),
                    label: const Text('Wyślij wiadomość'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Prawa autorskie
          Center(
            child: Column(
              children: [
                Text(
                  '© 2026 OSP Kolumna',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Wszystkie prawa zastrzeżone',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFunkcja(IconData icon, String tytul, String opis) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.red[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tytul,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  opis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
