import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wyjazd.dart';
import '../models/strazak.dart';
import '../models/sprzet.dart';

/// Serwis do generowania raportów PDF
class SerwisRaportowPDF {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Generuj raport miesięczny ekwiwalentów
  Future<void> generujRaportEkwiwalentow({
    required DateTime miesiac,
  }) async {
    // Załaduj font obsługujący polskie znaki
    final polishFont = await PdfGoogleFonts.robotoRegular();
    final polishFontBold = await PdfGoogleFonts.robotoBold();
    
    final poczatekMiesiaca = DateTime(miesiac.year, miesiac.month, 1);
    final koniecMiesiaca = DateTime(miesiac.year, miesiac.month + 1, 0);

    // Pobierz wyjazdy z miesiąca
    final wyjazdySnapshot = await _firestore
        .collection('wyjazdy')
        .where('dataWyjazdu',
            isGreaterThanOrEqualTo: Timestamp.fromDate(poczatekMiesiaca))
        .where('dataWyjazdu',
            isLessThanOrEqualTo: Timestamp.fromDate(koniecMiesiaca))
        .get();

    final wyjazdy = wyjazdySnapshot.docs
        .map((doc) => Wyjazd.fromMap(doc.data(), doc.id))
        .toList();

    // Pobierz wszystkich strażaków
    final strazacySnapshot = await _firestore.collection('strazacy').get();
    final strazacy = strazacySnapshot.docs
        .map((doc) => Strazak.fromMap(doc.data(), doc.id))
        .toList();

    // Oblicz ekwiwalenty per strażak
    final ekwiwalentyPerStrazak = <String, double>{};
    final wyjazdyPerStrazak = <String, int>{};

    for (var wyjazd in wyjazdy) {
      if (wyjazd.ekwiwalent > 0) {
        // Uwzględnij wszystkich uczestników
        for (var strazakId in wyjazd.strazacyIds) {
          ekwiwalentyPerStrazak[strazakId] =
              (ekwiwalentyPerStrazak[strazakId] ?? 0) + wyjazd.ekwiwalent;
          wyjazdyPerStrazak[strazakId] =
              (wyjazdyPerStrazak[strazakId] ?? 0) + 1;
        }
      }
    }

    // Twórz PDF
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: polishFont,
          bold: polishFontBold,
        ),
        build: (context) => [
          // Nagłówek
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'RAPORT MIESIĘCZNY EKWIWALENTÓW',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'OSP Kolumna',
                  style: const pw.TextStyle(fontSize: 14),
                ),
                pw.Text(
                  'Okres: ${_formatujMiesiac(miesiac)}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Divider(thickness: 2),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // Podsumowanie
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildStatPdf('Liczba wyjazdów', wyjazdy.length.toString()),
                _buildStatPdf(
                  'Suma ekwiwalentów',
                  '${ekwiwalentyPerStrazak.values.fold<double>(0, (sum, val) => sum + val).toStringAsFixed(2)} PLN',
                ),
                _buildStatPdf(
                  'Liczba strażaków',
                  ekwiwalentyPerStrazak.length.toString(),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // Tabela ekwiwalentów
          pw.Text(
            'Ekwiwalenty według strażaków',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),

          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey),
            children: [
              // Nagłówek tabeli
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _buildTableCell('Lp.', bold: true),
                  _buildTableCell('Imię i nazwisko', bold: true),
                  _buildTableCell('Liczba wyjazdów', bold: true),
                  _buildTableCell('Ekwiwalent (PLN)', bold: true),
                ],
              ),

              // Wiersze danych
              ...ekwiwalentyPerStrazak.entries
                  .toList()
                  .asMap()
                  .entries
                  .map((entry) {
                final index = entry.key;
                final strazakId = entry.value.key;
                final ekwiwalent = entry.value.value;

                final strazak = strazacy.firstWhere(
                  (s) => s.id == strazakId,
                  orElse: () => Strazak(
                    id: '',
                    imie: 'Nieznany',
                    nazwisko: '',
                    email: '',
                    numerTelefonu: '',
                  ),
                );

                return pw.TableRow(
                  children: [
                    _buildTableCell('${index + 1}'),
                    _buildTableCell(strazak.pelneImie),
                    _buildTableCell('${wyjazdyPerStrazak[strazakId] ?? 0}'),
                    _buildTableCell(ekwiwalent.toStringAsFixed(2)),
                  ],
                );
              }),

