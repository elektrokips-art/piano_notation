import 'dart:math' as math;
import 'dart:typed_data';

/// Частота ноты по MIDI-номеру (A4 = 69 = 440 Гц).
double midiToFrequency(int midi) => 440.0 * math.pow(2, (midi - 69) / 12);

enum ToneStyle { classicPiano, electricPiano, synth }

class _ToneSpec {
  final List<double> harmonics;
  final double inharmonicity;
  final double hammerNoise;
  // Базовые скорости затухания: [быстрая фаза, медленная фаза] для
  // основного тона (h=0). У более высоких гармоник умножается на
  // (1 + harmonicDecayGrowth*h) — оттого верх гаснет быстрее низа,
  // как у настоящей струны.
  final double fastDecay;
  final double slowDecay;
  final double harmonicDecayGrowth;
  // Насколько сильно регистр ноты (бас/дискант) влияет на скорость
  // затухания и длительность сэмпла: 0 = не влияет, 1 = полностью.
  final double registerSensitivity;

  const _ToneSpec({
    required this.harmonics,
    required this.inharmonicity,
    required this.hammerNoise,
    required this.fastDecay,
    required this.slowDecay,
    required this.harmonicDecayGrowth,
    required this.registerSensitivity,
  });
}

final _specs = <ToneStyle, _ToneSpec>{
  ToneStyle.classicPiano: const _ToneSpec(
    harmonics: [1.0, 0.62, 0.38, 0.24, 0.15, 0.09, 0.05, 0.03],
    inharmonicity: 0.0009,
    hammerNoise: 0.05,
    fastDecay: 8.5,
    slowDecay: 1.0,
    harmonicDecayGrowth: 0.55,
    registerSensitivity: 1.0,
  ),
  ToneStyle.electricPiano: const _ToneSpec(
    // Профиль в духе Rhodes/FM-электропиано: слабая вторая гармоника и
    // выделяющийся "звонкий" верхний обертон, без шума молоточка.
    harmonics: [1.0, 0.12, 0.55, 0.06, 0.22, 0.04],
    inharmonicity: 0.0,
    hammerNoise: 0.0,
    fastDecay: 6.0,
    slowDecay: 1.6,
    harmonicDecayGrowth: 0.3,
    registerSensitivity: 0.4,
  ),
  ToneStyle.synth: const _ToneSpec(
    harmonics: [1.0],
    inharmonicity: 0.0,
    hammerNoise: 0.0,
    fastDecay: 3.5,
    slowDecay: 3.5,
    harmonicDecayGrowth: 0.0,
    registerSensitivity: 0.0,
  ),
};

final _rng = math.Random(7);

/// Генерирует короткий WAV-сэмпл в выбранном тембре [style], без внешних
/// аудиофайлов. Верхние гармоники гаснут быстрее основного тона, а бас
/// звучит дольше дисканта — как у настоящей струны. Амплитуда всегда
/// держится с запасом от предела 16 бит, чтобы избежать клиппинга.
Uint8List generateToneWav(
  double frequencyHz, {
  ToneStyle style = ToneStyle.classicPiano,
  double durationSec = 1.1,
  double durationScale = 1.0,
  int sampleRate = 44100,
}) {
  final spec = _specs[style]!;
  final harmonicsSum = spec.harmonics.fold<double>(0, (sum, a) => sum + a);

  // Регистр: у низких нот бас звучит и гаснет заметно дольше, у высоких —
  // короче и резче. registerScale > 1 для дисканта, < 1 для баса.
  final rawRegisterScale = math.sqrt(frequencyHz / 440.0);
  final registerScale = 1 + (rawRegisterScale - 1) * spec.registerSensitivity;
  final effectiveDuration =
      (durationSec * durationScale / registerScale).clamp(0.35, 3.5);

  final sampleCount = (effectiveDuration * sampleRate).round();
  final samples = Int16List(sampleCount);

  const headroom = 0.9;
  const hammerWindow = 0.006; // окно щелчка молоточка, сек
  const fadeOutSec = 0.02; // чтобы обрезка сэмпла не щёлкала в конце
  final fadeOutStart = effectiveDuration - fadeOutSec;
  var filteredNoise = 0.0;

  for (var i = 0; i < sampleCount; i++) {
    final t = i / sampleRate;

    var harmonicValue = 0.0;
    for (var h = 0; h < spec.harmonics.length; h++) {
      final n = h + 1;
      final partialFreq =
          frequencyHz * n * math.sqrt(1 + spec.inharmonicity * n * n);
      final decayBoost = (1 + spec.harmonicDecayGrowth * h) * registerScale;
      final partialEnvelope = 0.5 * math.exp(-spec.fastDecay * decayBoost * t) +
          0.5 * math.exp(-spec.slowDecay * decayBoost * t);
      harmonicValue += spec.harmonics[h] *
          partialEnvelope *
          math.sin(2 * math.pi * partialFreq * t);
    }
    var value = (harmonicValue / harmonicsSum) * headroom;

    // Щелчок молоточка: сглаженный (однополюсный фильтр) шумовой всплеск —
    // без сглаживания случайный шум звучит как радиотреск, а не как
    // мягкий удар фетра.
    if (spec.hammerNoise > 0 && t < hammerWindow) {
      final raw = _rng.nextDouble() * 2 - 1;
      filteredNoise = filteredNoise * 0.8 + raw * 0.2;
      final hammerEnvelope = math.exp(-t / 0.0025);
      value += filteredNoise * spec.hammerNoise * hammerEnvelope;
    }

    if (t > fadeOutStart) {
      value *= (1 - (t - fadeOutStart) / fadeOutSec).clamp(0.0, 1.0);
    }

    samples[i] = (value * 32767).round().clamp(-32768, 32767);
  }

  final dataLength = samples.lengthInBytes;
  final header = ByteData(44);

  void writeString(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      header.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  writeString(0, 'RIFF');
  header.setUint32(4, 36 + dataLength, Endian.little);
  writeString(8, 'WAVE');
  writeString(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, 1, Endian.little); // mono
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  header.setUint16(32, 2, Endian.little); // block align
  header.setUint16(34, 16, Endian.little); // bits per sample
  writeString(36, 'data');
  header.setUint32(40, dataLength, Endian.little);

  final bytes = Uint8List(44 + dataLength);
  bytes.setRange(0, 44, header.buffer.asUint8List());
  bytes.setRange(44, 44 + dataLength, samples.buffer.asUint8List());
  return bytes;
}
