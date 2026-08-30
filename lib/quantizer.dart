import 'note_models.dart';

const ticksPerBeat = 4; // разрешение сетки — 16-е ноты
const ticksPerMeasure = ticksPerBeat * 4; // размер 4/4
const allowedDurations = [1, 2, 4, 8, 16]; // 16th, 8th, quarter, half, whole

int nearestDuration(int ticks) {
  return allowedDurations.reduce(
    (a, b) => (ticks - a).abs() <= (ticks - b).abs() ? a : b,
  );
}

/// Наибольшая разрешённая длительность, не превышающая [maxTicks].
int _largestFitting(int maxTicks) {
  return allowedDurations.lastWhere((x) => x <= maxTicks, orElse: () => 1);
}

class _Cluster {
  final int startTick;
  final List<int> pitches;
  int rawDur;
  _Cluster(this.startTick, this.pitches, this.rawDur);
}

/// Превращает поток сырых NoteEvent в список тактов из QuantizedNote.
/// Ноты, нажатые одновременно (попавшие в один и тот же тик), группируются
/// в аккорд — одну запись с несколькими высотами и общей длительностью,
/// так что игра несколькими пальцами сразу не портит тайминг тактов.
///
/// Ни нота, ни пауза никогда не пересекают границу такта: если сыгранная
/// нота длиннее, чем осталось до конца такта, она обрывается на границе
/// и (если реально звучала дольше) продолжается новой нотой той же высоты
/// в начале следующего такта — без этого длинная нота визуально наезжала
/// на соседний такт при отрисовке (такты рисуются фиксированной ширины).
List<List<QuantizedNote>> quantize(List<NoteEvent> events, int bpm) {
  final withOff = events.where((e) => e.offTime != null).toList()
    ..sort((a, b) => a.onTime.compareTo(b.onTime));

  if (withOff.isEmpty) return [];

  final msPerTick = (60 / bpm / ticksPerBeat) * 1000;
  final start = withOff.first.onTime;

  final rawNotes = withOff.map((e) {
    final startTick =
        (e.onTime.difference(start).inMilliseconds / msPerTick).round();
    final rawDur = (e.offTime!.difference(e.onTime).inMilliseconds / msPerTick)
        .round()
        .clamp(1, 999);
    return (midi: e.midiPitch, startTick: startTick, rawDur: rawDur);
  }).toList()
    ..sort((a, b) => a.startTick.compareTo(b.startTick));

  // группируем ноты с одинаковым startTick в аккорды
  final clusters = <_Cluster>[];
  for (final n in rawNotes) {
    final last = clusters.isNotEmpty ? clusters.last : null;
    if (last != null && last.startTick == n.startTick) {
      last.pitches.add(n.midi);
      if (n.rawDur > last.rawDur) last.rawDur = n.rawDur;
    } else {
      clusters.add(_Cluster(n.startTick, [n.midi], n.rawDur));
    }
  }

  // длительность каждого кластера, обрезанная так, чтобы не наехать
  // на начало следующего кластера (границы такта учтём отдельно ниже)
  final noteBudget = <int>[];
  for (var i = 0; i < clusters.length; i++) {
    final c = clusters[i];
    final untilNext = i + 1 < clusters.length
        ? clusters[i + 1].startTick - c.startTick
        : c.rawDur;
    noteBudget.add((untilNext < c.rawDur ? untilNext : c.rawDur).clamp(1, 999));
  }

  // строим таймлайн (паузы + ноты) — каждый элемент строго внутри такта
  final timeline = <QuantizedNote>[];
  var cursor = 0;
  for (var i = 0; i < clusters.length; i++) {
    final c = clusters[i];

    // паузами заполняем промежуток до начала ноты, не пересекая такты
    while (cursor < c.startTick) {
      final untilMeasure = ticksPerMeasure - (cursor % ticksPerMeasure);
      final untilNote = c.startTick - cursor;
      final d =
          _largestFitting(untilMeasure < untilNote ? untilMeasure : untilNote);
      timeline.add(QuantizedNote(startTick: cursor, durationTicks: d));
      cursor += d;
    }

    // сама нота/аккорд — не длиннее остатка такта; если не влезает целиком,
    // обрезаем по границе такта и продолжаем в следующем. Первый кусок —
    // настоящее нажатие, все следующие в этом же while — не новые нажатия,
    // а его же продолжение (см. QuantizedNote.tied).
    var remaining = noteBudget[i];
    var firstPiece = true;
    while (remaining > 0) {
      final untilMeasure = ticksPerMeasure - (cursor % ticksPerMeasure);
      final want = untilMeasure < remaining ? untilMeasure : remaining;
      var d = nearestDuration(want);
      if (d > untilMeasure) d = _largestFitting(untilMeasure);
      timeline.add(QuantizedNote(
        midiPitches: c.pitches,
        startTick: cursor,
        durationTicks: d,
        tied: !firstPiece,
      ));
      firstPiece = false;
      cursor += d;
      remaining -= d;
    }
  }

  // добиваем последний такт паузами
  final remainder =
      ((cursor / ticksPerMeasure).ceil() * ticksPerMeasure) - cursor;
  var pad = remainder;
  while (pad > 0) {
    final untilMeasure = ticksPerMeasure - (cursor % ticksPerMeasure);
    final d = _largestFitting(untilMeasure < pad ? untilMeasure : pad);
    timeline.add(QuantizedNote(startTick: cursor, durationTicks: d));
    cursor += d;
    pad -= d;
  }

  // режем таймлайн на такты по ticksPerMeasure — теперь без переполнений
  final measures = <List<QuantizedNote>>[];
  var measure = <QuantizedNote>[];
  var measureTicks = 0;
  for (final item in timeline) {
    measure.add(item);
    measureTicks += item.durationTicks;
    if (measureTicks >= ticksPerMeasure) {
      measures.add(measure);
      measure = [];
      measureTicks = 0;
    }
  }
  if (measure.isNotEmpty) measures.add(measure);
  return measures;
}
