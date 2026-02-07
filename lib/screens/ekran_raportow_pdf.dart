import 'package:flutter/material.dart';
import '../services/serwis_raportow_pdf.dart';

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
    DateTime wybranyMiesiac = DateTime(DateTime.now().year, DateTime.now().month);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Raport miesięczny ekwiwalentów'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Miesiąc'),
                subtitle: Text(
                  '${_nazwyMiesiecy[wybranyMiesiac.month - 1]} ${wybranyMiesiac.year}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final wybrana = await showDatePicker(
                    context: context,
                    initialDate: wybranyMiesiac,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (wybrana != null) {
                    setStateDialog(() {
                      wybranyMiesiac = wybrana;
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
                _generujRaportEkwiwalentow(wybranyMiesiac);
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

  Future<void> _generujRaportEkwiwalentow(DateTime miesiac) async {
    setState(() => _generuje = true);
    try {
      await _serwisPDF.generujRaportEkwiwalentow(
        miesiac: miesiac,
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
}
