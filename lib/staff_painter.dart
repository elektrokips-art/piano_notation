import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'note_models.dart';
import 'quantizer.dart' show ticksPerBeat, ticksPerMeasure;
import 'staff_position.dart';

/// Нота/аккорд из такта вместе с уже посчитанной X-координатой центра,
/// номером доли (для группировки восьмых/шестнадцатых в общую балку) и
/// сдвигом на октавы под знаком 8va/15ma (см. _assignOttavaShifts) — если
/// нота слишком далеко от стана, её рисуют ближе (без кучи добавочных
/// линеек), а знак сверху/снизу говорит читать на октаву(-ы) иначе.
class _NoteSlot {
  final QuantizedNote item;
  final double cx;
  final int beat;
  int shiftOctaves = 0;
  _NoteSlot(this.item, this.cx, this.beat);
}

class _OttavaRegion {
  final double startCx;
  final double endCx;
  final int shiftOctaves; // >0 — 8va/15ma (высокие ноты рисуются ниже), <0 — 8vb/15mb
  _OttavaRegion(this.startCx, this.endCx, this.shiftOctaves);
}

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
      final measureSlots = <List<_NoteSlot>>[];
      for (final measure in lineMeasures) {
        var tx = mx;
        var cursor = 0;
        final slots = <_NoteSlot>[];
        for (final item in measure) {
          final w = item.durationTicks * tickWidth;
          slots.add(_NoteSlot(item, tx + w / 2, cursor ~/ ticksPerBeat));
          tx += w;
          cursor += item.durationTicks;
        }
        measureSlots.add(slots);
        mx += measureWidth;
      }

      // Знаки 8va/15ma считаются по всей строке сразу — пассаж может
      // тянуться через несколько тактов подряд, разбивать его по тактам
      // отдельными значками было бы неправильно.
      final lineSlots = measureSlots.expand((s) => s).toList();
      final regions = _assignOttavaShifts(lineSlots);
      for (final region in regions) {
        _drawOttavaMark(canvas, staffBottomY, region);
      }

      mx = leftMargin;
      for (final slots in measureSlots) {
        _drawMeasureSlots(canvas, staffBottomY, slots);
        mx += measureWidth;
        canvas.drawLine(
          Offset(mx, staffBottomY),
          Offset(mx, staffBottomY - spaceHeight * 4),
          _inkPaint,
        );
      }
    }
  }

  static const int _highLedgerLimit = 14; // 3 добавочные линейки над станом
  static const int _lowLedgerLimit = -6; // 3 добавочные линейки под станом
  static const _octavaLabels = {1: '8va', 2: '15ma', -1: '8vb', -2: '15mb'};

  /// Сколько октав сдвинуть отображение аккорда/ноты, чтобы уместиться в
  /// разумных пределах добавочных линеек (0 — сдвиг не нужен).
  int _shiftFor(List<int> pitches) {
    final steps = pitches.map((p) => staffPositionFor(p).step);
    final maxStep = steps.reduce(math.max);
    final minStep = steps.reduce(math.min);
    if (maxStep > _highLedgerLimit) {
      return ((maxStep - _highLedgerLimit) / 7).ceil();
    }
    if (minStep < _lowLedgerLimit) {
      return -(((_lowLedgerLimit - minStep) / 7).ceil());
    }
    return 0;
  }

  /// Группирует подряд идущие ноты, которым нужен сдвиг в одну сторону, в
  /// регионы под одним знаком 8va/15ma (пропуская паузы — они сдвига не
  /// требуют и разрыв пассажа не считается). Проставляет [_NoteSlot.
  /// shiftOctaves] и возвращает список регионов для отрисовки самого знака.
  List<_OttavaRegion> _assignOttavaShifts(List<_NoteSlot> lineSlots) {
    final notes = [
      for (final s in lineSlots) if (!s.item.isRest) s,
    ];
    final regions = <_OttavaRegion>[];
    var i = 0;
    while (i < notes.length) {
      final shift0 = _shiftFor(notes[i].item.midiPitches);
      if (shift0 == 0) {
        i++;
        continue;
      }
      final sign = shift0.sign;
      var j = i;
      var maxAbs = 0;
      while (j < notes.length) {
        final s = _shiftFor(notes[j].item.midiPitches);
        if (s == 0 || s.sign != sign) break;
        if (s.abs() > maxAbs) maxAbs = s.abs();
        j++;
      }
      final shift = sign * maxAbs;
      for (var k = i; k < j; k++) {
        notes[k].shiftOctaves = shift;
      }
      regions.add(_OttavaRegion(notes[i].cx, notes[j - 1].cx, shift));
      i = j;
    }
    return regions;
  }

  void _drawOttavaMark(Canvas canvas, double staffBottomY, _OttavaRegion region) {
    final label = _octavaLabels[region.shiftOctaves] ?? '${region.shiftOctaves * 7}va';
    final above = region.shiftOctaves > 0;
    // Линия — вплотную к стану, подпись — сразу за ней (снаружи от стана),
    // единообразно что сверху, что снизу.
    final lineY =
        above ? staffBottomY - spaceHeight * 4 - 10 : staffBottomY + 10;
    final textBaselineY = above ? lineY - 3 : lineY + 20;
    final textWidth = label.length * 7.0;

    _drawText(canvas, label, region.startCx - 4, textBaselineY, 13);
    _drawDashedLine(
      canvas,
      Offset(region.startCx + textWidth, lineY),
      Offset(region.endCx + 10, lineY),
    );
    // короткий "хвостик" на конце — как в настоящей гравировке
    canvas.drawLine(
      Offset(region.endCx + 10, lineY),
      Offset(region.endCx + 10, lineY + (above ? 6 : -6)),
      _inkPaint,
    );
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end) {
    const dashLen = 4.0, gapLen = 3.0;
    final total = (end - start).distance;
    if (total <= 0) return;
    final dir = (end - start) / total;
    var travelled = 0.0;
    while (travelled < total) {
      final segEnd = math.min(travelled + dashLen, total);
      canvas.drawLine(
        start + dir * travelled,
        start + dir * segEnd,
        _inkPaint,
      );
      travelled = segEnd + gapLen;
    }
  }

  static const double _noteRx = 6.5, _noteRy = 5.0;
  static const double _stemLen = 34.0;

  late final Paint _stemPaint = Paint()
    ..color = const Color(0xFF23222A)
    ..strokeWidth = 1.4;

  late final Paint _beamPaint = Paint()
    ..color = const Color(0xFF23222A)
    ..strokeWidth = 4;

  /// Разбирает такт на паузы, одиночные ноты и группы восьмых/шестнадцатых
  /// внутри одной доли (объединяются общей балкой вместо отдельных
  /// флажков — как в настоящей нотной гравировке).
  void _drawMeasureSlots(Canvas canvas, double staffBottomY, List<_NoteSlot> slots) {
    var i = 0;
    while (i < slots.length) {
      final slot = slots[i];
      if (slot.item.isRest) {
        _drawRest(canvas, slot.cx, staffBottomY - spaceHeight * 2, slot.item.durationTicks);
        i++;
        continue;
      }
      if (slot.item.durationTicks > 2) {
        _drawNote(canvas, slot.cx, staffBottomY, slot.item.midiPitches, slot.item.durationTicks,
            shiftOctaves: slot.shiftOctaves);
        i++;
        continue;
      }
      var j = i;
      final group = <_NoteSlot>[];
      while (j < slots.length &&
          !slots[j].item.isRest &&
          slots[j].item.durationTicks <= 2 &&
          slots[j].beat == slot.beat) {
        group.add(slots[j]);
        j++;
      }
      if (group.length >= 2) {
        _drawBeamedGroup(canvas, staffBottomY, group);
      } else {
        _drawNote(canvas, slot.cx, staffBottomY, slot.item.midiPitches, slot.item.durationTicks,
            shiftOctaves: slot.shiftOctaves);
      }
      i = j;
    }
  }

  /// Общее направление штиля для группы под балкой — как в настоящей
  /// гравировке, а не у каждой ноты своё: считаем средний ОТОБРАЖАЕМЫЙ шаг
  /// (с учётом сдвига 8va/15ma, если он есть) по всем нотам/аккордам группы.
  bool _groupStemUp(List<_NoteSlot> group) {
    final steps = <int>[
      for (final slot in group)
        for (final p in slot.item.midiPitches)
          staffPositionFor(p).step - slot.shiftOctaves * 7,
    ];
    return steps.reduce((a, b) => a + b) / steps.length < 4;
  }

  double _cyFor(int pitch, int shiftOctaves, double staffBottomY) =>
      staffBottomY - (staffPositionFor(pitch).step - shiftOctaves * 7) * stepPx;

  void _drawBeamedGroup(Canvas canvas, double staffBottomY, List<_NoteSlot> group) {
    final stemUp = _groupStemUp(group);

    // Плоская (негорбатая) балка — проще для восприятия, чем ступенчатая по
    // контуру мелодии, и её проще сделать корректно во всех случаях.
    double beamY;
    if (stemUp) {
      final minCy = group
          .expand((s) => s.item.midiPitches.map((p) => _cyFor(p, s.shiftOctaves, staffBottomY)))
          .reduce(math.min);
      beamY = minCy - _stemLen;
    } else {
      final maxCy = group
          .expand((s) => s.item.midiPitches.map((p) => _cyFor(p, s.shiftOctaves, staffBottomY)))
          .reduce(math.max);
      beamY = maxCy + _stemLen;
    }

    for (final slot in group) {
      _drawNote(
        canvas,
        slot.cx,
        staffBottomY,
        slot.item.midiPitches,
        slot.item.durationTicks,
        shiftOctaves: slot.shiftOctaves,
        forcedStemUp: stemUp,
        forcedStemTopY: beamY,
        drawFlags: false,
      );
    }

    double stemXFor(_NoteSlot slot) =>
        slot.cx + (stemUp ? _noteRx - 1 : -(_noteRx - 1));

    // основная балка — на всю группу (объединяет и восьмые, и шестнадцатые)
    canvas.drawLine(
      Offset(stemXFor(group.first), beamY),
      Offset(stemXFor(group.last), beamY),
      _beamPaint,
    );

    // вторая балка — только между соседними шестнадцатыми
    const beamGap = 6.0;
    final beamY2 = stemUp ? beamY + beamGap : beamY - beamGap;
    for (var k = 0; k < group.length - 1; k++) {
      if (group[k].item.durationTicks == 1 && group[k + 1].item.durationTicks == 1) {
        canvas.drawLine(
          Offset(stemXFor(group[k]), beamY2),
          Offset(stemXFor(group[k + 1]), beamY2),
          _beamPaint,
        );
      }
    }
  }

  // Рисует ноту или аккорд: одна головка на каждую высоту, общий штиль.
  // [forcedStemUp]/[forcedStemTopY] задаются группой под общей балкой
  // (см. _drawBeamedGroup) — тогда [drawFlags] выключается, флажки не нужны.
  void _drawNote(
    Canvas canvas,
    double cx,
    double staffBottomY,
    List<int> pitches,
    int durTicks, {
    int shiftOctaves = 0,
    bool? forcedStemUp,
    double? forcedStemTopY,
    bool drawFlags = true,
  }) {
    final positions = pitches.map(staffPositionFor).toList();
    // Отображаемый шаг — с поправкой на 8va/15ma: сама позиция на стане
    // рисуется так, будто нота на shiftOctaves октав(ы) ближе к стану, а
    // знак сверху/снизу говорит читать её на самом деле выше/ниже.
    final displaySteps = [for (final p in positions) p.step - shiftOctaves * 7];
    final cys = [for (final s in displaySteps) staffBottomY - s * stepPx];
    final open = durTicks >= 8; // половинная/целая — незакрашенная головка
    const rx = _noteRx, ry = _noteRy;

    for (var idx = 0; idx < positions.length; idx++) {
      final pos = positions[idx];
      final displayStep = displaySteps[idx];
      final cy = cys[idx];

      // добавочные линейки, если нота выше/ниже стана
      if (displayStep < 0) {
        for (var s = -2; s >= displayStep; s -= 2) {
          final ly = staffBottomY - s * stepPx;
          canvas.drawLine(Offset(cx - 10, ly), Offset(cx + 10, ly), _inkPaint);
        }
      } else if (displayStep > 8) {
        for (var s = 10; s <= displayStep; s += 2) {
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

    final avgStep = displaySteps.reduce((a, b) => a + b) / displaySteps.length;
    final stemUp = forcedStemUp ?? (avgStep < 4);
    final stemX = cx + (stemUp ? rx - 1 : -(rx - 1));
    final minCy = cys.reduce((a, b) => a < b ? a : b);
    final maxCy = cys.reduce((a, b) => a > b ? a : b);
    // штиль тянется от дальнего от него края аккорда с запасом stemLen —
    // либо до общей балки группы, если она задана снаружи.
    final stemBaseY = stemUp ? maxCy : minCy;
    final naturalTopY = stemUp ? minCy - _stemLen : maxCy + _stemLen;
    final stemTopY = forcedStemTopY ?? naturalTopY;

    canvas.drawLine(Offset(stemX, stemBaseY), Offset(stemX, stemTopY), _stemPaint);

    if (!drawFlags) return;

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
