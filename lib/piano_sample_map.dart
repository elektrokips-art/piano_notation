import 'dart:math' as math;
import 'tone_synth.dart';

/// Сэмплы Salamander Grand Piano V3 (CC BY 3.0, автор Alexander Holm)
/// записаны через каждые 3 полутона. Для нот между сэмплами берём
/// ближайший и питч-шифтим через скорость воспроизведения.
const Map<int, String> pianoSampleFiles = {
  21: 'A0v14.mp3',
  24: 'C1v14.mp3',
  27: 'Ds1v14.mp3',
  30: 'Fs1v14.mp3',
  33: 'A1v14.mp3',
  36: 'C2v14.mp3',
  39: 'Ds2v14.mp3',
  42: 'Fs2v14.mp3',
  45: 'A2v14.mp3',
  48: 'C3v14.mp3',
  51: 'Ds3v14.mp3',
  54: 'Fs3v14.mp3',
  57: 'A3v14.mp3',
  60: 'C4v14.mp3',
  63: 'Ds4v14.mp3',
  66: 'Fs4v14.mp3',
  69: 'A4v14.mp3',
  72: 'C5v14.mp3',
  75: 'Ds5v14.mp3',
  78: 'Fs5v14.mp3',
  81: 'A5v14.mp3',
  84: 'C6v14.mp3',
  87: 'Ds6v14.mp3',
  90: 'Fs6v14.mp3',
  93: 'A6v14.mp3',
  96: 'C7v14.mp3',
  99: 'Ds7v14.mp3',
  102: 'Fs7v14.mp3',
  105: 'A7v14.mp3',
  108: 'C8v14.mp3',
};

/// Электропиано и синтезатор — сэмплы FluidR3 GM SoundFont (MIT, Frank Wen /
/// midi-js-soundfonts, Benjamin Gleitzman), сконвертированные в mp3 пакетом
/// soundfont-for-samplers (MIT). В отличие от Salamander, здесь записана
/// КАЖДАЯ полутоновая нота от A0 до C8 — питч-шифт не нужен, всегда точное
/// совпадение.
String fluidR3FileName(int midi) {
  const letters = [
    'C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B'
  ];
  final octave = (midi ~/ 12) - 1;
  return '${letters[midi % 12]}$octave.mp3';
}

class PianoSampleMatch {
  final String assetPath;
  final double playbackRate;
  const PianoSampleMatch(this.assetPath, this.playbackRate);
}

/// Ближайший записанный сэмпл для [midi] и скорость воспроизведения,
/// которая сдвигает его питч до нужной ноты (2^(полутоны/12)).
PianoSampleMatch nearestPianoSample(int midi) =>
    _nearestFrom(pianoSampleFiles, 'piano_samples', midi);

PianoSampleMatch sampleFor(int midi, ToneStyle style) {
  switch (style) {
    case ToneStyle.classicPiano:
      return nearestPianoSample(midi);
    case ToneStyle.electricPiano:
      return PianoSampleMatch(
          'assets/electric_piano_samples/${fluidR3FileName(midi)}', 1.0);
    case ToneStyle.synth:
      return PianoSampleMatch(
          'assets/synth_samples/${fluidR3FileName(midi)}', 1.0);
  }
}

PianoSampleMatch _nearestFrom(Map<int, String> files, String dir, int midi) {
  var bestMidi = files.keys.first;
  var bestDiff = (midi - bestMidi).abs();
  for (final sampleMidi in files.keys) {
    final diff = (midi - sampleMidi).abs();
    if (diff < bestDiff) {
      bestDiff = diff;
      bestMidi = sampleMidi;
    }
  }
  final semitones = midi - bestMidi;
  final rate = math.pow(2, semitones / 12).toDouble();
  return PianoSampleMatch('assets/$dir/${files[bestMidi]}', rate);
}
