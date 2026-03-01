import 'package:flutter/material.dart';
import '../services/serwis_raportow_pdf.dart';

enum TypOkresuRaportu { miesiac, kwartal, rok }

class EkranRaportowPDF extends StatefulWidget {
  const EkranRaportowPDF({super.key});

  @override
  State<EkranRaportowPDF> createState() => _EkranRaportowPDFState();
}

class _EkranRaportowPDFState extends State<EkranRaportowPDF> {
  final _serwisPDF = SerwisRaportowPDF();
  bool _generuje = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raporty PDF'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildRaportCard(
            tytul: 'Raport miesięczny ekwiwalentów',
            opis: 'Zestawienie ekwiwalentów za wybrany miesiąc',
            ikona: Icons.attach_money,
            kolor: Colors.green,
            onTap: () => _pokazDialogEkwiwalentow(),
          ),
          const SizedBox(height: 16),
          _buildRaportCard(
            tytul: 'Lista wyjazdów z okresu',
            opis: 'Szczegółowa lista wszystkich wyjazdów w określonym czasie',
            ikona: Icons.local_fire_department,
            kolor: Colors.red,
            onTap: () => _pokazDialogListyWyjazdow(),
          ),
          const SizedBox(height: 16),
          _buildRaportCard(
            tytul: 'Inwentaryzacja sprzętu',
            opis: 'Pełna inwentaryzacja sprzętu OSP',
            ikona: Icons.inventory,
            kolor: Colors.blue,
            onTap: () => _generujInwentaryzacje(),
          ),
        ],
      ),
    );
  }

  Widget _buildRaportCard({
    required String tytul,
    required String opis,
    required IconData ikona,
    required Color kolor,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: _generuje ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: kolor.withOpacity(0.2),
                child: Icon(ikona, color: kolor, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tytul,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      opis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _pokazDialogEkwiwalentow() {
    DateTime wybranaData = DateTime(DateTime.now().year, DateTime.now().month);
    TypOkresuRaportu typOkresu = TypOkresuRaportu.miesiac;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Raport ekwiwalentów'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<TypOkresuRaportu>(
                      value: typOkresu,
                      decoration: const InputDecoration(
                        labelText: 'Okres',
                        prefixIcon: Icon(Icons.filter_alt),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: TypOkresuRaportu.miesiac,
                          child: Text('Miesiąc'),
                        ),
                        DropdownMenuItem(
                          value: TypOkresuRaportu.kwartal,
                          child: Text('Kwartał'),
                        ),
                        DropdownMenuItem(
                          value: TypOkresuRaportu.rok,
                          child: Text('Rok'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setStateDialog(() => typOkresu = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('Okres referencyjny'),
                subtitle: Text(_opisOkresuDlaUI(typOkresu, wybranaData)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final wybrana = await showDatePicker(
                    context: context,
                    initialDate: wybranaData,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (wybrana != null) {
                    setStateDialog(() {
                      wybranaData = wybrana;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Anuluj'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _generujRaportEkwiwalentow(typOkresu, wybranaData);
              },
              child: const Text('Generuj PDF'),
            ),
          ],
        ),
      ),
    );
  }

  void _pokazDialogListyWyjazdow() {
    DateTime od = DateTime.now().subtract(const Duration(days: 30));
    DateTime doDaty = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Lista wyjazdów'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Od'),
                subtitle: Text(_formatujDate(od)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final wybrana = await showDatePicker(
                    context: context,
                    initialDate: od,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (wybrana != null) {
                    setStateDialog(() => od = wybrana);
                  }
                },
              ),
              ListTile(
                title: const Text('Do'),
                subtitle: Text(_formatujDate(doDaty)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final wybrana = await showDatePicker(
                    context: context,
                    initialDate: doDaty,
                    firstDate: od,
                    lastDate: DateTime.now(),
                  );
                  if (wybrana != null) {
                    setStateDialog(() => doDaty = wybrana);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Anuluj'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _generujListeWyjazdow(od, doDaty);
              },
              child: const Text('Generuj PDF'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generujRaportEkwiwalentow(
      TypOkresuRaportu typ, DateTime referencyjna) async {
    // Wyznacz zakres dat na podstawie wybranego typu okresu
    late DateTime od;
    late DateTime doDaty;
    late String opisOkresu;

    switch (typ) {
      case TypOkresuRaportu.miesiac:
        od = DateTime(referencyjna.year, referencyjna.month, 1);
        doDaty = DateTime(referencyjna.year, referencyjna.month + 1, 0);
        opisOkresu =
            '${_nazwyMiesiecy[referencyjna.month - 1]} ${referencyjna.year}';
        break;
      case TypOkresuRaportu.kwartal:
        final kwartal = ((referencyjna.month - 1) ~/ 3) + 1;
        final startMonth = (kwartal - 1) * 3 + 1;
        final endMonth = startMonth + 2;
        od = DateTime(referencyjna.year, startMonth, 1);
        doDaty = DateTime(referencyjna.year, endMonth + 1, 0);
        opisOkresu = 'Kwartał $kwartal ${referencyjna.year}';
        break;
      case TypOkresuRaportu.rok:
        od = DateTime(referencyjna.year, 1, 1);
        doDaty = DateTime(referencyjna.year, 12, 31);
        opisOkresu = 'Rok ${referencyjna.year}';
        break;
    }

    setState(() => _generuje = true);
    try {
      await _serwisPDF.generujRaportEkwiwalentow(
        od: od,
        doDaty: doDaty,
        opisOkresu: opisOkresu,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generuje = false);
    }
  }

  Future<void> _generujListeWyjazdow(DateTime od, DateTime doDaty) async {
    setState(() => _generuje = true);
    try {
      await _serwisPDF.generujListeWyjazdow(od: od, doDaty: doDaty);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generuje = false);
    }
  }

  Future<void> _generujInwentaryzacje() async {
    setState(() => _generuje = true);
    try {
      await _serwisPDF.generujInwentaryzacjeSprzetu();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generuje = false);
    }
  }

  String _formatujDate(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}.${data.month.toString().padLeft(2, '0')}.${data.year}';
  }

  List<String> get _nazwyMiesiecy => const [
    'Styczeń',
    'Luty',
    'Marzec',
    'Kwiecień',
    'Maj',
    'Czerwiec',
    'Lipiec',
    'Sierpień',
    'Wrzesień',
    'Październik',
    'Listopad',
    'Grudzień',
  ];

  String _opisOkresuDlaUI(TypOkresuRaportu typ, DateTime data) {
    switch (typ) {
      case TypOkresuRaportu.miesiac:
        return '${_nazwyMiesiecy[data.month - 1]} ${data.year}';
      case TypOkresuRaportu.kwartal:
        final kwartal = ((data.month - 1) ~/ 3) + 1;
        return 'Kwartał $kwartal ${data.year}';
      case TypOkresuRaportu.rok:
        return 'Rok ${data.year}';
    }
  }
}
