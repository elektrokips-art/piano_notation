import 'dart:convert';
import 'dart:typed_data';
import 'note_models.dart';

/// Формат вложенных в PDF данных ноты — чтобы наше же приложение могло
/// открыть свой же экспортированный файл обратно и включить режим
/// «играть по нотам» (учитель делится одним PDF-файлом: и печатается, и
/// открывается в приложении для тренировки).
const notationFileMarker = 'piano_notation.json';
const _formatKey = 'app';
const _formatValue = 'piano_notation';
const _formatVersion = 1;

Map<String, dynamic> notationToJson(List<List<QuantizedNote>> measures, int bpm) {
  return {
    _formatKey: _formatValue,
    'version': _formatVersion,
    'bpm': bpm,
    'measures': [
      for (final measure in measures)
        [
          for (final n in measure)
            {
              if (n.midiPitches.isNotEmpty) 'p': n.midiPitches,
              'd': n.durationTicks,
            },
        ],
    ],
  };
}

class NotationFile {
  final int bpm;
  final List<List<QuantizedNote>> measures;
  const NotationFile({required this.bpm, required this.measures});
}

/// Разбирает JSON, вложенный в PDF (см. [notationToJson]). Возвращает null,
/// если это не наш формат — например, случайный сторонний PDF или файл с
/// повреждёнными данными; вызывающий код должен спокойно проигнорировать
/// такой файл, а не падать.
NotationFile? notationFromJson(Object? json) {
  if (json is! Map || json[_formatKey] != _formatValue) return null;
  try {
    final bpm = json['bpm'] as int;
    final rawMeasures = json['measures'] as List;
    final measures = <List<QuantizedNote>>[
      for (final rawMeasure in rawMeasures)
        [
          for (final rawNote in rawMeasure as List)
            QuantizedNote(
              midiPitches: [
                for (final p in (rawNote as Map)['p'] as List? ?? const [])
                  p as int,
              ],
              startTick: 0, // не используется при отрисовке/воспроизведении
              durationTicks: rawNote['d'] as int,
            ),
        ],
    ];
    return NotationFile(bpm: bpm, measures: measures);
  } catch (_) {
    return null;
  }
}

/// Уникальная подстрока внутри самого JSON (а не имени файла) — по ней ищем
/// stream с нашими данными напрямую, не полагаясь на то, в каком порядке
/// объекты записаны в PDF (сам stream с содержимым может физически лежать
/// в файле раньше, чем filespec-объект с именем файла, ссылающийся на него).
const _contentMarker = '"$_formatKey":"$_formatValue"';

/// Ищет вложенный JSON-файл нот внутри байтов PDF, сгенерированного нашим
/// же приложением (см. pdf_export.dart — там он вкладывается через
/// PdfaAttachedFiles). Наш экспорт не сжимает и не шифрует вложение, так что
/// его можно найти простым поиском по байтам, не разбирая PDF целиком.
/// Возвращает null для любого файла, где такого вложения нет — включая
/// произвольные сторонние PDF.
NotationFile? extractNotationFromPdfBytes(Uint8List bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  final markerIndex = text.indexOf(_contentMarker);
  if (markerIndex == -1) return null;

  final streamStart = text.lastIndexOf('stream', markerIndex);
  if (streamStart == -1) return null;
  // после ключевого слова "stream" сразу идёт перевод строки (\r\n или \n)
  var dataStart = streamStart + 'stream'.length;
  if (text.startsWith('\r\n', dataStart)) {
    dataStart += 2;
  } else if (text.startsWith('\n', dataStart)) {
    dataStart += 1;
  }
  final dataEnd = text.indexOf('endstream', markerIndex);
  if (dataEnd == -1) return null;

  try {
    final jsonBytes = bytes.sublist(dataStart, dataEnd);
    final decoded = jsonDecode(utf8.decode(jsonBytes));
    return notationFromJson(decoded);
  } catch (_) {
    return null;
  }
}