              // Suma
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableCell('', bold: true),
                  _buildTableCell('RAZEM:', bold: true),
                  _buildTableCell(
                    wyjazdyPerStrazak.values
                        .fold<int>(0, (sum, val) => sum + val)
                        .toString(),
                    bold: true,
                  ),
                  _buildTableCell(
                    ekwiwalentyPerStrazak.values
                        .fold<double>(0, (sum, val) => sum + val)
                        .toStringAsFixed(2),
                    bold: true,
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 20),
        ],
      ),
    );

    // Wyświetl podgląd i pozwól na drukowanie/zapisywanie
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Raport_ekwiwalentow_${miesiac.year}_${miesiac.month}.pdf',
    );
  }

  /// Generuj listę wyjazdów z okresu
  Future<void> generujListeWyjazdow({
    required DateTime od,
    required DateTime doDaty,
  }) async {
    // Załaduj font obsługujący polskie znaki
    final polishFont = await PdfGoogleFonts.robotoRegular();
    final polishFontBold = await PdfGoogleFonts.robotoBold();
    
    final wyjazdySnapshot = await _firestore
        .collection('wyjazdy')
        .where('dataWyjazdu', isGreaterThanOrEqualTo: Timestamp.fromDate(od))
        .where('dataWyjazdu', isLessThanOrEqualTo: Timestamp.fromDate(doDaty))
        .orderBy('dataWyjazdu', descending: true)
        .get();

    final wyjazdy = wyjazdySnapshot.docs
        .map((doc) => Wyjazd.fromMap(doc.data(), doc.id))
        .toList();

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: polishFont,
          bold: polishFontBold,
        ),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'LISTA WYJAZDÓW',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text('OSP Kolumna'),
                pw.Text(
                  'Okres: ${_formatujDate(od)} - ${_formatujDate(doDaty)}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Divider(thickness: 2),
              ],
            ),
          ),

          pw.SizedBox(height: 10),

          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey),
            columnWidths: {
              0: const pw.FlexColumnWidth(1),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(3),
              3: const pw.FlexColumnWidth(2),
              4: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _buildTableCell('Lp.', bold: true),
                  _buildTableCell('Data', bold: true),
                  _buildTableCell('Lokalizacja', bold: true),
                  _buildTableCell('Kategoria', bold: true),
                  _buildTableCell('Osób', bold: true),
                ],
              ),
              ...wyjazdy.asMap().entries.map((entry) {
                final index = entry.key;
                final wyjazd = entry.value;
                return pw.TableRow(
                  children: [
                    _buildTableCell('${index + 1}'),
                    _buildTableCell(_formatujDate(wyjazd.dataWyjazdu)),
                    _buildTableCell(wyjazd.lokalizacja),
                    _buildTableCell(wyjazd.kategoria.nazwa),
                    _buildTableCell('${wyjazd.strazacyIds.length}'),
                  ],
                );
              }),
            ],
          ),

          pw.SizedBox(height: 20),
          pw.Text('Razem wyjazdów: ${wyjazdy.length}'),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Lista_wyjazdow_${od.year}_${od.month}_${od.day}.pdf',
    );
  }

  /// Generuj wykaz inwentaryzacji sprzętu
  Future<void> generujInwentaryzacjeSprzetu() async {
    // Załaduj font obsługujący polskie znaki
    final polishFont = await PdfGoogleFonts.robotoRegular();
    final polishFontBold = await PdfGoogleFonts.robotoBold();
    
    final sprzetSnapshot =
        await _firestore.collection('sprzet').orderBy('kategoria').get();

    final sprzet = sprzetSnapshot.docs
        .map((doc) => Sprzet.fromMap(doc.data(), doc.id))
        .toList();

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        orientation: pw.PageOrientation.landscape,
        theme: pw.ThemeData.withFont(
          base: polishFont,
          bold: polishFontBold,
        ),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'INWENTARYZACJA SPRZĘTU',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text('OSP Kolumna'),
                pw.Text('Data: ${_formatujDate(DateTime.now())}'),
                pw.Divider(thickness: 2),
              ],
            ),
          ),

          pw.SizedBox(height: 10),

          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _buildTableCell('Lp.', bold: true),
                  _buildTableCell('Nazwa', bold: true),
                  _buildTableCell('Kategoria', bold: true),
                  _buildTableCell('Nr inw.', bold: true),
                  _buildTableCell('Status', bold: true),
                  _buildTableCell('Data zakupu', bold: true),
                ],
              ),
              ...sprzet.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return pw.TableRow(
                  children: [
                    _buildTableCell('${index + 1}'),
                    _buildTableCell(item.nazwa),
                    _buildTableCell(item.kategoria.nazwa),
                    _buildTableCell(item.numerInwentarzowy ?? '-'),
                    _buildTableCell(item.status.nazwa),
                    _buildTableCell(
                      item.dataZakupu != null
                          ? _formatujDate(item.dataZakupu!)
                          : '-',
                    ),
                  ],
                );
              }),
            ],
          ),

          pw.SizedBox(height: 20),
          pw.Text('Razem pozycji: ${sprzet.length}'),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Inwentaryzacja_sprzetu_${DateTime.now().year}.pdf',
    );
  }

  // Pomocnicze metody

  pw.Widget _buildStatPdf(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  pw.Widget _buildTableCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 10,
        ),
      ),
    );
  }

  String _formatujDate(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}.${data.month.toString().padLeft(2, '0')}.${data.year}';
  }

  String _formatujMiesiac(DateTime data) {
    const miesiace = [
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
      'Grudzień'
    ];
    return '${miesiace[data.month - 1]} ${data.year}';
  }
}
