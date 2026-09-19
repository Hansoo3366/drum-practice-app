import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_editor.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_layout.dart';

void main() {
  test('uses the rendered system, not a fixed four-bar group', () {
    const systems = [
      ScoreSystemSpan(startMeasureIndex: 0, endMeasureIndex: 2),
      ScoreSystemSpan(startMeasureIndex: 3, endMeasureIndex: 6),
    ];

    expect(scoreSystemStart(1, systems), 0);
    expect(scoreSystemEnd(1, 8, systems), 2);
    expect(scoreSystemStart(5, systems), 3);
    expect(scoreSystemEnd(5, 8, systems), 6);
    expect(scorePageWidthPx, 794);
  });

  test('marks a section on the rendered system', () {
    const systems = [
      ScoreSystemSpan(startMeasureIndex: 0, endMeasureIndex: 2),
      ScoreSystemSpan(startMeasureIndex: 3, endMeasureIndex: 6),
    ];
    final marked = const UpdateSystemSectionCommand(
      measureIndex: 5,
      section: 'VERSE',
      systems: systems,
    ).apply(_score(measures: 8));

    expect(measurePlaybackSection(marked.parts.first.measures[3]), 'VERSE');
    expect(measurePlaybackSection(marked.parts.first.measures[4]), isNull);
    expect(measurePlaybackSection(marked.parts.first.measures[5]), isNull);
    expect(measurePlaybackSection(marked.parts.first.measures[0]), isNull);
  });
}

MusicScore _score({required int measures}) {
  return MusicScore(
    parts: [
      MusicPart(
        id: 'P1',
        name: 'Piano',
        measures: [
          for (var index = 0; index < measures; index++)
            MusicMeasure(
              number: '${index + 1}',
              attributes: MusicAttributes(divisions: 1),
              events: [
                MusicNote(onset: 0, duration: 4, voice: '1', staff: 1),
              ],
            ),
        ],
      ),
    ],
  );
}
