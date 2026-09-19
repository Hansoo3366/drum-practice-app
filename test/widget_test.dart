import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/app/app.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/l10n/locale_controller.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/app/widgets/app_brand_mark.dart';
import 'package:page_a_diddle/core/audio/audio_engine_provider.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/features/home/presentation/home_screen.dart';
import 'package:page_a_diddle/features/library/presentation/library_controller.dart';
import 'package:page_a_diddle/features/onboarding/data/onboarding_controller.dart';
import 'package:page_a_diddle/features/practice/data/practice_session_repository.dart';
import 'package:page_a_diddle/features/setlists/presentation/setlist_controller.dart';

class _KoLocaleController extends LocaleController {
  @override
  Locale? build() => const Locale('ko');
}

class _CompletedOnboarding extends OnboardingController {
  @override
  bool? build() => true;
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('ko'));

  test('DESIGN.md 색상과 타이포 토큰을 사용한다', () {
    final theme = AppTheme.light;

    expect(theme.colorScheme.primary, AppColors.ink);
    expect(theme.colorScheme.secondary, AppColors.accent);
    expect(theme.colorScheme.outline, AppColors.border);
    expect(theme.scaffoldBackgroundColor, AppColors.canvas);
    expect(theme.textTheme.bodyMedium?.fontFamily, AppFonts.sans);
    expect(theme.textTheme.bodyMedium?.fontSize, 16);
    expect(theme.textTheme.headlineMedium?.fontSize, 23);
    expect(theme.textTheme.displaySmall?.fontSize, 40);
  });

  testWidgets('앱 셸에서 주요 탭을 이동할 수 있다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localeControllerProvider.overrideWith(_KoLocaleController.new),
          onboardingCompletedProvider.overrideWith(_CompletedOnboarding.new),
          audioEngineProvider.overrideWithValue(const AsyncLoading()),
          librarySongsProvider.overrideWithValue(const AsyncData(<Song>[])),
          recentSongsProvider.overrideWithValue(const AsyncData(<Song>[])),
          recentPracticeSessionsProvider.overrideWithValue(
            const AsyncData(<PracticeSession>[]),
          ),
          setlistsProvider.overrideWithValue(const AsyncData(<Setlist>[])),
        ],
        child: const PageADiddleApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.openScore), findsOneWidget);
    await tester.tap(find.text(l10n.openScore));
    await tester.pumpAndSettle();
    expect(find.text(l10n.emptyLibraryTitle), findsOneWidget);

    await tester.tap(find.text(l10n.tabHome).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.tapTempo));
    await tester.pumpAndSettle();

    expect(find.text('TAP'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(l10n.tabLibrary),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.emptyLibraryTitle), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(l10n.tabSetlists),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.emptySetlistsTitle), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(l10n.tabHome),
      ),
    );
    await tester.pumpAndSettle();
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(AppBrandMark), findsOneWidget);
  });

  testWidgets('홈 헤더 아이콘은 모바일 폭에서만 표시한다', (tester) async {
    Future<void> pumpHomeAt(Size size) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeControllerProvider.overrideWith(_KoLocaleController.new),
            recentSongsProvider.overrideWithValue(const AsyncData(<Song>[])),
          ],
          child: MaterialApp(
            locale: const Locale('ko'),
            supportedLocales: const [Locale('ko')],
            localizationsDelegates: appLocalizationDelegates,
            theme: AppTheme.light,
            home: MediaQuery(
              data: MediaQueryData(size: size),
              child: const HomeScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpHomeAt(const Size(390, 844));
    expect(find.byType(AppBrandMark), findsOneWidget);

    await pumpHomeAt(const Size(1000, 800));
    expect(find.byType(AppBrandMark), findsNothing);
  });
}
