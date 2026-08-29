import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'note_models.dart';
import 'quantizer.dart';

/// Состояние экрана записи: идёт ли запись, зажата ли педаль сустейна,
/// какие события накоплены, темп и результат последней квантизации.
class NotationState {
  final bool recording;
  final bool sustain;
  final List<NoteEvent> events;
  final int bpm;
  final List<List<QuantizedNote>>? measures;

  const NotationState({
    this.recording = false,
    this.sustain = false,
    this.events = const [],
    this.bpm = 90,
    this.measures,
  });

  NotationState copyWith({
    bool? recording,
    bool? sustain,
    List<NoteEvent>? events,
    int? bpm,
    List<List<QuantizedNote>>? measures,
    bool clearMeasures = false,
  }) {
    return NotationState(
      recording: recording ?? this.recording,
      sustain: sustain ?? this.sustain,
      events: events ?? this.events,
      bpm: bpm ?? this.bpm,
      measures: clearMeasures ? null : (measures ?? this.measures),
    );
  }
}

class NotationController extends Notifier<NotationState> {
  @override
  NotationState build() => const NotationState();

  void toggleRecording() {
    if (state.recording) {
      // Клавиши, которые всё ещё держат нажатыми (или зависли под педалью)
      // на момент остановки, иначе останутся без offTime и молча выпадут
      // из квантизации.
      final now = DateTime.now();
      for (final e in state.events) {
        e.offTime ??= now;
      }
      state = state.copyWith(recording: false, events: [...state.events]);
      renderNotes();
    } else {
      state = state.copyWith(recording: true, events: [], clearMeasures: true);
    }
  }

  /// Сбрасывает записанные ноты и собранный нотный стан, не трогая запись.
  void reset() {
    state = state.copyWith(recording: false, events: [], clearMeasures: true);
  }

  /// Педаль сустейна: пока зажата, отпускание клавиши не обрывает ноту —
  /// как настоящая правая педаль пианино. При отпускании педали все
  /// зависшие под ней ноты закрываются.
  void toggleSustain() {
    if (state.sustain) {
      final now = DateTime.now();
      for (final e in state.events) {
        e.offTime ??= now;
      }
      state = state.copyWith(sustain: false, events: [...state.events]);
      if (state.recording) renderNotes();
    } else {
      state = state.copyWith(sustain: true);
    }
  }

  void noteOn(int midiPitch) {
    if (!state.recording) return;
    final now = DateTime.now();
    // Если та же нота уже висит под педалью — закрываем предыдущую перед
    // повторным нажатием, иначе quantize() увидит два открытых события.
    for (final e in state.events) {
      if (e.midiPitch == midiPitch && e.offTime == null) {
        e.offTime = now;
      }
    }
    state = state.copyWith(events: [
      ...state.events,
      NoteEvent(midiPitch: midiPitch, onTime: now),
    ]);
  }

  void noteOff(int midiPitch) {
    if (!state.recording) return;
    if (state.sustain) return; // педаль держит ноту звучащей
    for (var i = state.events.length - 1; i >= 0; i--) {
      if (state.events[i].midiPitch == midiPitch &&
          state.events[i].offTime == null) {
        state.events[i].offTime = DateTime.now();
        break;
      }
    }
    // events изменены мутацией — форсируем ребилд новой ссылкой на список.
    state = state.copyWith(events: [...state.events]);
    renderNotes(); // живое обновление нотного стана прямо во время записи
  }

  void renderNotes() {
    state = state.copyWith(measures: quantize(state.events, state.bpm));
  }

  /// Темп записи — влияет на то, как сырое время между нажатиями переводится
  /// в длительности нот (см. quantizer.dart). Если ребёнок играет медленнее
  /// или быстрее заданных по умолчанию 90 уд/мин, без этой настройки ноты
  /// посчитаются неверно даже при правильной раскладке балок.
  void setBpm(int bpm) {
    state = state.copyWith(bpm: bpm);
    if (state.events.isNotEmpty) renderNotes();
  }

  /// Загружает готовую пьесу (из PDF, см. notation_file.dart) на нотный
  /// стан — как результат renderNotes(), только без собственной записи.
  /// Используется режимом «играть по нотам» (см. practice_state.dart).
  void loadPiece(List<List<QuantizedNote>> measures, int bpm) {
    state = state.copyWith(
        recording: false, events: [], measures: measures, bpm: bpm);
  }
}

final notationControllerProvider =
    NotifierProvider<NotationController, NotationState>(
        NotationController.new);
