import 'note_models.dart';

const ticksPerBeat = 4; // разрешение сетки — 16-е ноты
const ticksPerMeasure = ticksPerBeat * 4; // размер 4/4
const allowedDurations = [1, 2, 4, 8, 16]; // 16th, 8th, quarter, half, whole

int nearestDuration(int ticks) {
  return allowedDurations.reduce(
    (a, b) => (ticks - a).abs() <= (ticks - b).abs() ? a : b,
  );
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

  // обрезаем длительность так, чтобы нота/аккорд не заезжали на следующий
  final clamped = <QuantizedNote>[];
  for (var i = 0; i < clusters.length; i++) {
    final c = clusters[i];
    final maxDur = i + 1 < clusters.length
        ? clusters[i + 1].startTick - c.startTick
        : c.rawDur;
    final dur = maxDur < c.rawDur ? maxDur : c.rawDur;
    clamped.add(QuantizedNote(
      midiPitches: c.pitches..sort(),
      startTick: c.startTick,
      durationTicks: nearestDuration(dur < 1 ? 1 : dur),
    ));
  }

  // заполняем паузами промежутки между нотами
  final timeline = <QuantizedNote>[];
  var cursor = 0;
  for (final n in clamped) {
    var gap = n.startTick - cursor;
    while (gap > 0) {
      final d = allowedDurations.lastWhere((x) => x <= gap, orElse: () => 1);
      timeline.add(QuantizedNote(startTick: cursor, durationTicks: d));
      cursor += d;
      gap -= d;
    }
    timeline.add(n);
    cursor = n.startTick + n.durationTicks;
  }

  // добиваем последний такт паузами
  final remainder =
      ((cursor / ticksPerMeasure).ceil() * ticksPerMeasure) - cursor;
  var pad = remainder;
  while (pad > 0) {
    final d = allowedDurations.lastWhere((x) => x <= pad, orElse: () => 1);
    timeline.add(QuantizedNote(startTick: cursor, durationTicks: d));
    cursor += d;
    pad -= d;
  }

  // режем таймлайн на такты по ticksPerMeasure
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
