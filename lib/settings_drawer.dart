import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_settings.dart';
import 'tone_synth.dart';
import 'translations.dart';

const _gesysTelegramUrl = 'https://t.me/Qudaro';

/// Меню настроек: язык, тема, внизу — логотип GeSys (ссылка на Telegram)
/// и версия приложения.
class SettingsDrawer extends ConsumerWidget {
  const SettingsDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final lang = settings.language;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.settings, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(lang.tr('settings'),
                      style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              title: Text(lang.tr('language')),
              trailing: DropdownButton<AppLanguage>(
                value: lang,
                underline: const SizedBox.shrink(),
                items: [
                  for (final l in AppLanguage.values)
                    DropdownMenuItem(value: l, child: Text(languageLabel(l))),
                ],
                onChanged: (value) {
                  if (value != null) controller.setLanguage(value);
                },
              ),
            ),
            ListTile(
              leading: Tooltip(
                message: lang.tr('soundStyle'),
                child: Icon(Icons.music_note, color: Theme.of(context).colorScheme.primary),
              ),
              trailing: DropdownButton<ToneStyle>(
                value: settings.soundStyle,
                underline: const SizedBox.shrink(),
                items: [
                  for (final s in ToneStyle.values)
                    DropdownMenuItem(
                      value: s,
                      child: Text(soundStyleLabel(s, lang)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) controller.setSoundStyle(value);
                },
              ),
            ),
            ListTile(
              title: Text(lang.tr('theme')),
              trailing: IconButton(
                icon: Icon(settings.themeMode == ThemeMode.dark
                    ? Icons.dark_mode
                    : Icons.light_mode),
                tooltip: settings.themeMode == ThemeMode.dark
                    ? lang.tr('themeDark')
                    : lang.tr('themeLight'),
                onPressed: controller.toggleTheme,
              ),
            ),
            const Spacer(),
            const Divider(height: 1),
            InkWell(
              onTap: () =>
                  launchUrl(Uri.parse(_gesysTelegramUrl), mode: LaunchMode.externalApplication),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    SvgPicture.asset('assets/gesys_logo.svg', width: 32, height: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('GeSys', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('@Qudaro',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const Icon(Icons.open_in_new, size: 18),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final version = snapshot.hasData
                      ? 'v${snapshot.data!.version}+${snapshot.data!.buildNumber}'
                      : '';
                  return InkWell(
                    onTap: () => showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Piano Notation'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${lang.tr('appVersion')} $version'),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${lang.tr('developer')}: GeSys'),
                                const SizedBox(width: 6),
                                SvgPicture.asset('assets/gesys_logo.svg',
                                    width: 16, height: 16),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Piano samples: Salamander Grand Piano V3 by '
                              'Alexander Holm (CC BY 3.0)',
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Electric piano / synth samples: FluidR3 GM '
                              'SoundFont by Frank Wen (MIT)',
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '${lang.tr('appVersion')} $version',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Theme.of(context).hintColor),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
