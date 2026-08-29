import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'note_models.dart';
import 'quantizer.dart' show ticksPerMeasure;

/// Состояние режима «играть по нотам»: пьеса загружена из PDF (см.
/// notation_file.dart), плеер идёт по нотам по очереди — либо ждёт нужную
/// клавишу (waitForKey), либо сам её подсвечивает и озвучивает (autoPlay,
/// логика таймера — в example_usage.dart, тут только позиция).
class PracticeState {
  final bool active;
  final List<QuantizedNote> notes;
  final int index;
  final int bpm;

  const PracticeState({
    this.active = false,
    this.notes = const [],
    this.index = 0,
    this.bpm = 90,
  });

  QuantizedNote? get current => index < notes.length ? notes[index] : null;
  bool get finished => active && index >= notes.length;

  PracticeState copyWith({
    bool? active,
    List<QuantizedNote>? notes,
    int? index,
    int? bpm,
  }) {
    return PracticeState(
      active: active ?? this.active,
      notes: notes ?? this.notes,
      index: index ?? this.index,
      bpm: bpm ?? this.bpm,
    );
  }
}

class PracticeController extends Notifier<PracticeState> {
  @override
  PracticeState build() => const PracticeState();

  void load(List<List<QuantizedNote>> measures, int bpm) {
    final notes = _mergeTiedNotes([for (final m in measures) ...m]);
    state = PracticeState(
      active: true,
      notes: notes,
      index: _firstNonRest(notes, 0),
      bpm: bpm,
    );
  }

  /// Нота, не влезшая в такт целиком, режется квантайзером на границе такта
  /// и продолжается новой нотой той же высоты в начале следующего —
  /// правильно для отрисовки (см. quantizer.dart), но это одна и та же
  /// сыгранная нота, а не две отдельные: в тренажёре её нельзя требовать
  /// нажать дважды. Склеиваем такие соседние обрывки обратно перед игрой.
  static List<QuantizedNote> _mergeTiedNotes(List<QuantizedNote> notes) {
    final merged = <QuantizedNote>[];
    for (final n in notes) {
      final last = merged.isEmpty ? null : merged.last;
      final isContinuation = last != null &&
          !last.isRest &&
          !n.isRest &&
          setEquals(last.midiPitches.toSet(), n.midiPitches.toSet()) &&
          last.startTick + last.durationTicks == n.startTick &&
          // квантайзер режет ноту только ровно на границе такта — если
          // продолжение начинается не с начала такта, это две отдельные
          // подряд сыгранные ноты той же высоты, а не одна разрезанная
          n.startTick % ticksPerMeasure == 0;
      if (isContinuation) {
        merged[merged.length - 1] = QuantizedNote(
          midiPitches: last.midiPitches,
          startTick: last.startTick,
          durationTicks: last.durationTicks + n.durationTicks,
        );
      } else {
        merged.add(n);
      }
    }
    return merged;
  }

  void stop() => state = const PracticeState();

  /// Возвращает воспроизведение к началу пьесы, не выходя из тренажёра
  /// (в отличие от [stop], который закрывает пьесу целиком) — кнопка
  /// «Стоп» в транспорте автоигры/тренажёра.
  void restart() => state = state.copyWith(index: _firstNonRest(state.notes, 0));

  /// Продвигает на следующую не-паузу — паузы в этом режиме не озвучиваются
  /// и не ждутся, они просто пропускаются автоматически.
  void advance() => state = state.copyWith(index: _firstNonRest(state.notes, state.index + 1));

  static int _firstNonRest(List<QuantizedNote> notes, int from) {
    var i = from;
    while (i < notes.length && notes[i].isRest) {
      i++;
    }
    return i;
  }
}

final practiceControllerProvider =
    NotifierProvider<PracticeController, PracticeState>(PracticeController.new);
