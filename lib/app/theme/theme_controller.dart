import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themePrefsKey = 'app_theme_mode';

class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = _parse(prefs.getString(_themePrefsKey));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePrefsKey, _key(mode));
  }

  static String _key(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };

  static ThemeMode _parse(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}

final themeControllerProvider =
    NotifierProvider<ThemeController, ThemeMode>(ThemeController.new);
