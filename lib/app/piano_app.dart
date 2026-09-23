import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/app/branding/app_branding.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/l10n/locale_controller.dart';
import 'package:page_a_diddle/app/router/piano_app_router.dart';
import 'package:page_a_diddle/app/theme/app_system_ui.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/app/theme/theme_controller.dart';

class PianoApp extends ConsumerWidget {
  const PianoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(pianoRouterProvider);
    final locale = ref.watch(localeControllerProvider);
    final themeMode = ref.watch(themeControllerProvider);

    return MaterialApp.router(
      onGenerateTitle: (_) => AppBranding.pianoAppName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.stage,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocales.supported,
      localizationsDelegates: appLocalizationDelegates,
      localeResolutionCallback: (deviceLocale, supported) {
        if (locale != null) return locale;
        if (deviceLocale == null) return const Locale('en');
        for (final candidate in supported) {
          if (candidate.languageCode == deviceLocale.languageCode) {
            return candidate;
          }
        }
        return const Locale('en');
      },
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppSystemUi.styleFor(brightness),
          child: child ?? const SizedBox.shrink(),
        );
      },
      routerConfig: router,
    );
  }
}
