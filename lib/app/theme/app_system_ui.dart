import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';

/// System UI chrome for the main app shell (not the score viewer).
abstract final class AppSystemUi {
  static SystemUiOverlayStyle styleFor(Brightness brightness) {
    final light = brightness == Brightness.light;
    return SystemUiOverlayStyle(
      statusBarColor: light ? AppColors.canvas : AppColors.stage,
      statusBarIconBrightness: light ? Brightness.dark : Brightness.light,
      statusBarBrightness: light ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: light ? AppColors.canvas : AppColors.stage,
      systemNavigationBarIconBrightness: light
          ? Brightness.dark
          : Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
      systemStatusBarContrastEnforced: true,
      systemNavigationBarContrastEnforced: true,
    );
  }

  /// Opaque bars + icons visible. Call when leaving the score viewer.
  static Future<void> restoreAppChrome(Brightness brightness) async {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setSystemUIOverlayStyle(styleFor(brightness));
  }
}
