import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/digital_score/presentation/playback_sequence_panel.dart';

const _sections = [
  ScoreSection(
    id: 'm0',
    name: 'VERSE',
    number: 1,
    startMeasureIndex: 0,
    endMeasureIndex: 3,
  ),
  ScoreSection(
    id: 'm4',
    name: 'CHORUS',
    number: null,
    startMeasureIndex: 4,
    endMeasureIndex: 7,
  ),
  ScoreSection(
    id: 'm8',
    name: 'VERSE',
    number: 2,
    startMeasureIndex: 8,
    endMeasureIndex: 11,
  ),
];

void main() {
  test('formats playback lengths', () {
    expect(formatPlaybackLength(96), '1:36');
    expect(formatPlaybackLength(5.4), '0:05');
  });

  testWidgets('names a section at the selected bar', (tester) async {
    final named = <String>[];
    var custom = 0;
    var removed = 0;
    await _pump(
      tester,
      selectedBar: 4,
      onSectionNamed: named.add,
      onCustomSection: () => custom++,
      onBoundaryRemoved: () => removed++,
    );

    expect(find.text('Chorus · 5–8마디'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Chorus'))
          .selected,
      isTrue,
    );
    for (final chip in [
      find.widgetWithText(ChoiceChip, 'Bridge'),
      find.widgetWithText(ActionChip, '직접 입력'),
      find.widgetWithText(ActionChip, '앞 구간과 합치기'),
    ]) {
      await tester.ensureVisible(chip);
      await tester.tap(chip);
    }
    expect(named, ['BRIDGE']);
    expect(custom, 1);
    expect(removed, 1);
  });

  testWidgets(
    'a bar inside a section starts a new one, not the whole section',
    (tester) async {
      await _pump(tester, selectedBar: 6);

      expect(find.text('7마디부터 · 뒤 마디를 누르면 범위가 늘어나요'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, '앞 구간과 합치기'), findsNothing);
    },
  );

  testWidgets('a second tap picks the last bar of the range', (tester) async {
    await _pump(tester, selectedBar: 4, selectedEnd: 6);

    expect(find.text('5–7마디 · 아래 줄을 누르면 거기까지 늘어나요'), findsOneWidget);
    // A picked range is named as a whole; merging is for an existing section.
    expect(find.widgetWithText(ActionChip, '앞 구간과 합치기'), findsNothing);
  });

  testWidgets('a pick can be taken back, and a name taken off', (tester) async {
    final named = <String>[];
    var cancelled = 0;
    await _pump(
      tester,
      selectedBar: 4,
      onSectionNamed: named.add,
      onCancelPick: () => cancelled++,
    );

    await tester.tap(find.text('선택 취소'));
    expect(cancelled, 1);
    // The chip of the section's own name, tapped again, takes the name off.
    for (final (chip, expected) in [
      (find.widgetWithText(ChoiceChip, 'Chorus'), ['']),
      (find.widgetWithText(ChoiceChip, 'Verse'), ['', 'VERSE']),
    ]) {
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pump();
      expect(named, expected);
    }
  });

  testWidgets('the nameless bars before the first mark are picked by the '
      'line, not all at once', (tester) async {
    // "주가 보이신 생명의 길": the first mark the conversion found is at bar 12,
    // so bars 1-11 are a stretch without a name. Tapping the first line (bars
    // 1-4) picks that line.
    await _pump(
      tester,
      sections: const [
        ScoreSection(
          id: 'm0',
          name: '',
          number: null,
          startMeasureIndex: 0,
          endMeasureIndex: 10,
        ),
        ScoreSection(
          id: 'm11',
          name: 'VERSE',
          number: null,
          startMeasureIndex: 11,
          endMeasureIndex: 19,
        ),
      ],
      selectedBar: 0,
      selectedEnd: 3,
    );

    expect(find.textContaining('1–4마디'), findsOneWidget);
    expect(find.textContaining('1–11마디'), findsNothing);
    expect(find.textContaining('이름 없음'), findsNothing);
  });

  test(
    'a pick on a section start means that section, a drawn range does not',
    () {
      expect(pickedSection(_sections, 4, extended: false)?.name, 'CHORUS');
      expect(pickedSection(_sections, 4, extended: true), isNull);
      expect(pickedSection(_sections, 5, extended: false), isNull);
      expect(pickedSection(_sections, null, extended: false), isNull);
      // A stretch without a name is not a section to pick whole.
      const nameless = [
        ScoreSection(
          id: 'm0',
          name: '',
          number: null,
          startMeasureIndex: 0,
          endMeasureIndex: 10,
        ),
      ];
      expect(pickedSection(nameless, 0, extended: false), isNull);
    },
  );

  testWidgets('without a selection only shows how to start', (tester) async {
    await _pump(tester);

    expect(find.text('마디를 누르면 그 마디부터 새 구간이 됩니다'), findsOneWidget);
    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Intro'),
    );
    expect(chip.onSelected, isNull);
  });

  testWidgets('starts an order from the sections', (tester) async {
    List<PlaybackStep>? changed;
    await _pump(
      tester,
      tab: StructureTab.order,
      onStepsChanged: (steps) => changed = steps,
    );

    expect(find.text('적힌 순서대로 연주합니다'), findsOneWidget);
    await tester.ensureVisible(find.text('적힌 순서로 시작'));
    await tester.tap(find.text('적힌 순서로 시작'));
    expect(changed!.map((s) => s.sectionId), ['m0', 'm4', 'm8']);
    // Nothing to make yet.
    expect(find.text('이 순서로 새 악보 만들기'), findsNothing);
  });

  testWidgets('switches between the two tabs and closes', (tester) async {
    final tabs = <StructureTab>[];
    var closed = 0;
    await _pump(tester, onTabChanged: tabs.add, onClose: () => closed++);

    expect(find.text('마디를 누르면 그 마디부터 새 구간이 됩니다'), findsOneWidget);
    await tester.tap(find.text('연주 순서'));
    await tester.tap(find.widgetWithText(TextButton, '닫기'));
    expect(tabs, [StructureTab.order]);
    expect(closed, 1);
  });

  testWidgets('split pieces read as one section; unnamed shows its bars', (
    tester,
  ) async {
    const sections = [
      ScoreSection(
        id: 'm0',
        name: 'INTRO',
        number: null,
        startMeasureIndex: 0,
        endMeasureIndex: 0,
      ),
      ScoreSection(
        id: 'm1',
        name: 'INTRO',
        number: null,
        startMeasureIndex: 1,
        endMeasureIndex: 2,
        continued: true,
      ),
      ScoreSection(
        id: 'm3',
        name: '',
        number: null,
        startMeasureIndex: 3,
        endMeasureIndex: 5,
      ),
    ];
    var sequence = PlaybackSequence(
      steps: [
        PlaybackStep(sectionId: 'm0'),
        PlaybackStep(sectionId: 'm1'),
        PlaybackStep(sectionId: 'm3', pass: 2),
      ],
    );
    await _pump(
      tester,
      tab: StructureTab.order,
      sections: sections,
      sequence: () => sequence,
      onStepsChanged: (steps) => sequence = sequence.copyWith(steps: steps),
    );

    expect(find.text('↳ 2–3마디'), findsOneWidget);
    // The order row and the chip that adds it.
    expect(find.text('4–6마디'), findsNWidgets(2));
    expect(find.text('2번째 반복'), findsOneWidget);
    // Adding the intro adds both of its pieces.
    await tester.ensureVisible(find.widgetWithText(ActionChip, 'Intro'));
    await tester.tap(find.widgetWithText(ActionChip, 'Intro'));
    await tester.pump();
    expect(sequence.steps.skip(3).map((s) => s.sectionId), ['m0', 'm1']);
  });

  testWidgets('edits steps with ranges, repeats and a summary', (tester) async {
    var sequence = PlaybackSequence(
      steps: [
        PlaybackStep(sectionId: 'm0'),
        PlaybackStep(sectionId: 'm4', repeats: 2),
      ],
    );
    var made = 0;
    await _pump(
      tester,
      tab: StructureTab.order,
      sequence: () => sequence,
      summary: (measures: 12, writtenMeasures: 12, time: '0:24', skipped: 4),
      onStepsChanged: (steps) => sequence = sequence.copyWith(steps: steps),
      onMakeScore: () => made++,
    );

    expect(find.text('Verse 1'), findsNWidgets(2));
    expect(find.text('1–4마디'), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);
    expect(find.text('12마디 · 0:24 · 4마디는 연주하지 않음'), findsOneWidget);
    // Changes are kept as they are made: no Save button.
    expect(find.widgetWithText(TextButton, '저장'), findsNothing);

    await tester.ensureVisible(find.byTooltip('횟수 늘리기').first);
    await tester.tap(find.byTooltip('횟수 늘리기').first);
    await tester.pump();
    expect(sequence.steps.first.repeats, 2);

    await tester.ensureVisible(find.byTooltip('구간 순서 아래로').first);
    await tester.tap(find.byTooltip('구간 순서 아래로').first);
    await tester.pump();
    expect(sequence.steps.map((s) => s.sectionId), ['m4', 'm0']);

    // A later verse can be added on its own.
    await tester.ensureVisible(find.widgetWithText(ActionChip, 'Verse 2'));
    await tester.tap(find.widgetWithText(ActionChip, 'Verse 2'));
    await tester.pump();
    expect(sequence.steps.last.sectionId, 'm8');

    await tester.ensureVisible(find.text('이 순서로 새 악보 만들기'));
    await tester.tap(find.text('이 순서로 새 악보 만들기'));
    expect(made, 1);
    expect(find.text('지금 악보는 그대로 남아요.'), findsOneWidget);
  });

  testWidgets('offers the score made earlier in this order', (tester) async {
    await _pump(
      tester,
      tab: StructureTab.order,
      sequence: () => PlaybackSequence(steps: [PlaybackStep(sectionId: 'm0')]),
      madeScoreExists: true,
    );

    expect(find.text('이 순서로 만든 악보 열기'), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  StructureTab tab = StructureTab.sections,
  List<ScoreSection> sections = _sections,
  int? selectedBar,
  int? selectedEnd,
  PlaybackSequence Function()? sequence,
  ({int measures, int writtenMeasures, String time, int skipped})? summary,
  bool madeScoreExists = false,
  ValueChanged<StructureTab>? onTabChanged,
  VoidCallback? onClose,
  VoidCallback? onCancelPick,
  ValueChanged<String>? onSectionNamed,
  VoidCallback? onCustomSection,
  VoidCallback? onBoundaryRemoved,
  ValueChanged<List<PlaybackStep>>? onStepsChanged,
  VoidCallback? onMakeScore,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko')],
      localizationsDelegates: appLocalizationDelegates,
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => Align(
            alignment: Alignment.bottomCenter,
            child: ScoreStructurePanel(
              tab: tab,
              onTabChanged: onTabChanged ?? (_) {},
              sequence: sequence?.call() ?? PlaybackSequence.empty,
              sections: sections,
              selectedBar: selectedBar,
              selectedEnd: selectedEnd,
              summary:
                  summary ??
                  (measures: 12, writtenMeasures: 12, time: '0:24', skipped: 0),
              canUndo: false,
              onUndo: () {},
              onClose: onClose ?? () {},
              onCancelPick: onCancelPick ?? () {},
              onSectionNamed: onSectionNamed ?? (_) {},
              onCustomSection: onCustomSection ?? () {},
              onBoundaryRemoved: onBoundaryRemoved ?? () {},
              onStepsChanged: (steps) {
                onStepsChanged?.call(steps);
                setState(() {});
              },
              madeScoreExists: madeScoreExists,
              onMakeScore: onMakeScore ?? () {},
            ),
          ),
        ),
      ),
    ),
  );
}
