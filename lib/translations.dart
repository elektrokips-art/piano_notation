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
  'tempo': {
    AppLanguage.ru: 'Темп',
    AppLanguage.uz: 'Tezlik',
    AppLanguage.en: 'Tempo',
  },
  'openPiece': {
    AppLanguage.ru: 'Открыть пьесу (PDF)',
    AppLanguage.uz: 'Asar ochish (PDF)',
    AppLanguage.en: 'Open piece (PDF)',
  },
  'notOurFile': {
    AppLanguage.ru: 'Это не файл Piano Notation — в нём нет нот для тренажёра',
    AppLanguage.uz: 'Bu Piano Notation fayli emas — trenajyor uchun notalar yoʻq',
    AppLanguage.en: 'Not a Piano Notation file — no notes to practice with',
  },
  'exitPractice': {
    AppLanguage.ru: 'Закрыть пьесу',
    AppLanguage.uz: 'Asarni yopish',
    AppLanguage.en: 'Close piece',
  },
  'practiceFinished': {
    AppLanguage.ru: 'Пьеса сыграна!',
    AppLanguage.uz: 'Asar oʻynaldi!',
    AppLanguage.en: 'Piece complete!',
  },
  'practiceModeWaitForKey': {
    AppLanguage.ru: 'Тренажёр (ждать клавишу)',
    AppLanguage.uz: 'Trenajyor (klavishni kutish)',
    AppLanguage.en: 'Trainer (wait for key)',
  },
  'practiceModeAutoPlay': {
    AppLanguage.ru: 'Автоигра (показ)',
    AppLanguage.uz: 'Avtomatik ijro (koʻrsatish)',
    AppLanguage.en: 'Auto-play (demo)',
  },
  'hideKeyboard': {
    AppLanguage.ru: 'Скрыть клавиатуру',
    AppLanguage.uz: 'Klaviaturani yashirish',
    AppLanguage.en: 'Hide keyboard',
  },
  'showKeyboard': {
    AppLanguage.ru: 'Показать клавиатуру',
    AppLanguage.uz: 'Klaviaturani ko\'rsatish',
    AppLanguage.en: 'Show keyboard',
  },
  'keySizeSmaller': {
    AppLanguage.ru: 'Мельче клавиши',
    AppLanguage.uz: 'Klavishlar kichikroq',
    AppLanguage.en: 'Smaller keys',
  },
  'keySizeBigger': {
    AppLanguage.ru: 'Крупнее клавиши',
    AppLanguage.uz: 'Klavishlar kattaroq',
    AppLanguage.en: 'Bigger keys',
  },
  'developer': {
    AppLanguage.ru: 'Разработчик',
    AppLanguage.uz: 'Dasturchi',
    AppLanguage.en: 'Developer',
  },
};

const _languageLabels = {
  AppLanguage.ru: 'RU',
  AppLanguage.uz: 'UZ',
  AppLanguage.en: 'EN',
};

const _soundStyleLabels = {
  ToneStyle.classicPiano: {
    AppLanguage.ru: 'Пиано',
    AppLanguage.uz: 'Pianino',
    AppLanguage.en: 'Piano',
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
