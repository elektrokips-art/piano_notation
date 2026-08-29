// Экран: запись событий с виртуальной клавиатуры пианино, квантизация,
// отрисовка нотного стана и экспорт в PDF. Состояние — через Riverpod
// (см. notation_state.dart), звук клавиш — через PianoSound.

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'app_settings.dart';
import 'notation_file.dart';
import 'notation_state.dart';
import 'practice_state.dart';
import 'quantizer.dart' show ticksPerBeat;
import 'settings_drawer.dart';
import 'staff_painter.dart';
import 'staff_position.dart';
import 'pdf_export.dart';
import 'piano_keyboard.dart';
import 'piano_sound.dart';
import 'translations.dart';

String _noteName(int midi) {
  final pos = staffPositionFor(midi);
  final octave = (midi ~/ 12) - 1;
  return '${pos.letter}${pos.sharp ? '♯' : ''}$octave';
}

/// Игра с физической клавиатуры компьютера (Windows/web, где нет пальцев на
/// экране): нижний ряд — одна октава от C4, верхний ряд — следующая, чёрные
/// клавиши — на цифрах/буквах над зазорами между белыми. Стандартная схема,
/// знакомая по большинству "клавиатура-как-пианино" инструментов.
final _keyboardNoteMap = <LogicalKeyboardKey, int>{
  LogicalKeyboardKey.keyZ: 60, // C4
  LogicalKeyboardKey.keyS: 61,
  LogicalKeyboardKey.keyX: 62,
  LogicalKeyboardKey.keyD: 63,
  LogicalKeyboardKey.keyC: 64,
  LogicalKeyboardKey.keyV: 65,
  LogicalKeyboardKey.keyG: 66,
  LogicalKeyboardKey.keyB: 67,
  LogicalKeyboardKey.keyH: 68,
  LogicalKeyboardKey.keyN: 69,
  LogicalKeyboardKey.keyJ: 70,
  LogicalKeyboardKey.keyM: 71,
  LogicalKeyboardKey.keyQ: 72, // C5
  LogicalKeyboardKey.digit2: 73,
  LogicalKeyboardKey.keyW: 74,
  LogicalKeyboardKey.digit3: 75,
  LogicalKeyboardKey.keyE: 76,
  LogicalKeyboardKey.keyR: 77,
  LogicalKeyboardKey.digit5: 78,
  LogicalKeyboardKey.keyT: 79,
  LogicalKeyboardKey.digit6: 80,
  LogicalKeyboardKey.keyY: 81,
  LogicalKeyboardKey.digit7: 82,
  LogicalKeyboardKey.keyU: 83,
  LogicalKeyboardKey.keyI: 84, // C6
};

class NotationExampleScreen extends ConsumerStatefulWidget {
  const NotationExampleScreen({super.key});

  @override
  ConsumerState<NotationExampleScreen> createState() =>
      _NotationExampleScreenState();
}

