import 'package:flutter/material.dart';
import 'note_models.dart';
import 'quantizer.dart' show ticksPerMeasure;
import 'staff_position.dart';

class StaffPainter extends CustomPainter {
  final List<List<QuantizedNote>> measures;
  final int bpm;

  StaffPainter({required this.measures, required this.bpm});

  static const double spaceHeight = 12.0; // расстояние между линиями стана
  static const double stepPx = spaceHeight / 2;
  static const double tickWidth = 17.0;
  static const int measuresPerLine = 3;
  static const double leftMargin = 78.0;
  static const double lineGap = 108.0;
  static const double topMargin = 46.0;

  late final Paint _inkPaint = Paint()
    ..color = const Color(0xFF23222A)
    ..strokeWidth = 1
    ..style = PaintingStyle.stroke;

  late final Paint _inkFill = Paint()..color = const Color(0xFF23222A);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFF6F0E2),
    );

    final lineCount = (measures.length / measuresPerLine).ceil();
    final measureWidth = ticksPerMeasure * tickWidth;

    for (var li = 0; li < lineCount; li++) {
      final staffBottomY = topMargin + li * lineGap + spaceHeight * 4;

      // 5 линий стана
      for (var l = 0; l < 5; l++) {
        final y = staffBottomY - l * spaceHeight;
        canvas.drawLine(
          Offset(leftMargin - 10, y),
          Offset(leftMargin + measuresPerLine * measureWidth, y),
          _inkPaint,
        );
      }

      // скрипичный ключ
      _drawText(canvas, '𝄞', leftMargin - 70, staffBottomY + 8, 48);

      // размер такта — только на первой строке
      if (li == 0) {
        _drawText(canvas, '4', leftMargin - 26, staffBottomY - spaceHeight * 2 + 10, 20);
        _drawText(canvas, '4', leftMargin - 26, staffBottomY + 8, 20);
      }

      final lineMeasures = measures.skip(li * measuresPerLine).take(measuresPerLine);
      var mx = leftMargin;
      for (final measure in lineMeasures) {
        var tx = mx;
        for (final item in measure) {
          final w = item.durationTicks * tickWidth;
          final cx = tx + w / 2;
          if (item.isRest) {
            _drawRest(canvas, cx, staffBottomY - spaceHeight * 2, item.durationTicks);
          } else {
            _drawNote(canvas, cx, staffBottomY, item.midiPitches, item.durationTicks);
          }
          tx += w;
        }
        mx += measureWidth;
        canvas.drawLine(
          Offset(mx, staffBottomY),
          Offset(mx, staffBottomY - spaceHeight * 4),
          _inkPaint,
        );
      }
    }
  }

  // Рисует ноту или аккорд: одна головка на каждую высоту, общий штиль.
  void _drawNote(
      Canvas canvas, double cx, double staffBottomY, List<int> pitches, int durTicks) {
    final positions = pitches.map(staffPositionFor).toList();
    final cys = [for (final p in positions) staffBottomY - p.step * stepPx];
    final open = durTicks >= 8; // половинная/целая — незакрашенная головка
    const rx = 6.5, ry = 5.0;

    for (var idx = 0; idx < positions.length; idx++) {
      final pos = positions[idx];
      final cy = cys[idx];

      // добавочные линейки, если нота выше/ниже стана
      if (pos.step < 0) {
        for (var s = -2; s >= pos.step; s -= 2) {
          final ly = staffBottomY - s * stepPx;
          canvas.drawLine(Offset(cx - 10, ly), Offset(cx + 10, ly), _inkPaint);
        }
      } else if (pos.step > 8) {
        for (var s = 10; s <= pos.step; s += 2) {
          final ly = staffBottomY - s * stepPx;
          canvas.drawLine(Offset(cx - 10, ly), Offset(cx + 10, ly), _inkPaint);
        }
      }

      // диез
      if (pos.sharp) {
        _drawText(canvas, '♯', cx - 18, cy + 5, 15);
      }

      // головка ноты (эллипс с небольшим наклоном)
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(-0.34);
      final headRect = Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2);
      if (open) {
        canvas.drawOval(headRect, Paint()..color = const Color(0xFFF6F0E2));
        canvas.drawOval(
          headRect,
          Paint()
            ..color = const Color(0xFF23222A)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      } else {
        canvas.drawOval(headRect, _inkFill);
      }
      canvas.restore();
    }

    if (durTicks == 16) return; // целая нота — без штиля

    final avgStep =
        positions.map((p) => p.step).reduce((a, b) => a + b) / positions.length;
    final stemUp = avgStep < 4;
    final stemX = cx + (stemUp ? rx - 1 : -(rx - 1));
    const stemLen = 34.0;
    final minCy = cys.reduce((a, b) => a < b ? a : b);
    final maxCy = cys.reduce((a, b) => a > b ? a : b);
    // штиль тянется от дальнего от него края аккорда с запасом stemLen
    final stemBaseY = stemUp ? maxCy : minCy;
    final stemTopY = stemUp ? minCy - stemLen : maxCy + stemLen;

    canvas.drawLine(
      Offset(stemX, stemBaseY),
      Offset(stemX, stemTopY),
      Paint()
        ..color = const Color(0xFF23222A)
        ..strokeWidth = 1.4,
    );

    final flags = durTicks == 1 ? 2 : (durTicks == 2 ? 1 : 0);
    for (var f = 0; f < flags; f++) {
      final fy = stemTopY + (stemUp ? f * 7 : -f * 7);
      final path = Path()..moveTo(stemX, fy);
      if (stemUp) {
        path.quadraticBezierTo(stemX + 10, fy + 6, stemX + 2, fy + 16);
      } else {
        path.quadraticBezierTo(stemX - 10, fy - 6, stemX - 2, fy - 16);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF23222A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  void _drawRest(Canvas canvas, double cx, double cy, int durTicks) {
    if (durTicks >= 16) {
      canvas.drawRect(Rect.fromLTWH(cx - 6, cy - 4, 12, 5), _inkFill);
    } else if (durTicks >= 8) {
      canvas.drawRect(Rect.fromLTWH(cx - 6, cy + 4, 12, 5), _inkFill);
    } else if (durTicks >= 4) {
      final path = Path()
        ..moveTo(cx - 3, cy - 10)
        ..lineTo(cx + 3, cy - 2)
        ..lineTo(cx - 3, cy + 4)
        ..lineTo(cx + 3, cy + 10);
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF23222A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    } else {
      canvas.drawLine(
        Offset(cx + 3, cy - 9),
        Offset(cx - 3, cy + 9),
        Paint()
          ..color = const Color(0xFF23222A)
          ..strokeWidth = 1.6,
      );
      canvas.drawCircle(Offset(cx + 4, cy - 8), 2.5, _inkFill);
      if (durTicks == 1) {
        canvas.drawCircle(Offset(cx + 1, cy - 2), 2.5, _inkFill);
      }
    }
  }

  void _drawText(Canvas canvas, String text, double x, double y, double fontSize) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xFF23222A),
          fontSize: fontSize,
          fontFamily: 'Georgia',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(x, y - painter.height));
  }

  /// Итоговый размер канвы под текущее число тактов — используй в
  /// SizedBox/CustomPaint(size: ...) перед рендером.
  static Size computeSize(int measureCount) {
    final lineCount = (measureCount / measuresPerLine).ceil().clamp(1, 999);
    final measureWidth = ticksPerMeasure * tickWidth;
    final width = leftMargin + measuresPerLine * measureWidth + 30;
    final height = topMargin + lineCount * lineGap + 40;
    return Size(width, height);
  }

  @override
  bool shouldRepaint(covariant StaffPainter oldDelegate) {
    return oldDelegate.measures != measures || oldDelegate.bpm != bpm;
  }
}
