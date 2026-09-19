import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/presentation/score_editor_panel.dart';

void main() {
  testWidgets('keeps the write palette to durations and staff actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(720, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? duration;
    var deleted = false;

    await tester.pumpWidget(
      _app(
        ScoreEditorPanel(
          canUndo: false,
          canRedo: false,
          hasSelection: true,
          inputDurationType: 'quarter',
          inputRest: false,
          inputAlter: 0,
          onUndo: () {},
          onRedo: () {},
          onDurationTypeChanged: (value) => duration = value,
          onInputRestChanged: (_) {},
          onInputAlterChanged: (_) {},
          onDeleteSelected: () => deleted = true,
          onInsertMeasure: () {},
        ),
      ),
    );

    expect(find.text('1/4'), findsOneWidget);
    expect(find.text('마디 1/1'), findsNothing);
    expect(find.text('C4 · 1'), findsNothing);
    expect(find.text('오선을 누르세요'), findsNothing);
    expect(find.text('구간'), findsNothing);
    expect(find.byTooltip('다음 마디 추가'), findsOneWidget);
    expect(find.byTooltip('마디 삭제'), findsNothing);
    expect(find.text('코드 추가'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('1/8'));
    await tester.tap(find.byTooltip('선택 항목 삭제'));

    expect(duration, 'eighth');
    expect(deleted, isTrue);
  });

  testWidgets('creates a rest through the note editor sheet', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    MusicNote? result;

    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showNoteEditorSheet(
                context,
                measure: _score().parts.first.measures.first,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('쉼표'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.isRest, isTrue);
    expect(result!.duration, 4);
    expect(result!.staff, 1);
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

MusicScore _score() {
  return MusicScore(
    parts: [
      MusicPart(
        id: 'P1',
        name: 'Piano',
        measures: [
          MusicMeasure(
            number: '1',
            attributes: MusicAttributes(
              divisions: 4,
              time: const MusicTimeSignature(beats: 4, beatType: 4),
              staves: 2,
            ),
            events: [
              MusicNote(
                onset: 0,
                duration: 4,
                voice: '1',
                staff: 1,
                pitch: const MusicPitch(step: PitchStep.c, octave: 4),
                type: 'quarter',
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
