import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'tone_synth.dart';

/// Проигрывает синтезированный звук ноты по MIDI-номеру в выбранном тембре
/// и с выбранной длительностью. Отслеживает активные ноты, чтобы отпускание
/// клавиши реально гасило звук (как демпфер настоящего пианино), а зажатая
/// педаль сустейна оставляла ноту звучать после отпускания клавиши.
class PianoSound {
  final _toneCache = <String, Uint8List>{};
  final _players = <int, AudioPlayer>{};
  final _heldByPedal = <int>{};

  Uint8List _toneFor(int midi, ToneStyle style, double durationScale) =>
      _toneCache.putIfAbsent(
        '${style.name}_${midi}_${durationScale.toStringAsFixed(2)}',
        () => generateToneWav(midiToFrequency(midi),
            style: style, durationScale: durationScale),
      );

  Future<void> noteDown(int midiPitch, ToneStyle style, double durationScale) async {
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
    await player.play(BytesSource(_toneFor(midiPitch, style, durationScale)));
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
    final player = _players.remove(midiPitch);
    _heldByPedal.remove(midiPitch);
    if (player == null) return;
    try {
      if (fade) {
        // Плавное затухание: много мелких шагов по квадратичной кривой —
        // на слух воспринимается мягче, чем резкий линейный спад в 3-4 шага.
        const steps = 18;
        const stepDuration = Duration(milliseconds: 10); // ~180мс всего
        for (var i = 1; i <= steps; i++) {
          final remaining = 1 - i / steps;
          await player.setVolume(remaining * remaining);
          await Future.delayed(stepDuration);
        }
      }
      await player.stop();
    } catch (_) {
      // плеер уже мог доиграть и освободиться сам — это не ошибка
    } finally {
      await player.dispose();
    }
  }
}
