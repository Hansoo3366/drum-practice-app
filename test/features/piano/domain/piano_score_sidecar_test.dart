import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/piano/domain/piano_score_sidecar.dart';

void main() {
  test('round-trips sections and arrangement without MusicXML fields', () {
    final sidecar = PianoScoreSidecar(
      scoreId: 'score-001',
      sourceRevision: 'sha256:abc',
      sections: const [
        PianoScoreSection(
          id: 'verse1',
          label: 'Verse 1',
          startMeasureUid: 'm-12',
          endMeasureUid: 'm-19',
        ),
      ],
      arrangement: [PianoArrangementItem(sectionId: 'verse1', playCount: 2)],
    );

    expect(PianoScoreSidecar.fromJson(sidecar.toJson()), sidecar);
    expect(sidecar.toJson(), isNot(contains('note')));
    expect(sidecar.toJson()['arrangement'], [
      {'sectionId': 'verse1', 'playCount': 2},
    ]);
  });

  test('rejects duplicate section ids', () {
    expect(
      () => PianoScoreSidecar(
        scoreId: 'score-001',
        sourceRevision: 'sha256:abc',
        sections: const [
          PianoScoreSection(
            id: 'chorus',
            label: 'Chorus',
            startMeasureUid: 'm-1',
            endMeasureUid: 'm-4',
          ),
          PianoScoreSection(
            id: 'chorus',
            label: 'Chorus again',
            startMeasureUid: 'm-5',
            endMeasureUid: 'm-8',
          ),
        ],
      ),
      throwsFormatException,
    );
  });

  test('playCount is total plays and must be positive', () {
    expect(
      () => PianoArrangementItem(sectionId: 'verse1', playCount: 0),
      throwsFormatException,
    );
  });

  test('rejects an arrangement item that has no declared section', () {
    expect(
      () => PianoScoreSidecar(
        scoreId: 'score-001',
        sourceRevision: 'sha256:abc',
        arrangement: [PianoArrangementItem(sectionId: 'missing')],
      ),
      throwsFormatException,
    );
  });
}
