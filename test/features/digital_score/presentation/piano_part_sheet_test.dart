import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_advice.dart';
import 'package:page_a_diddle/features/digital_score/domain/three_staff_arrangement.dart';
import 'package:page_a_diddle/features/digital_score/presentation/piano_part_sheet.dart';

Widget _app(Widget home) {
  return MaterialApp(
    locale: const Locale('ko'),
    supportedLocales: const [Locale('ko')],
    localizationsDelegates: appLocalizationDelegates,
    home: Scaffold(body: home),
  );
}

Future<PianoPartRequest? Function()> _open(
  WidgetTester tester,
  Future<ArrangementAdvice> Function() advise, {
  AccompanimentPlan initial = const AccompanimentPlan(),
}) async {
  await tester.binding.setSurfaceSize(const Size(500, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  PianoPartRequest? result;
  await tester.pumpWidget(
    _app(
      Builder(
        builder: (context) => FilledButton(
          onPressed: () async {
            result = await showPianoPartSheet(
              context,
              advise: advise,
              initial: initial,
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return () => result;
}

void main() {
  testWidgets('makes the part in the chosen style without any advice', (
    tester,
  ) async {
    var asked = 0;
    final result = await _open(tester, () async {
      asked++;
      throw StateError('not asked');
    });

    await tester.tap(find.text('박마다'));
    await tester.tap(find.text('낮게'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('만들기'));
    await tester.pumpAndSettle();

    expect(asked, 0);
    expect(
      result()?.plan.base,
      const AccompanimentStyle(
        pattern: AccompanimentPattern.beats,
        register: AccompanimentRegister.low,
      ),
    );
    expect(result()?.plan.sections, isEmpty);
    expect(result()?.corrections, isEmpty);
  });

  testWidgets('takes the advised styles and only the accepted chords', (
    tester,
  ) async {
    const fixes = [
      ChordCorrection(
        measureIndex: 0,
        chordIndex: 0,
        current: 'F#',
        suggested: 'D/F#',
        reason: 'G장조에서 F#은 드뭅니다',
      ),
      ChordCorrection(
        measureIndex: 16,
        chordIndex: 0,
        current: 'CM9',
        suggested: 'Cmaj9',
      ),
    ];
    final result = await _open(
      tester,
      () async => const ArrangementAdvice(
        plan: AccompanimentPlan(
          base: AccompanimentStyle(pattern: AccompanimentPattern.broken),
          sections: {
            8: AccompanimentStyle(pattern: AccompanimentPattern.beats),
          },
        ),
        corrections: fixes,
        note: '잔잔하게 시작해 후렴에서 박을 줍니다',
      ),
    );

    await tester.tap(find.text('AI 추천 받기'));
    await tester.pumpAndSettle();

    expect(find.text('잔잔하게 시작해 후렴에서 박을 줍니다'), findsOneWidget);
    expect(find.text('9마디부터: 박마다 · 가운데'), findsOneWidget);
    expect(find.text('1마디: F# → D/F#'), findsOneWidget);
    expect(find.text('G장조에서 F#은 드뭅니다'), findsOneWidget);
    // Nothing is accepted until the user ticks it.
    await tester.tap(find.text('17마디: CM9 → Cmaj9'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('만들기'));
    await tester.tap(find.text('만들기'));
    await tester.pumpAndSettle();

    expect(result()?.plan.base.pattern, AccompanimentPattern.broken);
    expect(result()?.plan.sections.keys, [8]);
    expect(result()?.corrections, [fixes[1]]);
  });

  testWidgets('a failed request leaves the chosen style and says so', (
    tester,
  ) async {
    final result = await _open(tester, () async => throw StateError('503'));

    await tester.tap(find.text('분산'));
    await tester.tap(find.text('AI 추천 받기'));
    await tester.pumpAndSettle();

    expect(find.text('지금은 추천을 받을 수 없습니다'), findsOneWidget);
    await tester.tap(find.text('만들기'));
    await tester.pumpAndSettle();
    expect(result()?.plan.base.pattern, AccompanimentPattern.broken);
  });

  testWidgets('opens with the style of the part the score already has', (
    tester,
  ) async {
    final result = await _open(
      tester,
      () async => throw StateError('not asked'),
      initial: const AccompanimentPlan(
        base: AccompanimentStyle(
          pattern: AccompanimentPattern.broken,
          register: AccompanimentRegister.low,
        ),
        sections: {8: AccompanimentStyle(pattern: AccompanimentPattern.beats)},
      ),
    );

    expect(find.text('9마디부터: 박마다 · 가운데'), findsOneWidget);
    await tester.tap(find.text('가운데'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('만들기'));
    await tester.pumpAndSettle();

    expect(
      result()?.plan.base,
      const AccompanimentStyle(pattern: AccompanimentPattern.broken),
    );
    expect(result()?.plan.sections.keys, [8]);
  });

  testWidgets('"one style for all" drops the section styles', (tester) async {
    final result = await _open(
      tester,
      () async => const ArrangementAdvice(
        plan: AccompanimentPlan(
          sections: {
            4: AccompanimentStyle(pattern: AccompanimentPattern.beats),
          },
        ),
      ),
    );

    await tester.tap(find.text('AI 추천 받기'));
    await tester.pumpAndSettle();
    expect(find.text('없음'), findsOneWidget);
    await tester.tap(find.text('전체 한 가지로'));
    await tester.pumpAndSettle();
    expect(find.text('5마디부터: 박마다 · 가운데'), findsNothing);
    await tester.tap(find.text('만들기'));
    await tester.pumpAndSettle();

    expect(result()?.plan.sections, isEmpty);
  });
}
