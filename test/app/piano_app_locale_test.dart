import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/piano_app.dart';
import 'package:page_a_diddle/app/router/piano_app_router.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('the piano app is Korean on a device set to English', (
    tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    late Locale shown;
    late String title;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            shown = Localizations.localeOf(context);
            title = context.l10n.scoreTranspose;
            return const SizedBox();
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [pianoRouterProvider.overrideWithValue(router)],
        child: const PianoApp(),
      ),
    );
    await tester.pump();

    expect(shown, const Locale('ko'));
    expect(title, '조옮김');
  });
}
