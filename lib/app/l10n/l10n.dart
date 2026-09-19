import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:page_a_diddle/l10n/app_localizations.dart';

export 'package:page_a_diddle/l10n/app_localizations.dart';

extension AppL10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Material/Cupertino fall back to English for locales they don't ship
/// (notably Latin).
class FallbackMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const FallbackMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    if (GlobalMaterialLocalizations.delegate.isSupported(locale)) {
      return GlobalMaterialLocalizations.delegate.load(locale);
    }
    return GlobalMaterialLocalizations.delegate.load(const Locale('en'));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<MaterialLocalizations> old) =>
      false;
}

class FallbackCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const FallbackCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    if (GlobalCupertinoLocalizations.delegate.isSupported(locale)) {
      return GlobalCupertinoLocalizations.delegate.load(locale);
    }
    return GlobalCupertinoLocalizations.delegate.load(const Locale('en'));
  }

  @override
  bool shouldReload(
    covariant LocalizationsDelegate<CupertinoLocalizations> old,
  ) => false;
}

List<LocalizationsDelegate<dynamic>> get appLocalizationDelegates => [
  AppLocalizations.delegate,
  const FallbackMaterialLocalizationsDelegate(),
  const FallbackCupertinoLocalizationsDelegate(),
  GlobalWidgetsLocalizations.delegate,
];
