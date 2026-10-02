import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _localePrefsKey = 'app_locale_code';

/// Supported app locales. `null` preference means follow the device.
abstract final class AppLocales {
  static const supported = <Locale>[
    Locale('en'),
    Locale('ko'),
    Locale('ja'),
    Locale('zh'),
    Locale('la'),
  ];

  static Locale? parse(String? code) {
    if (code == null || code.isEmpty || code == 'system') return null;
    for (final locale in supported) {
      if (locale.languageCode == code) return locale;
    }
    return null;
  }
}

class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppLocales.parse(prefs.getString(_localePrefsKey));
  }

  Future<void> setLocale(Locale? locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_localePrefsKey);
    } else {
      await prefs.setString(_localePrefsKey, locale.languageCode);
    }
  }
}

final localeControllerProvider = NotifierProvider<LocaleController, Locale?>(
  LocaleController.new,
);