class _NotationExampleScreenState
    extends ConsumerState<NotationExampleScreen> {
  final _sound = PianoSound();
  final _pianoScrollController = ScrollController();
  double _keyWidth = 54;
  bool _keyboardVisible = true;
  final _physicalKeysDown = <LogicalKeyboardKey>{};
  final _physicalActiveMidis = <int>{};
  final _heldMidis = <int>{}; // все сейчас зажатые клавиши (любым способом)
  bool _practicePaused = false; // пауза в режиме "ждать клавишу"
  Timer? _autoPlayTimer;
  bool _autoPlaying = false;

  static const _minKeyWidth = 32.0;
  static const _maxKeyWidth = 90.0;

  void _zoomKeys(double delta) {
    setState(() {
      _keyWidth = (_keyWidth + delta).clamp(_minKeyWidth, _maxKeyWidth);
    });
  }

  @override
  void initState() {
    super.initState();
    _sound.preload();
    HardwareKeyboard.instance.addHandler(_handlePhysicalKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handlePhysicalKey);
    _autoPlayTimer?.cancel();
    _pianoScrollController.dispose();
    _sound.dispose();
    super.dispose();
  }

  // Игра с физической клавиатуры компьютера — те же noteDown/noteUp, что и
  // от тапов по экранной клавиатуре, плюс подсветка соответствующей клавиши
  // и автопрокрутка к ней, если она сейчас не видна.
  bool _handlePhysicalKey(KeyEvent event) {
    final midi = _keyboardNoteMap[event.logicalKey];
    if (midi == null) return false;
    if (event is KeyDownEvent) {
      if (_physicalKeysDown.add(event.logicalKey)) {
        _onKeyDown(midi);
        _scrollToNote(midi);
        setState(() => _physicalActiveMidis.add(midi));
      }
      return true;
    }
    if (event is KeyUpEvent) {
      _physicalKeysDown.remove(event.logicalKey);
      _onKeyUp(midi);
      setState(() => _physicalActiveMidis.remove(midi));
      return true;
    }
    return false;
  }

  void _scrollToNote(int midi) {
    if (!_pianoScrollController.hasClients) return;
    final position = _pianoScrollController.position;
    if (!position.hasViewportDimension || !position.hasContentDimensions) return;

    var whiteIndex = 0;
    for (var m = 21; m < midi; m++) {
      if (!staffPositionFor(m).sharp) whiteIndex++;
    }
    final noteX = whiteIndex * _keyWidth;
    final viewStart = position.pixels;
    final viewEnd = viewStart + position.viewportDimension;
    if (noteX >= viewStart && noteX <= viewEnd - _keyWidth) return;

    final target = (noteX - position.viewportDimension / 2)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    _pianoScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _onKeyDown(int midiPitch) {
    final settings = ref.read(appSettingsProvider);
    _sound.noteDown(midiPitch, settings.soundStyle);
    _heldMidis.add(midiPitch);
    if (ref.read(practiceControllerProvider).active) {
      // В автоигре плеер сам решает, что и когда звучит — нажатия клавиш
      // пользователем позицию не двигают (но звук выше всё равно сыграл).
      if (settings.practiceMode == PracticeMode.waitForKey) {
        _checkPracticeMatch();
      }
    } else {
      ref.read(notationControllerProvider.notifier).noteOn(midiPitch);
    }
  }

  void _onKeyUp(int midiPitch) {
    final sustain = ref.read(notationControllerProvider).sustain;
    _sound.noteUp(midiPitch, sustain: sustain);
    _heldMidis.remove(midiPitch);
    if (!ref.read(practiceControllerProvider).active) {
      ref.read(notationControllerProvider.notifier).noteOff(midiPitch);
    }
  }

  // Тренажёр: как только зажатые клавиши совпали ровно с ожидаемой нотой
  // (или аккордом), переходим к следующей.
  void _checkPracticeMatch() {
    if (_practicePaused) return;
    final practice = ref.read(practiceControllerProvider);
    final current = practice.current;
    if (current == null || current.isRest) return;
    if (setEquals(_heldMidis, current.midiPitches.toSet())) {
      ref.read(practiceControllerProvider.notifier).advance();
      final next = ref.read(practiceControllerProvider).current;
      if (next != null && next.midiPitches.isNotEmpty) {
        _scrollToNote(next.midiPitches.first);
      }
    }
  }

  Future<void> _openPiece(AppLanguage lang) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (files.isEmpty) return;
    final bytes = await files.first.readAsBytes();

    final notation = extractNotationFromPdfBytes(bytes);
    if (notation == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(lang.tr('notOurFile'))));
      }
      return;
    }

    _pauseAutoPlay();
    setState(() => _practicePaused = false);
    if (ref.read(notationControllerProvider).recording) {
      ref.read(notationControllerProvider.notifier).toggleRecording();
    }
    ref
        .read(notationControllerProvider.notifier)
        .loadPiece(notation.measures, notation.bpm);
    ref
        .read(practiceControllerProvider.notifier)
        .load(notation.measures, notation.bpm);
    final first = ref.read(practiceControllerProvider).current;
    if (first != null && first.midiPitches.isNotEmpty) {
      _scrollToNote(first.midiPitches.first);
    }
  }

  void _closePractice() {
    _pauseAutoPlay();
    setState(() => _practicePaused = false);
    ref.read(practiceControllerProvider.notifier).stop();
  }

  /// Пауза — останавливает таймер автоигры, но НЕ сбрасывает позицию: play
  /// после паузы продолжит с того же места.
  void _pauseAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;
    if (_autoPlaying) setState(() => _autoPlaying = false);
  }

  /// Стоп — останавливает и возвращает пьесу к началу (в отличие от паузы).
  void _stopAutoPlay() {
    _pauseAutoPlay();
    ref.read(practiceControllerProvider.notifier).restart();
  }

  void _startAutoPlay() {
    if (!ref.read(practiceControllerProvider).active) return;
    // Если пьеса доиграна до конца — начинаем заново, иначе play после
    // завершения молча ничего не делал бы (current уже null).
    if (ref.read(practiceControllerProvider).finished) {
      ref.read(practiceControllerProvider.notifier).restart();
    }
    setState(() => _autoPlaying = true);
    _scheduleAutoPlayStep();
  }

  void _scheduleAutoPlayStep() {
    final practice = ref.read(practiceControllerProvider);
    final current = practice.current;
    final notifier = ref.read(practiceControllerProvider.notifier);

    if (current == null) {
      _pauseAutoPlay();
      notifier.restart(); // готовим play к чистому повторному запуску
      _showPracticeFinished();
      return;
    }
    if (current.isRest) {
      notifier.advance();
      _scheduleAutoPlayStep();
      return;
    }

    final settings = ref.read(appSettingsProvider);
    for (final p in current.midiPitches) {
      _sound.noteDown(p, settings.soundStyle);
    }
    _scrollToNote(current.midiPitches.first);

    final msPerTick = (60 / practice.bpm / ticksPerBeat) * 1000;
    final durationMs = (current.durationTicks * msPerTick).round();
    _autoPlayTimer = Timer(Duration(milliseconds: durationMs), () {
      for (final p in current.midiPitches) {
        _sound.noteUp(p, sustain: false);
      }
      notifier.advance();
      if (mounted && _autoPlaying) _scheduleAutoPlayStep();
    });
  }

  void _showPracticeFinished() {
    final lang = ref.read(appSettingsProvider).language;
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(lang.tr('practiceFinished'))));
    }
  }

  void _onToggleSustain() {
    final wasOn = ref.read(notationControllerProvider).sustain;
    ref.read(notationControllerProvider.notifier).toggleSustain();
    if (wasOn) {
      _sound.releasePedal();
    }
  }

  Future<Uint8List?> _buildPdf(NotationState state, AppLanguage lang, bool grandStaff) async {
    if (state.measures == null || state.measures!.isEmpty) return null;
    return renderStaffToPdf(
        measures: state.measures!, bpm: state.bpm, lang: lang, grandStaff: grandStaff);
  }

  /// Отдельно от «Поделиться»: пишет файл напрямую через системный диалог
  /// сохранения, чтобы получить PDF в файловой системе устройства без
  /// обходного пути через сторонний просмотрщик и его «сохранить копию».
  Future<void> _savePdf(NotationState state, AppLanguage lang, bool grandStaff) async {
    final bytes = await _buildPdf(state, lang, grandStaff);
    if (bytes == null) return;
    final uri = await FilePicker.saveFile(
      fileName: 'melody.pdf',
      bytes: bytes,
      mimeType: 'application/pdf',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (uri != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.tr('pdfSaved'))));
    }
  }

  Future<void> _sharePdf(NotationState state, AppLanguage lang, bool grandStaff) async {
    final bytes = await _buildPdf(state, lang, grandStaff);
    if (bytes == null) return;
    await Printing.sharePdf(bytes: bytes, filename: 'melody.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notationControllerProvider);
    final controller = ref.read(notationControllerProvider.notifier);
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;
    final practice = ref.watch(practiceControllerProvider);
    ref.listen(practiceControllerProvider, (previous, next) {
      if (next.finished && previous?.finished != true) {
        _showPracticeFinished();
      }
    });
    // В альбомной ориентации (короткий экран) клавиатура не должна съедать
    // всю высоту — иначе ноты сверху не помещаются.
    final screenHeight = MediaQuery.sizeOf(context).height;
    final keyboardHeight = (screenHeight * 0.46).clamp(185.0, 380.0);

    final expectedMidis = practice.active
        ? (practice.current?.midiPitches.toSet() ?? const <int>{})
        : const <int>{};

    return Scaffold(
      appBar: AppBar(
        title: Text(practice.active ? lang.tr('openPiece') : lang.tr('appTitle')),
        actions: [
          IconButton(
            icon: Icon(_keyboardVisible ? Icons.keyboard_hide : Icons.piano),
            tooltip: _keyboardVisible
                ? lang.tr('hideKeyboard')
                : lang.tr('showKeyboard'),
            onPressed: () => setState(() => _keyboardVisible = !_keyboardVisible),
          ),
          if (practice.active) ...[
            if (settings.practiceMode == PracticeMode.autoPlay) ...[
              IconButton(
                icon: Icon(_autoPlaying ? Icons.pause : Icons.play_arrow),
                tooltip: _autoPlaying ? lang.tr('pause') : lang.tr('play'),
                onPressed: _autoPlaying ? _pauseAutoPlay : _startAutoPlay,
              ),
              IconButton(
                icon: const Icon(Icons.stop),
                tooltip: lang.tr('stopPlayback'),
                onPressed: _stopAutoPlay,
              ),
            ] else ...[
              // "Ждать клавишу": плей/пауза приостанавливает проверку
              // нажатий (не сбрасывая позицию), стоп возвращает к началу.
              IconButton(
                icon: Icon(_practicePaused ? Icons.play_arrow : Icons.pause),
                tooltip: _practicePaused ? lang.tr('play') : lang.tr('pause'),
                onPressed: () =>
                    setState(() => _practicePaused = !_practicePaused),
              ),
              IconButton(
                icon: const Icon(Icons.stop),
                tooltip: lang.tr('stopPlayback'),
                onPressed: () {
                  ref.read(practiceControllerProvider.notifier).restart();
                  setState(() => _practicePaused = false);
                },
              ),
            ],
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: lang.tr('exitPractice'),
              onPressed: _closePractice,
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.folder_open),
              tooltip: lang.tr('openPiece'),
              onPressed: () => _openPiece(lang),
            ),
            IconButton(
              icon: Icon(state.recording ? Icons.stop : Icons.fiber_manual_record),
              tooltip: state.recording ? lang.tr('stop') : lang.tr('record'),
              onPressed: controller.toggleRecording,
            ),
            IconButton(
              icon: const Icon(Icons.music_note),
              tooltip: lang.tr('renderNotes'),
              onPressed: state.events.isEmpty ? null : controller.renderNotes,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: lang.tr('reset'),
              onPressed: (state.events.isEmpty && state.measures == null)
                  ? null
                  : controller.reset,
            ),
            PopupMenuButton<VoidCallback>(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: lang.tr('exportPdf'),
              enabled: state.measures?.isNotEmpty ?? false,
              onSelected: (action) => action(),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: () => _savePdf(state, lang, settings.staffMode == StaffMode.grand),
                  child: Row(children: [
                    const Icon(Icons.save_alt),
                    const SizedBox(width: 12),
                    Text(lang.tr('savePdf')),
                  ]),
                ),
                PopupMenuItem(
                  value: () => _sharePdf(state, lang, settings.staffMode == StaffMode.grand),
                  child: Row(children: [
                    const Icon(Icons.share),
                    const SizedBox(width: 12),
                    Text(lang.tr('sharePdf')),
                  ]),
                ),
              ],
            ),
          ],
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.settings),
              tooltip: lang.tr('settings'),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: const SettingsDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: state.measures == null
                        ? Center(child: Text(lang.tr('placeholder')))
                        : SingleChildScrollView(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: CustomPaint(
                                size: StaffPainter.computeSize(state.measures!.length,
                                    grandStaff: settings.staffMode == StaffMode.grand),
                                painter: StaffPainter(
                                  measures: state.measures!,
                                  bpm: state.bpm,
                                  grandStaff: settings.staffMode == StaffMode.grand,
                                ),
                              ),
                            ),
                          ),
                  ),
                  if (practice.active)
                    Positioned(
                      top: 8,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            practice.finished
                                ? lang.tr('practiceFinished')
                                : practice.current == null
                                    ? ''
                                    : settings.practiceMode == PracticeMode.waitForKey &&
                                            _practicePaused
                                        ? '⏸ ${lang.tr('pause')}'
                                        : '${lang.tr('practiceHint')}: '
                                            '${practice.current!.midiPitches.map(_noteName).join(' + ')}'
                                            '  ·  ${practice.index + 1}/${practice.notes.length}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 16,
                    bottom: 0,
                    child: FloatingActionButton.small(
                      heroTag: 'sustainPedal',
                      onPressed: _onToggleSustain,
                      backgroundColor:
                          state.sustain ? Colors.red.shade400 : Colors.grey.shade300,
                      foregroundColor:
                          state.sustain ? Colors.white : Colors.black87,
                      elevation: state.sustain ? 6 : 2,
                      tooltip: lang.tr('sustainPedal'),
                      child: Icon(state.sustain ? Icons.circle : Icons.circle_outlined),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    bottom: 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'keyZoomOut',
                          tooltip: lang.tr('keySizeSmaller'),
                          onPressed:
                              _keyWidth > _minKeyWidth ? () => _zoomKeys(-6) : null,
                          child: const Icon(Icons.remove),
                        ),
                        const SizedBox(width: 8),
                        FloatingActionButton.small(
                          heroTag: 'keyZoomIn',
                          tooltip: lang.tr('keySizeBigger'),
                          onPressed:
                              _keyWidth < _maxKeyWidth ? () => _zoomKeys(6) : null,
                          child: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _keyboardVisible
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 2),
                      child: PianoKeyboard(
                        onKeyDown: _onKeyDown,
                        onKeyUp: _onKeyUp,
                        height: keyboardHeight,
                        whiteKeyWidth: _keyWidth,
                        scrollController: _pianoScrollController,
                        externalActiveMidis: _physicalActiveMidis,
                        practiceHintMidis: expectedMidis,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}
