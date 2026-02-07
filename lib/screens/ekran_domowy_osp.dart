import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/strazak.dart';
import '../services/serwis_autentykacji_nowy.dart';
import '../services/serwis_motywu.dart';
import '../services/serwis_powiadomien.dart';
import '../services/serwis_imgw.dart';
import '../services/eremiza_service.dart';
import '../services/serwis_monitoringu_discord.dart';
import 'status_polaczenia_widget.dart';
import 'ekran_zarzadzania_strazakami.dart';
import 'ekran_logowania_nowy.dart';
import 'ekran_dodawania_wyjazdu.dart';
import 'ekran_terminarza.dart';
import 'ekran_raportu_ekwiwalentow.dart';
import 'ekran_statystyk.dart';
import 'ekran_statystyk_reakcji.dart';
import 'ekran_szkolen.dart';
import 'ekran_sprzetu.dart';
import 'ekran_importu_eremiza.dart';
import 'ekran_listy_wyjazdow.dart';
import 'ekran_dostepnosci_strazakow.dart';
import 'ekran_wozow_strazackich.dart';
import 'ekran_raportow_pdf.dart';
import 'ekran_mapy_wyjazdow.dart';
import 'ekran_zatwierdzania_uzytkownikow.dart';
import 'ekran_zagrozen.dart';
import 'ekran_wyjazdow_w_powiecie.dart';
import 'ekran_o_aplikacji.dart';
import 'ekran_zglaszania_problemow.dart';
import 'ekran_czatu_grupowego.dart';
import 'ekran_monitoringu_discord.dart';
import '../widgets/widget_nadchodzace_wydarzenia.dart';
import '../widgets/widget_zagrozen_pozarowych.dart';

class EkranDomowyOSP extends StatefulWidget {
  final Strazak strazak;

  const EkranDomowyOSP({super.key, required this.strazak});

  @override
  State<EkranDomowyOSP> createState() => _EkranDomowyOSPState();
}

