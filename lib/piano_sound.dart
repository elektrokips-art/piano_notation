import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'piano_sample_map.dart';
import 'tone_synth.dart';

/// Проигрывает звук ноты по MIDI-номеру: все стили — настоящие сэмплы
/// (Salamander Grand Piano для классического пианино, FluidR3 GM для
/// электропиано и синтезатора), см. piano_sample_map.dart. Отслеживает
/// активные ноты, чтобы отпускание клавиши реально гасило звук (как
/// демпфер настоящего пианино), а зажатая педаль сустейна оставляла ноту
/// звучать после отпускания клавиши.
class PianoSound {
  final _players = <int, AudioPlayer>{};
  final _heldByPedal = <int>{};
  final _preloaded = <AudioPlayer>[];

  /// Заранее загружает все уникальные сэмплы в системный кэш звуков
  /// (SoundPool на Android), чтобы самое первое нажатие каждой ноты не
  /// ждало декодирования файла — иначе звук на нём мог не успеть начаться
  /// до отпускания клавиши. Плееры-«якоря» держим живыми всё время работы
  /// приложения (не dispose), иначе кэш для этого сэмпла тут же очистится.
  Future<void> preload() async {
    // SoundPool (получатель кэша) — это Android-специфика; на web
    // setPlayerMode(lowLatency) всё равно no-op, а прогревать сотни
    // плееров впустую — только тратить AudioContext-ресурсы браузера.
    if (kIsWeb) return;
    // По умолчанию каждый плеер при старте запрашивает аудиофокус
    // (AUDIOFOCUS_GAIN на Android, эксклюзивная сессия на iOS) — и тогда
    // вторая нажатая клавиша отнимает фокус у первой, а плагин в ответ
    // глушит её: аккорд из двух нот звучал как одна. Ноты — это звуки
    // одного инструмента, они должны смешиваться, поэтому фокус не
    // запрашиваем вовсе.
    try {
      await AudioPlayer.global.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          audioFocus: AndroidAudioFocus.none,
          usageType: AndroidUsageType.media,
          contentType: AndroidContentType.music,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {AVAudioSessionOptions.mixWithOthers},
        ),
      ));
    } catch (_) {
      // На платформах без поддержки AudioContext оставляем как есть.
    }
    final assetPaths = <String>{
      for (final file in pianoSampleFiles.values) 'piano_samples/$file',
      for (var midi = 21; midi <= 108; midi++) ...[
        'electric_piano_samples/${fluidR3FileName(midi)}',
        'synth_samples/${fluidR3FileName(midi)}',
      ],
    };
    for (final assetPath in assetPaths) {
      final player = AudioPlayer();
      try {
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setVolume(0);
        await player.setSourceAsset(assetPath);
      } catch (_) {
        // На платформах без поддержки low-latency (или без файла) просто
        // не прогреваем кэш для этого сэмпла — первое нажатие сыграет как
        // обычно, чуть медленнее.
      }
      _preloaded.add(player);
    }
  }

  Future<void> noteDown(int midiPitch, ToneStyle style) async {
    // Если по этой же ноте ещё идёт плавное угасание после отпускания —
    // обрываем его немедленно (реальная клавиша заглушает демпфером старый
    // звук при новом ударе), а не даём ему тихо дозвучать поверх новой ноты.
    await _stopNote(midiPitch);
    final player = AudioPlayer();
    _players[midiPitch] = player;
    player.onPlayerComplete.first.then((_) {
      if (identical(_players[midiPitch], player)) {
        _players.remove(midiPitch);
        _heldByPedal.remove(midiPitch);
      }
      player.dispose();
    });

    // Между await'ами эта же клавиша может быть нажата повторно (быстрый
    // повтор, глиссандо туда-обратно) — тогда новый noteDown() вызовет
    // _stopNote() и удалит/уничтожит именно этот player раньше, чем мы
    // дойдём до resume(). Проверяем после каждого await, что мы всё ещё
    // актуальный плеер для этой ноты — иначе просто тихо выходим, не трогая
    // чужой (более новый) плеер и не проигрывая поверх него.
    bool stillCurrent() => identical(_players[midiPitch], player);

    try {
      final sample = sampleFor(midiPitch, style);
      // low-latency (SoundPool на Android) — сэмплы уже прогреты в
      // preload(), проигрывание стартует мгновенно, в отличие от
      // MediaPlayer, который под каждое нажатие готовит новый нативный
      // плеер заново — на быстрых повторах это и давало пропуски звука.
      // Заодно SoundPool меняет высоту тона напрямую через скорость
      // (ресемплинг), без «сохранения высоты тона», которое ломало
      // питч-шифт в MediaPlayer.
      await player.setPlayerMode(PlayerMode.lowLatency);
      if (!stillCurrent()) return;
      await player.setSourceAsset(sample.assetPath.replaceFirst('assets/', ''));
      if (!stillCurrent()) return;
      await player.setPlaybackRate(sample.playbackRate);
      if (!stillCurrent()) return;
      await player.resume();
    } catch (_) {
      // Плеер могли остановить/уничтожить параллельным вызовом — это не
      // ошибка, просто эта нота проиграна не будет (её место уже занято
      // более новым нажатием).
    }
  }

  /// Отпускание клавиши. Если педаль зажата ([sustain]) — нота продолжает
  /// звучать; иначе быстро гасится, как демпфер реального пианино.
  Future<void> noteUp(int midiPitch, {required bool sustain}) async {
    if (sustain) {
      _heldByPedal.add(midiPitch);
      return;
    }
    await _stopNote(midiPitch, fade: true);
  }

  /// Отпускание педали — гасит все ноты, которые звучали только благодаря ей.
  Future<void> releasePedal() async {
    final held = _heldByPedal.toList();
    _heldByPedal.clear();
    for (final midi in held) {
      await _stopNote(midi, fade: true);
    }
  }

  Future<void> _stopNote(int midiPitch, {bool fade = false}) async {
    // Плеер НЕ убираем из карты сразу — пока идёт угасание, он должен
    // оставаться «текущим» для этой ноты, чтобы noteDown() при повторном
    // нажатии мог его найти и оборвать немедленно (см. комментарий выше).
    final player = _players[midiPitch];
    _heldByPedal.remove(midiPitch);
    if (player == null) return;

    if (fade) {
      // Плавное затухание: много мелких шагов по квадратичной кривой —
      // на слух воспринимается мягче, чем резкий линейный спад в 3-4 шага.
      const steps = 18;
      const stepDuration = Duration(milliseconds: 10); // ~180мс всего
      for (var i = 1; i <= steps; i++) {
        // Клавишу успели нажать заново — эту ноту уже добивает другой
        // вызов _stopNote(), выходим, не трогая чужой плеер.
        if (!identical(_players[midiPitch], player)) return;
        final remaining = 1 - i / steps;
        try {
          await player.setVolume(remaining * remaining);
        } catch (_) {
          break;
        }
        await Future.delayed(stepDuration);
      }
    }

    if (identical(_players[midiPitch], player)) {
      _players.remove(midiPitch);
    }
    try {
      await player.stop();
    } catch (_) {
      // плеер уже мог доиграть и освободиться сам — это не ошибка
    } finally {
      await player.dispose();
    }
  }

  Future<void> dispose() async {
    for (final p in _preloaded) {
      await p.dispose();
    }
    _preloaded.clear();
  }
}
