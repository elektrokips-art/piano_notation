import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'app_settings.dart';
import 'note_models.dart';
import 'notation_file.dart';
import 'staff_painter.dart';

const _pdfTitle = {
  AppLanguage.ru: 'Партитура',
  AppLanguage.uz: 'Partitura',
  AppLanguage.en: 'Score',
};

const _measuresWord = {
  AppLanguage.ru: 'такт(ов)',
  AppLanguage.uz: 'oʻlchov',
  AppLanguage.en: 'measures',
};

/// Рендерит такты в offscreen-картинку (через тот же StaffPainter)
/// и вставляет её в PDF-документ формата A4. Текст — шрифтом DejaVu Sans
/// (поддерживает кириллицу и узбекскую латиницу), заголовок — на языке [lang].
///
/// Использование:
/// ```dart
/// final bytes = await renderStaffToPdf(measures: measures, bpm: 90, lang: AppLanguage.ru);
/// await Printing.sharePdf(bytes: bytes, filename: 'melody.pdf');
/// // или Printing.layoutPdf(onLayout: (_) async => bytes);
/// ```
Future<Uint8List> renderStaffToPdf({
  required List<List<QuantizedNote>> measures,
  required int bpm,
  AppLanguage lang = AppLanguage.ru,
  bool grandStaff = false,
}) async {
  final size = StaffPainter.computeSize(measures.length, grandStaff: grandStaff);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  StaffPainter(measures: measures, bpm: bpm, grandStaff: grandStaff).paint(canvas, size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.ceil(), size.height.ceil());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final pngBytes = byteData!.buffer.asUint8List();

  final regularFont = pw.Font.ttf(
      (await rootBundle.load('assets/fonts/DejaVuSans.ttf')).buffer.asByteData());
  final boldFont = pw.Font.ttf(
      (await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf')).buffer.asByteData());

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
  );
  final pwImage = pw.MemoryImage(pngBytes);

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            _pdfTitle[lang]!,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text('$bpm BPM · 4/4 · ${measures.length} ${_measuresWord[lang]}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 12),
          pw.Image(pwImage, fit: pw.BoxFit.contain),
        ],
      ),
    ),
  );

  // Вкладываем сами ноты (JSON) внутрь PDF — так один и тот же файл можно
  // и распечатать, и открыть заново в приложении для режима «играть по
  // нотам» (см. notation_file.dart и example_usage.dart _openPiece).
  PdfaAttachedFiles(doc.document, [
    PdfaAttachedFile(
      name: notationFileMarker,
      data: jsonEncode(notationToJson(measures, bpm)),
      subType: '/application/json',
      AFRelationship: '/Data',
    ),
  ]);

  return doc.save();
}
