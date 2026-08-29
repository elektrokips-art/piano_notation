import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'note_models.dart';

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
    state = PracticeState(
      active: true,
      notes: [for (final m in measures) ...m],
      bpm: bpm,
    );
  }

  void stop() => state = const PracticeState();

  /// Продвигает на следующую не-паузу — паузы в этом режиме не озвучиваются
  /// и не ждутся, они просто пропускаются автоматически.
  void advance() {
    var next = state.index + 1;
    while (next < state.notes.length && state.notes[next].isRest) {
      next++;
    }
    state = state.copyWith(index: next);
  }
}

final practiceControllerProvider =
    NotifierProvider<PracticeController, PracticeState>(PracticeController.new);
