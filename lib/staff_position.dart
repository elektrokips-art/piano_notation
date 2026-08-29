/// Скрипичный или басовый ключ — от этого зависит, какая нота считается
/// нижней линией стана (step=0), см. [staffPositionFor].
enum Clef { treble, bass }

/// Позиция ноты на стане: step=0 — нижняя линия стана (E4 для скрипичного
/// ключа, G2 для басового), каждый следующий шаг — на пол-расстояния между
/// линиями выше/ниже.
class StaffPosition {
  final int step;
  final bool sharp;
  final String letter;

  const StaffPosition({
    required this.step,
    required this.sharp,
    required this.letter,
  });
}

const _letterOrder = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];

// (буква, диез?) для каждого из 12 полутонов, начиная с C.
const _pitchInfo = [
  ('C', false), ('C', true), ('D', false), ('D', true), ('E', false),
  ('F', false), ('F', true), ('G', false), ('G', true), ('A', false),
  ('A', true), ('B', false),
];

// Опорная точка (нижняя линия стана, step=0): E4 для скрипичного ключа,
// G2 для басового.
const _trebleReferenceStep = 4 * 7 + 2; // E, октава 4
const _bassReferenceStep = 2 * 7 + 4; // G, октава 2

StaffPosition staffPositionFor(int midiPitch, [Clef clef = Clef.treble]) {
  final (letter, sharp) = _pitchInfo[midiPitch % 12];
  final octave = (midiPitch ~/ 12) - 1;
  final idx = _letterOrder.indexOf(letter);
  final absoluteStep = octave * 7 + idx;
  final referenceStep =
      clef == Clef.treble ? _trebleReferenceStep : _bassReferenceStep;
  return StaffPosition(
    step: absoluteStep - referenceStep,
    sharp: sharp,
    letter: letter,
  );
}
