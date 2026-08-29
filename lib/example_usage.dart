// Экран: запись событий с виртуальной клавиатуры пианино, квантизация,
// отрисовка нотного стана и экспорт в PDF. Состояние — через Riverpod
// (см. notation_state.dart), звук клавиш — через PianoSound.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'app_settings.dart';
import 'notation_state.dart';
import 'settings_drawer.dart';
import 'staff_painter.dart';
import 'pdf_export.dart';
import 'piano_keyboard.dart';
import 'piano_sound.dart';
import 'translations.dart';

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
  }

  @override
  void dispose() {
    _pianoScrollController.dispose();
    _sound.dispose();
    super.dispose();
  }

  void _onKeyDown(int midiPitch) {
    final settings = ref.read(appSettingsProvider);
    _sound.noteDown(midiPitch, settings.soundStyle);
    ref.read(notationControllerProvider.notifier).noteOn(midiPitch);
  }

  void _onKeyUp(int midiPitch) {
    final sustain = ref.read(notationControllerProvider).sustain;
    _sound.noteUp(midiPitch, sustain: sustain);
    ref.read(notationControllerProvider.notifier).noteOff(midiPitch);
  }

  void _onToggleSustain() {
    final wasOn = ref.read(notationControllerProvider).sustain;
    ref.read(notationControllerProvider.notifier).toggleSustain();
    if (wasOn) {
      _sound.releasePedal();
    }
  }

  Future<void> _exportPdf(NotationState state, AppLanguage lang) async {
    if (state.measures == null || state.measures!.isEmpty) return;
    final bytes = await renderStaffToPdf(
        measures: state.measures!, bpm: state.bpm, lang: lang);
    await Printing.sharePdf(bytes: bytes, filename: 'melody.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notationControllerProvider);
    final controller = ref.read(notationControllerProvider.notifier);
    final lang = ref.watch(appSettingsProvider).language;
    // В альбомной ориентации (короткий экран) клавиатура не должна съедать
    // всю высоту — иначе ноты сверху не помещаются.
    final screenHeight = MediaQuery.sizeOf(context).height;
    final keyboardHeight = (screenHeight * 0.46).clamp(185.0, 380.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.tr('appTitle')),
        actions: [
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
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: lang.tr('exportPdf'),
            onPressed: (state.measures?.isNotEmpty ?? false)
                ? () => _exportPdf(state, lang)
                : null,
          ),
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
                                size: StaffPainter.computeSize(state.measures!.length),
                                painter: StaffPainter(
                                    measures: state.measures!, bpm: state.bpm),
                              ),
                            ),
                          ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
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
                    bottom: 16,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 2),
              child: PianoKeyboard(
                onKeyDown: _onKeyDown,
                onKeyUp: _onKeyUp,
                height: keyboardHeight,
                whiteKeyWidth: _keyWidth,
                scrollController: _pianoScrollController,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
