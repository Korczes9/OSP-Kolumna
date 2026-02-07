import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/strazak.dart';

/// Ekran wyje w powiecie z integracją Discord webhook
/// Dostępny tylko dla użytkowników z rolą Pro i wyżej
class EkranWyjazdowWPowiecie extends StatefulWidget {
  final Strazak aktualnyStrazak;

  const EkranWyjazdowWPowiecie({super.key, required this.aktualnyStrazak});

  @override
  State<EkranWyjazdowWPowiecie> createState() => _EkranWyjazdowWPowiecieState();
}

class _EkranWyjazdowWPowiecieState extends State<EkranWyjazdowWPowiecie> {
    static const String _discordBotToken =
      String.fromEnvironment('DISCORD_BOT_TOKEN', defaultValue: '');
  static const String _discordChannelId = '1193142209470533733';

  List<Map<String, dynamic>> _wiadomosci = [];
  bool _ladowanieWiadomosci = true;
  String? _bladPobierania;

  @override
  void initState() {
    super.initState();
    _pobierzWiadomosciZDiscorda();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Pobiera wiadomości z kanału Discord
  Future<void> _pobierzWiadomosciZDiscorda() async {
    setState(() {
      _ladowanieWiadomosci = true;
      _bladPobierania = null;
    });

    try {
      debugPrint('🔍 Discord: Próba pobrania wiadomości...');
      debugPrint('📡 URL: https://discord.com/api/v10/channels/$_discordChannelId/messages?limit=50');
      
      final response = await http.get(
        Uri.parse('https://discord.com/api/v10/channels/$_discordChannelId/messages?limit=50'),
        headers: {
          'Authorization': 'Bot $_discordBotToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      
      debugPrint('📊 Discord Response: ${response.statusCode}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        debugPrint('✅ Discord: Pobrano ${data.length} wiadomości');
        setState(() {
          _wiadomosci = data.cast<Map<String, dynamic>>();
          _ladowanieWiadomosci = false;
          _bladPobierania = null;
        });
      } else if (response.statusCode == 403) {
        debugPrint('❌ Discord: Błąd 403 - brak uprawnień');
        try {
          final error = json.decode(response.body);
          setState(() {
            _ladowanieWiadomosci = false;
            _bladPobierania = 'Bot nie ma uprawnień do odczytu wiadomości.\nKod błędu: ${error['code'] ?? 'nieznany'}\nWiadomość: ${error['message'] ?? 'brak'}';
          });
        } catch (_) {
          setState(() {
            _ladowanieWiadomosci = false;
            _bladPobierania = 'Bot nie ma uprawnień do odczytu wiadomości (403).\nSprawdź token bota i uprawnienia w Discord Developer Portal.';
          });
        }
      } else if (response.statusCode == 401) {
        debugPrint('❌ Discord: Błąd 401 - nieprawidłowy token');
        setState(() {
          _ladowanieWiadomosci = false;
          _bladPobierania = 'Nieprawidłowy token bota (401).\nToken może być wygasły lub niepoprawny.\nWygeneruj nowy token w Discord Developer Portal.';
        });
      } else {
        debugPrint('❌ Discord: Błąd ${response.statusCode}');
        debugPrint('Body: ${response.body}');
        setState(() {
          _ladowanieWiadomosci = false;
          _bladPobierania = 'Błąd ${response.statusCode}: ${response.body.length < 200 ? response.body : response.body.substring(0, 200)}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ladowanieWiadomosci = false;
        _bladPobierania = 'Błąd połączenia: ${e.toString()}';
      });
    }
  }

  /// Formatuje datę do czytelnej formy
  String _formatujDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} o ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Sprawdź, czy użytkownik ma rolę Pro
    if (!widget.aktualnyStrazak.jestPro) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Wyje w powiecie'),
          backgroundColor: Colors.red[700],
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 20),
              Text(
                'Brak dostępu',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Ta funkcja jest dostępna tylko dla użytkowników\nz rolą Pro lub wyższą.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wyje w powiecie'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _pobierzWiadomosciZDiscorda,
            tooltip: 'Odśwież wiadomości',
          ),
        ],
      ),
      body: Column(
        children: [
          // Informacja o funkcji
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Row(
              children: [
                Icon(Icons.discord, color: Colors.blue[700], size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Wiadomości z kanału Discord',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Wiadomości z Discorda
          Expanded(
            child: _ladowanieWiadomosci
                ? const Center(child: CircularProgressIndicator())
                : _bladPobierania != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline,
                                  size: 64, color: Colors.red[400]),
                              const SizedBox(height: 16),
                              const Text(
                                'Błąd pobierania wiadomości',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _bladPobierania!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: _pobierzWiadomosciZDiscorda,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Spróbuj ponownie'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[700],
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _wiadomosci.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox,
                                    size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'Brak wiadomości',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                              itemCount: _wiadomosci.length,
                              itemBuilder: (context, index) {
                                final msg = _wiadomosci[index];
                                final content = msg['content'] as String? ?? '';
                                final embeds = msg['embeds'] as List<dynamic>? ?? [];
                                final timestamp = msg['timestamp'] as String?;
                                final author = msg['author'] as Map<String, dynamic>?;
                                final authorName = author?['username'] as String? ?? 'Nieznany';

                                // Parsuj timestamp
                                DateTime? msgTime;
                                if (timestamp != null) {
                                  try {
                                    msgTime = DateTime.parse(timestamp);
                                  } catch (e) {
                                    // ignore
                                  }
                                }

                                // Debug: wypisz informacje o wiadomości
                                debugPrint('💬 Wiadomość #$index: content="$content", embeds=${embeds.length}, author=$authorName');

                                // Jeśli wiadomość ma embedy
                                if (embeds.isNotEmpty) {
                                  final embed = embeds.first as Map<String, dynamic>;
                                  final title = embed['title'] as String? ?? '';
                                  final description = embed['description'] as String? ?? '';
                                  final fields = embed['fields'] as List<dynamic>? ?? [];

                                  // Zbierz całą dostępną treść
                                  final czesci = <String>[];
                                  if (content.isNotEmpty) czesci.add(content);
                                  if (title.isNotEmpty) czesci.add(title);
                                  if (description.isNotEmpty) czesci.add(description);
                                  
                                  final glownyTekst = czesci.isNotEmpty ? czesci.join(' • ') : 'Brak treści';

                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.red[700],
                                        child: const Icon(
                                          Icons.local_fire_department,
                                          color: Colors.white,
                                        ),
                                      ),
                                      title: Text(
                                        glownyTekst,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          Text(
                                            'Wysłane przez: $authorName',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.blue[800],
                                            ),
                                          ),
                                          if (fields.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            ...fields.map((field) {
                                              final fieldData =
                                                  field as Map<String, dynamic>;
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 4),
                                                child: Text(
                                                  '${fieldData['name']}: ${fieldData['value']}',
                                                  style: const TextStyle(
                                                      fontSize: 12),
                                                ),
                                              );
                                            }),
                                          ],
                                          if (msgTime != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatujDate(msgTime),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      isThreeLine: true,
                                    ),
                                  );
                                }

                                // Wiadomość bez embedów - zwykła wiadomość tekstowa
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blue[700],
                                      child: const Icon(
                                        Icons.message,
                                        color: Colors.white,
                                      ),
                                    ),
                                    title: Text(
                                      authorName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(
                                          content.isNotEmpty ? content : '(brak treści)',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                        if (msgTime != null) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            _formatujDate(msgTime),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    isThreeLine: true,
                                  ),
                                );
                              },
                            ),
          ),
        ],
      ),
    );
  }
}
