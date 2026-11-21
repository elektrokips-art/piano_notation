import 'package:flutter/material.dart';
import 'app_settings.dart';
import 'help_content.dart';
import 'translations.dart';

/// Окно «Справка»: что за приложение и как пользоваться — запись, клавиатура,
/// педаль, станы, PDF, тренировка. Прокручивается, т. к. на низком
/// (альбомном) экране телефона целиком не помещается.
Future<void> showHelpDialog(BuildContext context, AppLanguage lang) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      final textTheme = Theme.of(context).textTheme;
      final sections = helpSections(lang);
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                child: Row(
                  children: [
                    Icon(Icons.help_outline, color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(lang.tr('helpTitle'), style: textTheme.titleLarge),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: lang.tr('close'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  itemCount: sections.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 18),
                  itemBuilder: (context, i) {
                    final s = sections[i];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final icon in s.icons)
                              Icon(icon, size: 20, color: scheme.primary),
                            Text(
                              s.title,
                              style: textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(s.body, style: textTheme.bodyMedium),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
