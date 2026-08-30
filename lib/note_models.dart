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
  // true, если это не новое нажатие, а искусственное продолжение предыдущей
  // QuantizedNote той же высоты — квантайзер сам их развёл (одна реально
  // сыгранная нота не влезла в одну разрешённую длительность), это не
  // догадка задним числом по времени. См. quantizer.dart.
  final bool tied;

  QuantizedNote({
    this.midiPitches = const [],
    required this.startTick,
    required this.durationTicks,
    this.tied = false,
  });

  bool get isRest => midiPitches.isEmpty;
}
