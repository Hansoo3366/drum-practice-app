import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/performance_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';

void main() {
  test('discovers named sections from rehearsal marks', () {
    final ranges = discoverScoreSections(_score());

    expect(ranges, hasLength(3));
    expect(ranges[0].section, 'INTRO');
    expect(ranges[0].startMeasureIndex, 0);
    expect(ranges[0].endMeasureIndex, 0);
    expect(ranges[1].section, 'VERSE');
    expect(ranges[1].startMeasureIndex, 1);
    expect(ranges[1].endMeasureIndex, 2);
    expect(ranges[2].section, 'CHORUS');
    expect(ranges[2].startMeasureIndex, 3);
    expect(ranges[2].endMeasureIndex, 3);
    expect(measureSectionCodes(_score()), [
      'INTRO',
      'VERSE',
      'VERSE',
      'CHORUS',
    ]);
    expect(measureSectionMarks(_score()), [
      'INTRO',
      'VERSE',
      null,
      'CHORUS',
    ]);
  });

  test('keeps the written score when the sequence is empty', () {
    final score = _score();

    expect(identical(expandPlaybackSequence(score), score), isTrue);
    expect(expandPlaybackSequence(score).measureCount, 4);
  });

  test(
    'expands INTRO × 4 → VERSE × 2 → CHORUS × 1 without mutating source',
    () {
      final score = _score();
      final expanded = expandPlaybackSequence(
        score,
        PlaybackSequence([
          PlaybackSequenceItem(section: 'INTRO', repeats: 4),
          PlaybackSequenceItem(section: 'VERSE', repeats: 2),
          PlaybackSequenceItem(section: 'CHORUS'),
        ]),
      );

      expect(score.measureCount, 4);
      expect(expanded.measureCount, 9);
      expect(expanded.parts.single.measures.map(measurePlaybackSection), [
        'INTRO',
        'INTRO',
        'INTRO',
        'INTRO',
        'VERSE',
        null,
        'VERSE',
        null,
        'CHORUS',
      ]);
      expect(expanded.parts.single.measures.map((measure) => measure.number), [
        '1',
        '2',
        '3',
        '4',
        '5',
        '6',
        '7',
        '8',
        '9',
      ]);
    },
  );

  test('rejects an unknown section and oversized expansion', () {
    final score = _score();

    expect(
      () => expandPlaybackSequence(
        score,
        PlaybackSequence([PlaybackSequenceItem(section: 'BRIDGE')]),
      ),
      throwsFormatException,
    );
    expect(
      () => expandPlaybackSequence(
        _score(measures: 20, verseAt: null, chorusAt: null),
        PlaybackSequence([PlaybackSequenceItem(section: 'INTRO', repeats: 16)]),
      ),
      throwsFormatException,
    );
  });

  test('round-trips sequence JSON and normalizes standard names', () {
    final sequence = PlaybackSequence.fromJson({
      'items': [
        {'section': 'intro', 'repeats': 4},
        {'section': 'verse', 'repeats': '2'},
      ],
    });

    expect(sequence.items.map((item) => item.section), ['INTRO', 'VERSE']);
    expect(sequence.items.map((item) => item.repeats), [4, 2]);
    expect(PlaybackSequence.fromJson(sequence.toJson()), sequence);
    expect(PlaybackSequence.fromJson(null), PlaybackSequence.empty);
  });

  test('keeps the written score until playback is turned on', () {
    final written = _score();
    final sequence = PlaybackSequence([
      PlaybackSequenceItem(section: 'INTRO', repeats: 4),
      PlaybackSequenceItem(section: 'VERSE', repeats: 2),
      PlaybackSequenceItem(section: 'CHORUS'),
    ]);

    expect(
      identical(
        displayedDigitalScore(
          written: written,
          editing: true,
          playbackEnabled: true,
          sequence: sequence,
        ),
        written,
      ),
      isTrue,
    );
    expect(
      identical(
        displayedDigitalScore(
          written: written,
          editing: false,
          playbackEnabled: false,
          sequence: sequence,
        ),
        written,
      ),
      isTrue,
    );
    expect(
      displayedDigitalScore(
        written: written,
        editing: false,
        playbackEnabled: true,
        sequence: sequence,
      ).measureCount,
      9,
    );
  });
}

MusicScore _score({int measures = 4, int? verseAt = 1, int? chorusAt = 3}) {
  return MusicScore(
    parts: [
      MusicPart(
        id: 'P1',
        name: 'Piano',
        measures: [
          for (var index = 0; index < measures; index++)
            MusicMeasure(
              number: '${index + 1}',
              attributes: MusicAttributes(
                divisions: 1,
                time: const MusicTimeSignature(beats: 4, beatType: 4),
              ),
              events: [
                if (index == 0)
                  const MusicDirection(onset: 0, staff: 1, rehearsal: 'INTRO'),
                if (verseAt != null && index == verseAt)
                  const MusicDirection(onset: 0, staff: 1, rehearsal: 'VERSE'),
                if (chorusAt != null && index == chorusAt)
                  const MusicDirection(onset: 0, staff: 1, rehearsal: 'CHORUS'),
                MusicNote(
                  onset: 0,
                  duration: 4,
                  voice: '1',
                  staff: 1,
                  pitch: MusicPitch(step: PitchStep.c, octave: 4 + (index % 2)),
                ),
              ],
            ),
        ],
      ),
    ],
  );
}
