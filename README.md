# Играй → Ноты — Dart-код

Файлы:

- `lib/note_models.dart` — `NoteEvent`, `QuantizedNote`
- `lib/quantizer.dart` — квантизация к тактовой сетке (16-е ноты, 4/4)
- `lib/staff_position.dart` — маппинг MIDI-питча на позицию на скрипичном ключе
- `lib/staff_painter.dart` — `CustomPainter`, рисует стан/ноты/паузы/лиговки
- `lib/pdf_export.dart` — рендер в PNG + вставка в PDF через пакет `pdf`
- `lib/example_usage.dart` — пример экрана, связывающий всё вместе (не финальный UI, а иллюстрация проводки)

## Зависимости (добавить в pubspec.yaml)

```yaml
dependencies:
  pdf: ^3.10.0
  printing: ^5.11.0
```

(у тебя они, скорее всего, уже есть — этот же стек использовался в DT Calc / Davomat для экспорта).

## Как подключить к своей клавиатуре

Вызывай `onKeyDown(midi)` / `onKeyUp(midi)` из `example_usage.dart` в обработчиках
твоего существующего piano-виджета (там, где у тебя уже что-то вроде
`onTapDown`/`onTapUp` по клавише). Дальше пайплайн стандартный:

```
события → quantize(events, bpm) → List<List<QuantizedNote>>
        → StaffPainter (экран) / renderStaffToPdf (файл)
```

## Благодарности

Приложение бесплатное для музыкальных школ и использует только сэмплы с
открытой лицензией:

- **Пианино** — [Salamander Grand Piano V3](https://archive.org/details/SalamanderGrandPianoV3)
  Александра Холма (Alexander Holm), лицензия CC BY 3.0. Mp3-версия — из пакета
  [samples-piano-mp3](https://github.com/darosh/samples-piano-mp3) (Jan Forst).
- **Электропиано / синтезатор** — [FluidR3 GM SoundFont](http://www.synthfont.com/SoundFonts/FluidR3_GM.sfArk)
  Фрэнка Вена (Frank Wen), лицензия MIT. Mp3-конвертация — пакет
  [soundfont-for-samplers](https://www.npmjs.com/package/soundfont-for-samplers)
  (K.G.Studio, MIT), по методике [midi-js-soundfonts](https://github.com/gleitz/midi-js-soundfonts)
  Бенджамина Гляйцмана (Benjamin Gleitzman).

Спасибо всем троим — без их открытых записей это приложение звучало бы
гораздо хуже.

## Известные упрощения MVP

- монофония — предполагается одна нота одновременно (для полифонии
  `quantize()` нужно переписать под несколько параллельных голосов)
- только диезы, без выбора тональности/бемолей
- восьмые/шестнадцатые не группируются в лиги — у каждой свой флажок
- паузы — упрощённые векторные глифы, не полноценная гравировка
