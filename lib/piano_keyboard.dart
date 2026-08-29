import 'package:flutter/material.dart';
import 'staff_position.dart';

String _noteName(int midi) {
  final pos = staffPositionFor(midi);
  final octave = (midi ~/ 12) - 1;
  return '${pos.letter}${pos.sharp ? '♯' : ''}$octave';
}

class _KeyLayout {
  final List<int> whiteMidis; // индекс белой клавиши -> MIDI
  final List<({int afterWhiteIndex, int midi})> blackKeys;
  _KeyLayout(this.whiteMidis, this.blackKeys);
}

/// Виртуальная клавиатура пианино: по умолчанию — полный диапазон
/// настоящего фортепиано, 88 клавиш от A0 (21) до C8 (108). С подписями
/// нот на каждой клавише. По нажатию/отпусканию вызывает [onKeyDown] и
/// [onKeyUp] с MIDI-номером ноты — их слушает example_usage.dart.
/// Клавиатура шире экрана — прокручивается по горизонтали. Поддерживает
/// глиссандо: если вести палец/мышь с зажатой кнопкой по клавишам подряд,
/// не отпуская, звучит каждая клавиша под пальцем — как на настоящем
/// пианино, а не только та, где было первое касание.
class PianoKeyboard extends StatefulWidget {
  final void Function(int midiPitch) onKeyDown;
  final void Function(int midiPitch) onKeyUp;
  final int startMidi;
  final int endMidi;
  final double height;
  // Ширина белой клавиши — управляется снаружи кнопками +/- (см.
  // example_usage.dart), как и scrollController ниже.
  final double whiteKeyWidth;
  // Внешний контроллер скролла — чтобы можно было листать клавиатуру
  // кнопками снаружи (см. example_usage.dart), а не перетаскиванием по
  // клавишам: перетаскивание по клавишам уже занято глиссандо и конфликтует
  // со скроллом (ноты залипают на полпути).
  final ScrollController? scrollController;
  // Ноты, нажатые не пальцем/мышью по этому виджету, а снаружи (например,
  // физической клавиатурой компьютера — см. example_usage.dart) — тоже
  // подсвечиваются, чтобы визуально было видно, что клавиша звучит.
  final Set<int> externalActiveMidis;

  const PianoKeyboard({
    super.key,
    required this.onKeyDown,
    required this.onKeyUp,
    this.startMidi = 21, // A0
    this.endMidi = 108, // C8
    this.height = 380,
    this.whiteKeyWidth = 54,
    this.scrollController,
    this.externalActiveMidis = const {},
  });

  @override
  State<PianoKeyboard> createState() => _PianoKeyboardState();
}

class _PianoKeyboardState extends State<PianoKeyboard> {
  ScrollController? _ownScrollController;
  final _pointerToMidi = <int, int>{};
  final Set<int> _activeMidis = {};

  ScrollController get _scrollController =>
      widget.scrollController ?? (_ownScrollController ??= ScrollController());

  @override
  void dispose() {
    _ownScrollController?.dispose();
    super.dispose();
  }

  _KeyLayout _computeLayout() {
    final whiteMidis = <int>[];
    final blackKeys = <({int afterWhiteIndex, int midi})>[];
    for (var midi = widget.startMidi; midi <= widget.endMidi; midi++) {
      if (staffPositionFor(midi).sharp) {
        blackKeys.add((afterWhiteIndex: whiteMidis.length, midi: midi));
      } else {
        whiteMidis.add(midi);
      }
    }
    return _KeyLayout(whiteMidis, blackKeys);
  }

  int? _keyAt(
    Offset local,
    _KeyLayout layout,
    double whiteKeyWidth,
    double blackKeyWidth,
    double blackKeyHeight,
    double totalWidth,
  ) {
    if (local.dx < 0 || local.dx > totalWidth || local.dy < 0) return null;

    if (local.dy < blackKeyHeight) {
      for (final b in layout.blackKeys) {
        final centerX = b.afterWhiteIndex * whiteKeyWidth;
        if (local.dx >= centerX - blackKeyWidth / 2 &&
            local.dx <= centerX + blackKeyWidth / 2) {
          return b.midi;
        }
      }
    }

    final whiteIndex =
        (local.dx / whiteKeyWidth).floor().clamp(0, layout.whiteMidis.length - 1);
    return layout.whiteMidis[whiteIndex];
  }

