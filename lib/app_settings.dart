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

enum AppLanguage { ru, uz, en }

class AppSettings {
  final AppLanguage language;
  final ThemeMode themeMode;
  final ToneStyle soundStyle;

  const AppSettings({
    this.language = AppLanguage.ru,
    this.themeMode = ThemeMode.light,
    this.soundStyle = ToneStyle.classicPiano,
  });

  AppSettings copyWith({
    AppLanguage? language,
    ThemeMode? themeMode,
    ToneStyle? soundStyle,
  }) {
    return AppSettings(
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      soundStyle: soundStyle ?? this.soundStyle,
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
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
        AppSettingsController.new);