class _EkranDomowyOSPState extends State<EkranDomowyOSP> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SerwisIMGW _serwisIMGW = SerwisIMGW();
  final EremizaService _eremizaService = EremizaService();
  final SerwisMonitoringuDiscord _discordMonitoring = SerwisMonitoringuDiscord();
  List<OstrzezenieIMGW> _ostrzezenia = [];
  
  @override
  void initState() {
    super.initState();
    // Inicjalizuj powiadomienia push po zalogowaniu
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SerwisPowiadomien.inicjalizuj(context);
      _zaladujOstrzezenia();
      _inicjalizujEremiza();
      _uruchomMonitoringDiscord();
    });
  }

  Future<void> _uruchomMonitoringDiscord() async {
    try {
      debugPrint('🔄 Uruchamiam monitoring Discord...');
      await _discordMonitoring.startMonitoring();
      debugPrint('✅ Monitoring Discord uruchomiony');
    } catch (e) {
      debugPrint('⚠️ Błąd uruchamiania monitoringu Discord: $e');
    }
  }

  Future<void> _inicjalizujEremiza() async {
    try {
      debugPrint('🔄 Inicjalizacja eRemiza...');
      
      // Ustaw dane logowania
      await _eremizaService.setCredentials(
        'korczes9@gmail.com',
        'M@gda1994',
      );
      
      // Zaloguj się
      await _eremizaService.login();
      debugPrint('✅ eRemiza - zalogowano');
      
      // Uruchom automatyczną synchronizację
      _eremizaService.startAutoSync();
      debugPrint('✅ eRemiza - auto-sync uruchomiony');
      
    } catch (e) {
      debugPrint('⚠️ Błąd inicjalizacji eRemiza: $e');
      // Nie przerywaj działania aplikacji jeśli eRemiza nie działa
    }
  }

  Future<void> _zaladujOstrzezenia() async {
    try {
      final ostrzezenia = await _serwisIMGW.pobierzWszystkieOstrzezenia();
      await _serwisIMGW.powiadomONowychOstrzezeniach(ostrzezenia);
      if (mounted) {
        setState(() {
          _ostrzezenia = ostrzezenia.where((o) => o.poziom != PoziomOstrzezenia.brak).toList();
        });
      }
    } catch (e) {
      debugPrint('Błąd ładowania ostrzeżeń: $e');
    }
  }

  Widget _buildSzkoleniaWygasajace() {
    final teraz = DateTime.now();
    final granica = teraz.add(const Duration(days: 30));
    final czyAdminLubModerator =
        widget.strazak.jestAdministratorem || widget.strazak.jestModeratorem;

    Query query = _firestore.collection('szkolenia');
    if (czyAdminLubModerator) {
      query = query
          .where('dataWaznosci',
              isGreaterThanOrEqualTo: Timestamp.fromDate(teraz))
          .where('dataWaznosci',
              isLessThanOrEqualTo: Timestamp.fromDate(granica));
    } else {
      query = query.where('strazakId', isEqualTo: widget.strazak.id);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final docs = snapshot.data!.docs;
        final szkolenia = docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
        final wygasajace = szkolenia.where((s) {
          final data = s['dataWaznosci'];
          if (data == null) return false;
          final dataWaznosci = (data as Timestamp).toDate();
          return dataWaznosci.isAfter(teraz) && dataWaznosci.isBefore(granica);
        }).toList();

        if (wygasajace.isEmpty) {
          return const SizedBox.shrink();
        }

        Widget buildLista(Map<String, String> strazakMap) {
          return Card(
            color: Colors.orange[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange[700], size: 28),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Szkolenia do odnowienia (30 dni)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...wygasajace.map((s) {
                    final dataWaznosci = (s['dataWaznosci'] as Timestamp).toDate();
                    final dni = dataWaznosci.difference(teraz).inDays;
                    final strazakId = s['strazakId'] as String?;
                    final strazakNazwa = strazakId != null
                        ? (strazakMap[strazakId] ?? 'Nieznany strażak')
                        : 'Nieznany strażak';
                    final tytul = czyAdminLubModerator
                        ? '$strazakNazwa • ${s['nazwa'] ?? 'Szkolenie'}'
                        : (s['nazwa'] ?? 'Szkolenie');

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '$tytul (ważne do: ${_formatujDate(dataWaznosci)} • $dni dni)',
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }

        if (!czyAdminLubModerator) {
          return buildLista({widget.strazak.id: widget.strazak.pelneImie});
        }

        return FutureBuilder<QuerySnapshot>(
          future: _firestore.collection('strazacy').get(),
          builder: (context, strazacySnapshot) {
            if (!strazacySnapshot.hasData) {
              return buildLista({});
            }
            final map = <String, String>{};
            for (var doc in strazacySnapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final imie = data['imie'] ?? '';
              final nazwisko = data['nazwisko'] ?? '';
              map[doc.id] = '$imie $nazwisko'.trim();
            }
            return buildLista(map);
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _discordMonitoring.stopMonitoring();
    _eremizaService.stopAutoSync();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'assets/images/logo_osp_kolumna.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.local_fire_department,
              color: Colors.white,
            ),
          ),
        ),
        title: Text('OSP Kolumna - ${widget.strazak.pelneImie}'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: StatusPoloczeniaWidget(),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await authService.logout();
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EkranLogowania(),
                    ),
                  );
                }
              } else if (value == 'theme') {
                final serwisMotywu =
                    Provider.of<SerwisMotywu>(context, listen: false);
                await serwisMotywu.przelaczMotyw();
              } else if (value == 'zatwierdzanie') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EkranZatwierdzaniaUzytkownikow(
                      aktualnyStrazak: widget.strazak,
                    ),
                  ),
                );
              } else if (value == 'o_aplikacji') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EkranOAplikacji(),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 20),
                    const SizedBox(width: 8),
                    Text(widget.strazak.pelneImie),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'role',
                enabled: false,
                child: Row(
                  children: [
                    const Icon(Icons.badge, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      widget.strazak.rola.nazwa,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'theme',
                child: Consumer<SerwisMotywu>(
                  builder: (context, serwis, _) => Row(
                    children: [
                      Icon(
                        serwis.czyCiemny ? Icons.light_mode : Icons.dark_mode,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(serwis.czyCiemny ? 'Tryb jasny' : 'Tryb ciemny'),
                    ],
                  ),
                ),
              ),
              const PopupMenuDivider(),
              // TYLKO DLA ADMINISTRATORÓW
              if (widget.strazak.rola.poziom >= 4) ...[
                const PopupMenuItem(
                  value: 'zatwierdzanie',
                  child: Row(
                    children: [
                      Icon(Icons.admin_panel_settings, size: 20),
                      SizedBox(width: 8),
                      Text('Zatwierdzanie użytkowników'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
              ],
              const PopupMenuItem(
                value: 'o_aplikacji',
                child: Row(
                  children: [
                    Icon(Icons.info, size: 20),
                    SizedBox(width: 8),
                    Text('O aplikacji'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Wyloguj', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Sekcja powitalna
          Card(
            color: Colors.red[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.red[700],
                    radius: 30,
                    child: Text(
                      '${widget.strazak.imie[0]}${widget.strazak.nazwisko[0]}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Witaj, ${widget.strazak.pelneImie}!',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.strazak.rola.nazwa,
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Widget z zagrożeniem pożarowym i silnym wiatrem
          const WidgetZagrozeniaPozarowego(),
          const SizedBox(height: 16),

          _buildSzkoleniaWygasajace(),
          const SizedBox(height: 16),

          // Widget z ostrzeżeniami IMGW (jeśli są)
          if (_ostrzezenia.isNotEmpty) ...[
            Card(
              color: Colors.orange[50],
              child: ExpansionTile(
                leading: Icon(Icons.warning_amber, color: Colors.orange[700], size: 32),
                title: Text(
                  'Ostrzeżenia IMGW (${_ostrzezenia.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  _ostrzezenia.first.tytul,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                children: _ostrzezenia.map((ostrzezenie) {
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.warning,
                      color: _kolorPoziomOstrzezenia(ostrzezenie.poziom),
                      size: 20,
                    ),
                    title: Text(
                      ostrzezenie.tytul,
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      '${_formatujDate(ostrzezenie.dataOd)} - ${_formatujDate(ostrzezenie.dataDo)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EkranZagrozen(strazak: widget.strazak),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Widget z nadchodzącymi wydarzeniami
          WidgetNadchodzaceWydarzenia(aktualnyStrazak: widget.strazak),

          // Menu główne
          ListTile(
            leading: const Icon(Icons.local_fire_department,
                color: Colors.red, size: 32),
            title: const Text('Wyjazdy', style: TextStyle(fontSize: 18)),
            subtitle: const Text('Historia wszystkich wyjazdów'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EkranListyWyjazdow(
                    aktualnyStrazak: widget.strazak,
                  ),
                ),
              );
            },
          ),
          const Divider(),

          // Przycisk dodawania wyjazdu dla Dowódcy, Moderatora i Administratora
          if (widget.strazak.rola.poziom >= 2)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EkranDodawaniaWyjazdu(
                        aktualnyStrazak: widget.strazak,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add_alert),
                label: const Text('DODAJ WYJAZD'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

          if (widget.strazak.rola.poziom >= 2) const Divider(),

          // Dostępność strażaków - widoczna dla wszystkich (od najniższej roli)
          ListTile(
            leading: const Icon(Icons.people_outline, color: Colors.green, size: 32),
            title: const Text('Dostępność strażaków', style: TextStyle(fontSize: 18)),
            subtitle: const Text('Daj znać czy jesteś dziś dostępny'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EkranDostepnosciStrazakow(
                    aktualnyStrazak: widget.strazak,
                  ),
                ),
              );
            },
          ),
          const Divider(),

          // Czat grupowy - widoczny dla wszystkich
          ListTile(
            leading: const Icon(Icons.chat, color: Colors.blue, size: 32),
            title: const Text('Czat jednostki', style: TextStyle(fontSize: 18)),
            subtitle: const Text('Pogadajmy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EkranCzatuGrupowego(
                    aktualnyStrazak: widget.strazak,
                  ),
                ),
              );
            },
          ),
          const Divider(),

          ListTile(
            leading:
                const Icon(Icons.directions_car, color: Colors.blue, size: 32),
            title:
                const Text('Wozy strażackie', style: TextStyle(fontSize: 18)),
            subtitle: const Text('Zarządzaj pojazdami'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EkranWozowStrazackich(
                    aktualnyStrazak: widget.strazak,
                  ),
                ),
              );
            },
          ),

          // Terminarz - widoczny dla wszystkich
          ListTile(
            leading: const Icon(Icons.calendar_month,
                color: Colors.purple, size: 32),
            title: const Text('Terminarz', style: TextStyle(fontSize: 18)),
            subtitle: const Text('Plan wydarzeń, szkoleń i ćwiczeń'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      EkranTerminarza(aktualnyStrazak: widget.strazak),
                ),
              );
            },
          ),
          const Divider(),

          // Raport ekwiwalentów - widoczny dla wszystkich
          ListTile(
            leading:
                const Icon(Icons.attach_money, color: Colors.green, size: 32),
            title: const Text('Przefiltruj wyjazdy',
                style: TextStyle(fontSize: 18)),
            subtitle: const Text('Podsumowanie twojej obecności na wyjazdach'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      EkranRaportuEkwiwalentow(aktualnyStrazak: widget.strazak),
                ),
              );
            },
          ),
          const Divider(),

          // Statystyki - widoczne dla wszystkich
          ListTile(
            leading: const Icon(Icons.bar_chart, color: Colors.blue, size: 32),
            title: const Text('Statystyki', style: TextStyle(fontSize: 18)),
            subtitle: const Text('podsumowanie'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      EkranStatystyk(aktualnyStrazak: widget.strazak),
                ),
              );
            },
          ),

          // Statystyki reakcji - widoczne dla wszystkich
          ListTile(
            leading: const Icon(Icons.speed, color: Colors.green, size: 32),
            title: const Text('Statystyki reakcji', style: TextStyle(fontSize: 18)),
            subtitle: const Text('Czas reakcji i ranking zaangażowania'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      EkranStatystykReakcji(aktualnyStrazak: widget.strazak),
                ),
              );
            },
          ),

          // Raporty PDF - tylko dla Administratora i Moderatora
          if (widget.strazak.rola.poziom >= 3)
            ListTile(
              leading:
                  const Icon(Icons.picture_as_pdf, color: Colors.red, size: 32),
              title: const Text('Raporty PDF', style: TextStyle(fontSize: 18)),
              subtitle: const Text('Generuj raporty do druku i wysyłania'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EkranRaportowPDF(),
                  ),
                );
              },
            ),

          // Mapa wyjazdów - NOWE
          ListTile(
            leading: const Icon(Icons.map, color: Colors.green, size: 32),
            title: const Text('Mapa wyjazdów', style: TextStyle(fontSize: 18)),
            subtitle: const Text('Historia wyjazdów na mapie'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EkranMapyWyjazdow(),
                ),
              );
            },
          ),

          // Wyje w powiecie - TYLKO DLA PRO
          if (widget.strazak.jestPro)
            ListTile(
              leading:
                  const Icon(Icons.public, color: Colors.deepPurple, size: 32),
              title:
                  const Text('Wyje w powiecie', style: TextStyle(fontSize: 18)),
              subtitle: const Text('Sprawdź co wyje w powiecie łaskim - funkcja dostępna dla wersji PRO'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'PRO',
                      style: TextStyle(
                        color: Colors.deepPurple[900],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EkranWyjazdowWPowiecie(
                      aktualnyStrazak: widget.strazak,
                    ),
                  ),
                );
              },
            ),
          const Divider(),

          // Powiadomienia Discord - tylko dla PRO
          if (widget.strazak.jestPro)
            ListTile(
              leading: Icon(Icons.discord, color: Colors.blue[700], size: 32),
              title: const Text('Powiadomienia Discord',
                  style: TextStyle(fontSize: 18)),
              subtitle: const Text('Zarządzaj alertami z Discord - funkcja PRO'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'PRO',
                      style: TextStyle(
                        color: Colors.deepPurple[900],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EkranMonitoringuDiscord(),
                  ),
                );
              },
            ),

          // Szkolenia - widoczne dla wszystkich
          ListTile(
            leading: const Icon(Icons.school, color: Colors.indigo, size: 32),
            title: const Text('Szkolenia', style: TextStyle(fontSize: 18)),
            subtitle: const Text('Szkolenia i uprawnienia'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EkranSzkolen(aktualnyStrazak: widget.strazak),
                ),
              );
            },
          ),

          // Sprzęt - tylko dla Administratora i Moderatora
          if (widget.strazak.rola.poziom >= 3)
            ListTile(
              leading:
                  const Icon(Icons.inventory_2, color: Colors.teal, size: 32),
              title: const Text('Sprzęt', style: TextStyle(fontSize: 18)),
              subtitle: const Text('Przeglądy'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EkranSprzetu(aktualnyStrazak: widget.strazak),
                  ),
                );
              },
            ),

          // Integracja eRemiza - tylko dla Administratora
          if (widget.strazak.jestAdministratorem)
            ListTile(
              leading: const Icon(Icons.download, color: Colors.orange, size: 32),
              title: const Text('Import z eRemiza',
                  style: TextStyle(fontSize: 18)),
              subtitle: const Text(
                  'Importuj alarmy z SK KP ze strony eRemiza'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EkranImportuEremiza(),
                  ),
                );
              },
            ),

          // Zgłoś problem - widoczne dla wszystkich
          ListTile(
            leading: const Icon(Icons.bug_report,
                color: Colors.deepOrange, size: 32),
            title: const Text('Zgłoś problem', style: TextStyle(fontSize: 18)),
            subtitle: const Text('Zgłoś błąd lub problem w aplikacji'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      EkranZglaszaniaProblemow(aktualnyStrazak: widget.strazak),
                ),
              );
            },
          ),

          // Opcje administratora
          if (widget.strazak.jestAdministratorem) ...[
            const Divider(thickness: 2, height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Panel Administratora',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings,
                  color: Colors.orange, size: 32),
              title: const Text('Zarządzaj strażakami',
                  style: TextStyle(fontSize: 18)),
              subtitle: const Text('Dodawaj i edytuj konta'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EkranZarzadzaniaStrazakami(
                      obecnyStrazak: widget.strazak,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_problem,
                  color: Colors.deepOrange, size: 32),
              title: const Text('Zgłoszenia problemów',
                  style: TextStyle(fontSize: 18)),
              subtitle: const Text('Przeglądaj zgłoszone problemy użytkowników'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        EkranZglaszaniaProblemow(aktualnyStrazak: widget.strazak),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading:
                  const Icon(Icons.assessment, color: Colors.purple, size: 32),
              title: const Text('Raporty', style: TextStyle(fontSize: 18)),
              subtitle: const Text('Historia i statystyki'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ],

          // Opcje dla Moderatora
          if (widget.strazak.jestModeratorem &&
              !widget.strazak.jestAdministratorem) ...[
            const Divider(thickness: 2, height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Panel Moderatora',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _kolorPoziomOstrzezenia(PoziomOstrzezenia poziom) {
    switch (poziom) {
      case PoziomOstrzezenia.zolty:
        return Colors.amber[600]!;
      case PoziomOstrzezenia.pomaranczowy:
        return Colors.orange[700]!;
      case PoziomOstrzezenia.czerwony:
        return Colors.red[700]!;
      default:
        return Colors.grey;
    }
  }

  String _formatujDate(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}.${data.month.toString().padLeft(2, '0')}';
  }
}
