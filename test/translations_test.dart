import 'package:flutter_test/flutter_test.dart';
import 'package:piano_notation/app_settings.dart';
import 'package:piano_notation/tone_synth.dart';
import 'package:piano_notation/translations.dart';

// Universal language test: iterates over AppLanguage.values, so a newly added
// language is checked automatically without touching this file.
void main() {
  test('every key is translated into every language', () {
    for (final key in translationKeys) {
      for (final lang in AppLanguage.values) {
        final text = lang.tr(key);
        expect(text, isNot(equals(key)), reason: '"$key" missing for $lang');
        expect(text.trim(), isNotEmpty, reason: '"$key" empty for $lang');
      }
    }
  });

  test('every language has a label', () {
    for (final lang in AppLanguage.values) {
      expect(languageLabel(lang), isNotEmpty);
    }
  });

  test('every sound style is labelled in every language', () {
    for (final style in ToneStyle.values) {
      for (final lang in AppLanguage.values) {
        expect(soundStyleLabel(style, lang), isNotEmpty, reason: '$style / $lang');
      }
    }
  });

  test('unknown key falls back to the key itself', () {
    expect(AppLanguage.en.tr('__no_such_key__'), '__no_such_key__');
  });
}
