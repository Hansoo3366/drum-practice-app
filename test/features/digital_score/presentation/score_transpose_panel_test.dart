import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/features/digital_score/presentation/score_transpose_panel.dart';

void main() {
  testWidgets('applies a semitone step and target key', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ScoreTransposeRequest? saved;

    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              saved = await showScoreTransposeSheet(context, currentFifths: 0);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('조옮김'), findsOneWidget);
    expect(find.text('원곡'), findsOneWidget);
    expect(find.text('C / Am'), findsWidgets);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '완료'))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byTooltip('반음 올리기'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('C / Am'), findsWidgets);
    expect(find.text('D♭ / B♭m'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '완료'));
    await tester.pumpAndSettle();

    expect(saved?.semitones, 1);
    expect(saved?.fifthsDelta, -5);
  });

  testWidgets('choosing a target key sets the matching interval', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ScoreTransposeRequest? saved;

    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              saved = await showScoreTransposeSheet(context, currentFifths: 0);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('D / Bm').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '완료'));
    await tester.pumpAndSettle();

    expect(saved?.semitones, 2);
    expect(saved?.fifthsDelta, 2);
  });

  testWidgets('keeps the original key after the written key has changed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () {
              showScoreTransposeSheet(
                context,
                currentFifths: 2,
                originalFifths: 0,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('원곡'), findsOneWidget);
    expect(find.text('C / Am'), findsOneWidget);
    expect(find.text('D / Bm'), findsOneWidget);
  });
}

Widget _app(Widget home) {
  return MaterialApp(
    locale: const Locale('ko'),
    supportedLocales: const [Locale('ko')],
    localizationsDelegates: appLocalizationDelegates,
    home: Scaffold(body: home),
  );
}
