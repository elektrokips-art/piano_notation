import 'app_settings.dart';
import 'tone_synth.dart';

const _strings = <String, Map<AppLanguage, String>>{
  'appTitle': {
    AppLanguage.ru: 'Играй → ноты',
    AppLanguage.uz: 'Chal → notalar',
    AppLanguage.en: 'Play → notes',
  },
  'record': {
    AppLanguage.ru: 'Запись',
    AppLanguage.uz: 'Yozish',
    AppLanguage.en: 'Record',
  },
  'stop': {
    AppLanguage.ru: 'Стоп',
    AppLanguage.uz: 'Toʻxtatish',
    AppLanguage.en: 'Stop',
  },
  'renderNotes': {
    AppLanguage.ru: 'Собрать ноты',
    AppLanguage.uz: 'Notalarni yigʻish',
    AppLanguage.en: 'Build notes',
  },
  'reset': {
    AppLanguage.ru: 'Сброс',
    AppLanguage.uz: 'Tozalash',
    AppLanguage.en: 'Reset',
  },
  'sustainPedal': {
    AppLanguage.ru: 'Педаль (сустейн)',
    AppLanguage.uz: 'Pedal (sustain)',
    AppLanguage.en: 'Sustain pedal',
  },
  'exportPdf': {
    AppLanguage.ru: 'Экспорт PDF',
    AppLanguage.uz: 'PDF eksport',
    AppLanguage.en: 'Export PDF',
  },
  'placeholder': {
    AppLanguage.ru: 'здесь появятся ноты после записи',
    AppLanguage.uz: 'yozuvdan keyin bu yerda notalar chiqadi',
    AppLanguage.en: 'notes will appear here after recording',
  },
  'settings': {
    AppLanguage.ru: 'Настройки',
    AppLanguage.uz: 'Sozlamalar',
    AppLanguage.en: 'Settings',
  },
  'language': {
    AppLanguage.ru: 'Язык',
    AppLanguage.uz: 'Til',
    AppLanguage.en: 'Language',
  },
  'theme': {
    AppLanguage.ru: 'Тема',
    AppLanguage.uz: 'Mavzu',
    AppLanguage.en: 'Theme',
  },
  'themeLight': {
    AppLanguage.ru: 'Светлая',
    AppLanguage.uz: 'Yorugʻ',
    AppLanguage.en: 'Light',
  },
  'themeDark': {
    AppLanguage.ru: 'Тёмная',
    AppLanguage.uz: 'Qorongʻu',
    AppLanguage.en: 'Dark',
  },
  'appVersion': {
    AppLanguage.ru: 'Версия',
    AppLanguage.uz: 'Versiya',
    AppLanguage.en: 'Version',
  },
  'soundStyle': {
    AppLanguage.ru: 'Звук',
    AppLanguage.uz: 'Ovoz',
    AppLanguage.en: 'Sound',
  },
  'soundDuration': {
    AppLanguage.ru: 'Длительность звука',
    AppLanguage.uz: 'Ovoz davomiyligi',
    AppLanguage.en: 'Sound duration',
  },
};

const _languageLabels = {
  AppLanguage.ru: 'RU',
  AppLanguage.uz: 'UZ',
  AppLanguage.en: 'EN',
};

const _soundStyleLabels = {
  ToneStyle.classicPiano: {
    AppLanguage.ru: 'Пианино классик',
    AppLanguage.uz: 'Pianino klassik',
    AppLanguage.en: 'Classic piano',
  },
  ToneStyle.electricPiano: {
    AppLanguage.ru: 'Электро',
    AppLanguage.uz: 'Elektro',
    AppLanguage.en: 'Electric',
  },
  ToneStyle.synth: {
    AppLanguage.ru: 'Синтезатор',
    AppLanguage.uz: 'Sintezator',
    AppLanguage.en: 'Synth',
  },
};

String languageLabel(AppLanguage lang) => _languageLabels[lang]!;

String soundStyleLabel(ToneStyle style, AppLanguage lang) =>
    _soundStyleLabels[style]![lang]!;

extension TranslateX on AppLanguage {
  String tr(String key) => _strings[key]?[this] ?? key;
}
