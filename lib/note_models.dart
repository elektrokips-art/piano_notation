/// Сырое событие нажатия клавиши на виртуальном пианино.
class NoteEvent {
  final int midiPitch;
  final DateTime onTime;
  DateTime? offTime;

  NoteEvent({
    required this.midiPitch,
    required this.onTime,
    this.offTime,
  });
}

/// Нота, аккорд или пауза после квантизации к тактовой сетке.
/// startTick / durationTicks — в единицах 1/16 (см. quantizer.dart).
class QuantizedNote {
  final List<int> midiPitches; // пусто = пауза, несколько значений = аккорд
  final int startTick;
  final int durationTicks;

  QuantizedNote({
    this.midiPitches = const [],
    required this.startTick,
    required this.durationTicks,
  });

  bool get isRest => midiPitches.isEmpty;
}
