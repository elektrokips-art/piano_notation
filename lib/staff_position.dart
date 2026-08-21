/// Позиция ноты на скрипичном ключе: step=0 — нижняя линия стана (E4),
/// каждый следующий шаг — на пол-расстояния между линиями выше/ниже.
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

StaffPosition staffPositionFor(int midiPitch) {
  final (letter, sharp) = _pitchInfo[midiPitch % 12];
  final octave = (midiPitch ~/ 12) - 1;
  final idx = _letterOrder.indexOf(letter);
  final absoluteStep = octave * 7 + idx;
  // опорная точка: E4 (октава 4, буква E) = нижняя линия стана = step 0
  const referenceStep = 4 * 7 + 2;
  return StaffPosition(
    step: absoluteStep - referenceStep,
    sharp: sharp,
    letter: letter,
  );
}
