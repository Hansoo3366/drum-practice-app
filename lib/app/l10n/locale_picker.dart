import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/l10n/locale_controller.dart';

abstract final class AppLocaleLabels {
  static String of(AppLocalizations l10n, Locale? locale) {
    if (locale == null) return l10n.languageSystem;
    return switch (locale.languageCode) {
      'ko' => l10n.languageKorean,
      'ja' => l10n.languageJapanese,
      'zh' => l10n.languageChinese,
      'la' => l10n.languageLatin,
      _ => l10n.languageEnglish,
    };
  }
}

Future<void> pickAppLanguage({
  required BuildContext context,
  required WidgetRef ref,
  Locale? current,
}) async {
  final l10n = context.l10n;
  final selected = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final options = <(String, String)>[
        ('system', l10n.languageSystem),
        ('ko', l10n.languageKorean),
        ('en', l10n.languageEnglish),
        ('ja', l10n.languageJapanese),
        ('zh', l10n.languageChinese),
        ('la', l10n.languageLatin),
      ];
      final currentCode = current?.languageCode ?? 'system';
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final (code, label) in options)
              ListTile(
                title: Text(label),
                trailing: code == currentCode
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(code),
              ),
          ],
        ),
      );
    },
  );
  if (selected == null) return;
  await ref
      .read(localeControllerProvider.notifier)
      .setLocale(AppLocales.parse(selected == 'system' ? null : selected));
}
