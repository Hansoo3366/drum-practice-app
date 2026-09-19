import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/digital_score/presentation/playback_sequence_panel.dart';

void main() {
  test('keeps only marked section roles and their repeats', () {
    final sequence = sequenceForMarkedSections(
      _score(),
      PlaybackSequence([
        PlaybackSequenceItem(section: 'INTRO', repeats: 4),
        PlaybackSequenceItem(section: 'CHORUS', repeats: 8),
      ]),
    );

    expect(sequence.items, [
      PlaybackSequenceItem(section: 'INTRO', repeats: 4),
      PlaybackSequenceItem(section: 'VERSE'),
    ]);
  });

  testWidgets('marks a measure role and changes that role repeat count', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(720, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? section;
    var inserted = false;
    var sequence = PlaybackSequence([
      PlaybackSequenceItem(section: 'INTRO', repeats: 2),
      PlaybackSequenceItem(section: 'VERSE'),
    ]);

    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) {
            return ScoreStructurePanel(
              score: _score(),
              sequence: sequence,
              measureIndex: 0,
              onSectionChanged: (value) => section = value,
              onInsertMeasure: () => inserted = true,
              onRepeatsChanged: (value, repeats) {
                setState(() {
                  sequence = sequenceForMarkedSections(
                    _score(),
                    PlaybackSequence([
                      for (final item in sequence.items)
                        if (item.section == value)
                          item.copyWith(repeats: repeats)
                        else
                          item,
                    ]),
                  );
                });
              },
            );
          },
        ),
      ),
    );

    expect(find.textContaining('오선에서 마디를 누르고'), findsOneWidget);
    expect(find.text('1/2'), findsNothing);
    expect(find.text('다음 마디 추가'), findsOneWidget);
    expect(find.byTooltip('마디 뒤로'), findsNothing);
    expect(find.text('조표'), findsNothing);
    expect(find.text('박자'), findsNothing);
    expect(find.text('인트로'), findsWidgets);
    expect(find.text('벌스'), findsOneWidget);

    await tester.tap(find.byTooltip('횟수 늘리기').first);
    await tester.pump();
    expect(
      sequence.items.first,
      PlaybackSequenceItem(section: 'INTRO', repeats: 3),
    );

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('코러스').last);
    await tester.pumpAndSettle();
    expect(section, 'CHORUS');

    await tester.tap(find.text('다음 마디 추가'));
    await tester.pump();
    expect(inserted, isTrue);
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
            attributes: MusicAttributes(divisions: 1),
            events: const [
              MusicDirection(onset: 0, staff: 1, rehearsal: 'INTRO'),
            ],
          ),
          MusicMeasure(
            number: '2',
            attributes: MusicAttributes(divisions: 1),
            events: const [
              MusicDirection(onset: 0, staff: 1, rehearsal: 'VERSE'),
            ],
          ),
        ],
      ),
    ],
  );
}