  void _updatePointer(int pointer, int? midi) {
    final prev = _pointerToMidi[pointer];
    if (prev == midi) return;
    if (prev != null) widget.onKeyUp(prev);
    if (midi != null) {
      _pointerToMidi[pointer] = midi;
      widget.onKeyDown(midi);
    } else {
      _pointerToMidi.remove(pointer);
    }
    setState(() {
      _activeMidis
        ..clear()
        ..addAll(_pointerToMidi.values);
    });
  }

  void _releasePointer(int pointer) {
    final midi = _pointerToMidi.remove(pointer);
    if (midi == null) return;
    widget.onKeyUp(midi);
    setState(() {
      _activeMidis
        ..clear()
        ..addAll(_pointerToMidi.values);
    });
  }

  @override
  Widget build(BuildContext context) {
    final whiteKeyWidth = widget.whiteKeyWidth;
    final blackKeyWidth = whiteKeyWidth * 0.6;
    final blackKeyHeight = widget.height * 0.6;
    final layout = _computeLayout();
    final totalWidth = layout.whiteMidis.length * whiteKeyWidth;
    bool isPressed(int midi) =>
        _activeMidis.contains(midi) || widget.externalActiveMidis.contains(midi);

    final whiteKeyWidgets = [
      for (final midi in layout.whiteMidis)
        _PianoKey(
          width: whiteKeyWidth,
          height: widget.height,
          isBlack: false,
          label: _noteName(midi),
          pressed: isPressed(midi),
        ),
    ];

    final blackKeyWidgets = [
      for (final b in layout.blackKeys)
        Positioned(
          left: b.afterWhiteIndex * whiteKeyWidth - blackKeyWidth / 2,
          child: _PianoKey(
            width: blackKeyWidth,
            height: blackKeyHeight,
            isBlack: true,
            label: _noteName(b.midi),
            pressed: isPressed(b.midi),
          ),
        ),
    ];

    return SizedBox(
      height: widget.height + _miniMapHeight,
      child: Column(
        children: [
          _MiniKeyboardNav(
            layout: layout,
            totalWidth: totalWidth,
            scrollController: _scrollController,
            height: _miniMapHeight,
          ),
          SizedBox(
            height: widget.height,
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              // Листание клавиатуры перетаскиванием отключено (это
              // глиссандо), а полосу листают через мини-навигатор сверху —
              // поэтому сам скроллбар не должен реагировать на касания.
              // Иначе он мог перехватывать тап у самого нижнего края
              // клавиш (где подписи нот), не давая нажать.
              interactive: false,
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                // Перетаскивание по клавишам — это глиссандо, не скролл.
                // Листать клавиатуру можно только мини-навигатором сверху.
                physics: const NeverScrollableScrollPhysics(),
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) => _updatePointer(
                    e.pointer,
                    _keyAt(e.localPosition, layout, whiteKeyWidth,
                        blackKeyWidth, blackKeyHeight, totalWidth),
                  ),
                  onPointerMove: (e) => _updatePointer(
                    e.pointer,
                    _keyAt(e.localPosition, layout, whiteKeyWidth,
                        blackKeyWidth, blackKeyHeight, totalWidth),
                  ),
                  onPointerUp: (e) => _releasePointer(e.pointer),
                  onPointerCancel: (e) => _releasePointer(e.pointer),
                  child: SizedBox(
                    width: totalWidth,
                    height: widget.height,
                    child: Stack(
                      children: [
                        Row(children: whiteKeyWidgets),
                        ...blackKeyWidgets,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _miniMapHeight = 28.0;

/// Полоска-навигатор над клавиатурой: уменьшенная схема всей клавиатуры
/// (88 клавиш) с подсвеченным окном текущей видимой области. Тап или
/// протягивание пальцем по полоске сразу листает основную клавиатуру —
/// удобнее, чем стрелки листания по чуть-чуть.
class _MiniKeyboardNav extends StatelessWidget {
  final _KeyLayout layout;
  final double totalWidth;
  final ScrollController scrollController;
  final double height;

  const _MiniKeyboardNav({
    required this.layout,
    required this.totalWidth,
    required this.scrollController,
    required this.height,
  });

  // На самом первом кадре ScrollController уже "подключён" (hasClients),
  // но сам Scrollable ещё не прошёл ни одного layout — viewportDimension
  // в этот момент не установлен, и обращение к нему падает с null-check
  // ошибкой. hasPixels/hasContentDimensions гарантируют, что хотя бы один
  // layout уже случился.
  bool get _isReady =>
      scrollController.hasClients &&
      scrollController.position.hasViewportDimension &&
      scrollController.position.hasContentDimensions;

  void _scrollToLocalX(double localX, double scale) {
    if (!_isReady) return;
    final position = scrollController.position;
    final target = (localX / scale) - position.viewportDimension / 2;
    scrollController.jumpTo(
      target.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stripWidth = constraints.maxWidth;
        final scale = stripWidth / totalWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _scrollToLocalX(d.localPosition.dx, scale),
          onHorizontalDragUpdate: (d) => _scrollToLocalX(d.localPosition.dx, scale),
          child: AnimatedBuilder(
            animation: scrollController,
            builder: (context, _) {
              final ready = _isReady;
              return CustomPaint(
                size: Size(stripWidth, height),
                painter: _MiniMapPainter(
                  layout: layout,
                  totalWidth: totalWidth,
                  scale: scale,
                  offset: ready ? scrollController.offset : 0,
                  viewport: ready ? scrollController.position.viewportDimension : stripWidth,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  final _KeyLayout layout;
  final double totalWidth;
  final double scale;
  final double offset;
  final double viewport;

  _MiniMapPainter({
    required this.layout,
    required this.totalWidth,
    required this.scale,
    required this.offset,
    required this.viewport,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.grey.shade300);

    final whiteKeyWidthMini = size.width / layout.whiteMidis.length;
    final linePaint = Paint()
      ..color = Colors.grey.shade500
      ..strokeWidth = 1;
    for (var i = 1; i < layout.whiteMidis.length; i++) {
      final x = i * whiteKeyWidthMini;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }

    final blackPaint = Paint()..color = Colors.black87;
    final realWhiteKeyWidth = totalWidth / layout.whiteMidis.length;
    for (final b in layout.blackKeys) {
      final x = b.afterWhiteIndex * realWhiteKeyWidth * scale;
      canvas.drawRect(
        Rect.fromLTWH(x - 1.5, 0, 3, size.height * 0.6),
        blackPaint,
      );
    }

    final windowRect = Rect.fromLTWH(offset * scale, 0, viewport * scale, size.height);
    canvas.drawRect(windowRect, Paint()..color = Colors.blue.withValues(alpha: 0.35));
    canvas.drawRect(
      windowRect,
      Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) {
    return oldDelegate.offset != offset ||
        oldDelegate.viewport != viewport ||
        oldDelegate.scale != scale;
  }
}

class _PianoKey extends StatelessWidget {
  final double width;
  final double height;
  final bool isBlack;
  final String label;
  final bool pressed;

  const _PianoKey({
    required this.width,
    required this.height,
    required this.isBlack,
    required this.label,
    required this.pressed,
  });

  @override
  Widget build(BuildContext context) {
    final restColor = isBlack ? Colors.black : Colors.white;
    final pressedColor = isBlack ? Colors.grey.shade800 : Colors.grey.shade300;
    final labelColor = isBlack ? Colors.white70 : Colors.black54;

    return IgnorePointer(
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: pressed ? pressedColor : restColor,
          border: Border.all(color: Colors.black87, width: 1),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: isBlack ? 10 : 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
