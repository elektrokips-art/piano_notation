import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tone_synth.dart';

/// Экземпляр SharedPreferences, загруженный в main() до runApp — доступен
/// синхронно, поэтому настройки читаются сразу при первом build().
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main()');
});

const _languageKey = 'settings.language';
const _themeModeKey = 'settings.themeMode';
const _soundStyleKey = 'settings.soundStyle';
const _practiceModeKey = 'settings.practiceMode';
const _staffModeKey = 'settings.staffMode';

enum AppLanguage { ru, uz, en }

/// Как ведёт себя режим «играть по нотам» (загруженная через PDF пьеса):
/// [waitForKey] — подсвечивает следующую ноту и ждёт, пока не нажмут именно
/// её (тренажёр); [autoPlay] — проигрывает сама, подсвечивая клавиши по
/// очереди в темпе пьесы (демонстрация).
enum PracticeMode { waitForKey, autoPlay }

/// Нотный стан: [single] — один скрипичный ключ на все ноты (проще читать
/// новичку, играющему одной рукой), [grand] — гранд-стан (скрипичный +
/// басовый, как в настоящих нотах для фортепиано, для игры двумя руками).
enum StaffMode { single, grand }

class AppSettings {
  final AppLanguage language;
  final ThemeMode themeMode;
  final ToneStyle soundStyle;
  final PracticeMode practiceMode;
  final StaffMode staffMode;

  const AppSettings({
    this.language = AppLanguage.ru,
    this.themeMode = ThemeMode.light,
    this.soundStyle = ToneStyle.classicPiano,
    this.practiceMode = PracticeMode.waitForKey,
    this.staffMode = StaffMode.single,
  });

  AppSettings copyWith({
    AppLanguage? language,
    ThemeMode? themeMode,
    ToneStyle? soundStyle,
    PracticeMode? practiceMode,
    StaffMode? staffMode,
  }) {
    return AppSettings(
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      soundStyle: soundStyle ?? this.soundStyle,
      practiceMode: practiceMode ?? this.practiceMode,
      staffMode: staffMode ?? this.staffMode,
    );
  }
}

class AppSettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return AppSettings(
      language: _enumFromPrefs(prefs, _languageKey, AppLanguage.values, AppLanguage.ru),
      themeMode: _enumFromPrefs(prefs, _themeModeKey, ThemeMode.values, ThemeMode.light),
      soundStyle:
          _enumFromPrefs(prefs, _soundStyleKey, ToneStyle.values, ToneStyle.classicPiano),
      practiceMode: _enumFromPrefs(
          prefs, _practiceModeKey, PracticeMode.values, PracticeMode.waitForKey),
      staffMode: _enumFromPrefs(prefs, _staffModeKey, StaffMode.values, StaffMode.single),
    );
  }

  T _enumFromPrefs<T>(SharedPreferences prefs, String key, List<T> values, T fallback) {
    final index = prefs.getInt(key);
    if (index == null || index < 0 || index >= values.length) return fallback;
    return values[index];
  }

  void setLanguage(AppLanguage language) {
    state = state.copyWith(language: language);
    ref.read(sharedPreferencesProvider).setInt(_languageKey, language.index);
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    ref.read(sharedPreferencesProvider).setInt(_themeModeKey, mode.index);
  }

  void toggleTheme() {
    setThemeMode(state.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  void setSoundStyle(ToneStyle style) {
    state = state.copyWith(soundStyle: style);
    ref.read(sharedPreferencesProvider).setInt(_soundStyleKey, style.index);
  }

  void setPracticeMode(PracticeMode mode) {
    state = state.copyWith(practiceMode: mode);
    ref.read(sharedPreferencesProvider).setInt(_practiceModeKey, mode.index);
  }

  void setStaffMode(StaffMode mode) {
    state = state.copyWith(staffMode: mode);
    ref.read(sharedPreferencesProvider).setInt(_staffModeKey, mode.index);
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
        AppSettingsController.new);
