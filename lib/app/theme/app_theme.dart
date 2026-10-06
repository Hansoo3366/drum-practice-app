import 'package:flutter/material.dart';
import 'package:page_a_diddle/app/theme/app_system_ui.dart';

abstract final class AppColors {
  static const canvas = Color(0xFFFFFFFF);
  static const ink = Color(0xFF000000);
  static const secondaryInk = Color(0xFF303033);
  static const tertiaryInk = Color(0xFF474747);
  static const mutedInk = Color(0xFF5D5D5D);
  static const accent = Color(0xFFFF4800);
  static const border = Color(0xFFDDDDDD);
  static const surfaceSoft = Color(0xFFF5F5F5);
  static const surfaceMuted = Color(0xFFEEEEEE);

  /// Viewer / metronome / jam dark stage.
  static const stage = Color(0xFF111214);
  static const stageElevated = Color(0xFF202226);
  static const stagePanel = Color(0xFF303238);
  static const stageMuted = Color(0xFFB8BAC0);
  static const stageOutline = Color(0xFF5D5D5D);
}

/// App typefaces — SUIT for UI, JetBrains Mono for BPM / measures.
abstract final class AppFonts {
  static const sans = 'SUIT';
  static const mono = 'JetBrainsMono';
}

abstract final class AppTheme {
  static const _radius = BorderRadius.all(Radius.circular(4));
  static const _border = BorderSide(color: AppColors.border);

  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: AppColors.ink,
      onPrimary: AppColors.canvas,
      secondary: AppColors.accent,
      onSecondary: AppColors.ink,
      tertiary: AppColors.tertiaryInk,
      surface: AppColors.canvas,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.mutedInk,
      surfaceContainer: AppColors.surfaceSoft,
      surfaceContainerHighest: AppColors.surfaceMuted,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.canvas,
      fontFamily: AppFonts.sans,
    );
    final textTheme = _textTheme(
      base.textTheme,
      AppColors.ink,
      AppColors.mutedInk,
    );

    return base.copyWith(
      textTheme: textTheme,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: AppColors.ink),
        systemOverlayStyle: AppSystemUi.styleFor(Brightness.light),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: _radius, side: _border),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minLeadingWidth: 28,
        iconColor: AppColors.ink,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.canvas,
        indicatorColor: AppColors.accent.withValues(alpha: 0.12),
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? AppColors.ink : AppColors.mutedInk,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? AppColors.accent : AppColors.ink,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.canvas,
        indicatorColor: AppColors.accent.withValues(alpha: 0.12),
        selectedIconTheme: const IconThemeData(
          color: AppColors.accent,
          size: 22,
        ),
        unselectedIconTheme: const IconThemeData(
          color: AppColors.ink,
          size: 22,
        ),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: AppColors.ink,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: AppColors.mutedInk,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: const RoundedRectangleBorder(borderRadius: _radius),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: AppColors.ink,
          side: _border,
          shape: const RoundedRectangleBorder(borderRadius: _radius),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.canvas,
        selectedColor: AppColors.accent.withValues(alpha: 0.12),
        side: _border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceSoft,
        border: OutlineInputBorder(borderRadius: _radius),
        enabledBorder: OutlineInputBorder(
          borderRadius: _radius,
          borderSide: _border,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: AppColors.ink, width: 2),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.canvas,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: _radius),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: _radius, side: _border),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: const WidgetStatePropertyAll(AppColors.surfaceSoft),
        elevation: const WidgetStatePropertyAll(0),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12),
        ),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: _radius),
        ),
      ),
    );
  }

  /// Dark stage theme for Viewer overlays, metronome, jam.
  static ThemeData get stage {
    const scheme = ColorScheme.dark(
      primary: AppColors.canvas,
      onPrimary: AppColors.ink,
      secondary: AppColors.accent,
      onSecondary: AppColors.canvas,
      tertiary: AppColors.stageMuted,
      surface: AppColors.stage,
      onSurface: AppColors.canvas,
      onSurfaceVariant: AppColors.stageMuted,
      surfaceContainer: AppColors.stageElevated,
      surfaceContainerHighest: AppColors.stagePanel,
      outline: AppColors.stageOutline,
      outlineVariant: AppColors.stageOutline,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.stage,
      fontFamily: AppFonts.sans,
    );
    final textTheme = _textTheme(
      base.textTheme,
      AppColors.canvas,
      AppColors.stageMuted,
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.stage,
        foregroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: AppColors.canvas),
        systemOverlayStyle: AppSystemUi.styleFor(Brightness.dark),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.stageElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: _radius,
          side: BorderSide(color: AppColors.stageOutline),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        iconColor: AppColors.canvas,
        textColor: AppColors.canvas,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.canvas,
          minimumSize: const Size(48, 48),
          shape: const RoundedRectangleBorder(borderRadius: _radius),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.stageOutline,
        thumbColor: AppColors.accent,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.stageOutline),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.stageElevated,
        labelStyle: TextStyle(
          color: AppColors.stageMuted,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(color: AppColors.stageMuted),
        floatingLabelStyle: TextStyle(color: AppColors.stageMuted),
        border: OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: AppColors.stageOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: AppColors.stageOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: AppColors.accent, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: AppColors.stageOutline),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.stageElevated,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: AppColors.stageMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.stageElevated,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, Color ink, Color muted) {
    return base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontSize: 40,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.6,
        color: ink,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 23,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: ink,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 22,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: ink,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: ink,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 14,
        height: 1.35,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: ink,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.1,
        color: ink,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.1,
        color: ink,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 13,
        height: 1.4,
        letterSpacing: -0.05,
        color: muted,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 13,
        height: 1.3,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        color: ink,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 10,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: muted,
      ),
    );
  }
}
