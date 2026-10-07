import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_editor.dart';

void main() {
  _dividingTests();
  group('sections', () {
    test('reads rehearsal marks written by older versions', () {
      final sections = scoreSections(
        _score(marks: {0: 'INTRO', 1: 'VERSE', 3: 'CHORUS'}),
        PlaybackSequence.empty,
      );

      expect(sections.map(_describe), [
        'm0 INTRO 0-0',
        'm1 VERSE 1-2',
        'm3 CHORUS 3-3',
      ]);
    });

    test('a boundary starts a section that runs to the next one', () {
      final score = _score(measures: 8);
      var sequence = setSectionBoundary(
        score,
        PlaybackSequence.empty,
        measureIndex: 2,
        name: 'verse',
      );

      expect(scoreSections(score, sequence).map(_describe), [
        'm0  0-1',
        'm2 VERSE 2-7',
      ]);

      sequence = setSectionBoundary(
        score,
        sequence,
        measureIndex: 5,
        name: 'CHORUS',
      );
      expect(scoreSections(score, sequence).map(_describe), [
        'm0  0-1',
        'm2 VERSE 2-4',
        'm5 CHORUS 5-7',
      ]);
    });

    test('renaming keeps the steps that play the section', () {
      final score = _score(measures: 4);
      var sequence = setSectionBoundary(
        score,
        PlaybackSequence.empty,
        measureIndex: 0,
        name: 'VERSE',
      );
      sequence = sequence.copyWith(
        steps: [PlaybackStep(sectionId: sectionIdAt(0), repeats: 3)],
      );

      sequence = setSectionBoundary(
        score,
        sequence,
        measureIndex: 0,
        name: 'Solo',
      );

      expect(scoreSections(score, sequence).single.name, 'SOLO');
      expect(sequence.steps.single.repeats, 3);
    });

    test('numbers repeated names and plays only the chosen one', () {
      final score = _score(measures: 6);
      final sequence = PlaybackSequence(
        marks: [
          SectionMark(startMeasureIndex: 0, name: 'VERSE'),
          SectionMark(startMeasureIndex: 2, name: 'CHORUS'),
          SectionMark(startMeasureIndex: 4, name: 'VERSE'),
        ],
        steps: [PlaybackStep(sectionId: sectionIdAt(4))],
      );

      expect(scoreSections(score, sequence).map((s) => s.number), [1, null, 2]);
      expect(performanceMeasureMap(score, sequence), [4, 5]);
    });

    test('removing a boundary merges bars and drops its steps', () {
      final score = _score(measures: 4);
      final sequence = PlaybackSequence(
        marks: [
          SectionMark(startMeasureIndex: 0, name: 'VERSE'),
          SectionMark(startMeasureIndex: 2, name: 'CHORUS'),
        ],
        steps: [
          PlaybackStep(sectionId: sectionIdAt(0)),
          PlaybackStep(sectionId: sectionIdAt(2)),
        ],
      );

      final next = removeSectionBoundary(score, sequence, measureIndex: 2);

      expect(scoreSections(score, next).map(_describe), ['m0 VERSE 0-3']);
      expect(next.steps.map((s) => s.sectionId), [sectionIdAt(0)]);
    });
  });

  group('playback order', () {
    test('an empty order plays the written score', () {
      final score = _score(marks: {0: 'INTRO', 1: 'VERSE'});

      expect(identical(expandPlaybackSequence(score), score), isTrue);
      expect(performanceMeasureMap(score, PlaybackSequence.empty), [
        0,
        1,
        2,
        3,
      ]);
    });

    test('expands steps with repeats without changing the source', () {
      final score = _score(marks: {0: 'INTRO', 1: 'VERSE', 3: 'CHORUS'});
      final sequence = PlaybackSequence(
        steps: [
          PlaybackStep(sectionId: sectionIdAt(0), repeats: 4),
          PlaybackStep(sectionId: sectionIdAt(1), repeats: 2),
          PlaybackStep(sectionId: sectionIdAt(3)),
        ],
      );

      final expanded = expandPlaybackSequence(score, sequence);

      expect(score.measureCount, 4);
      expect(expanded.measureCount, 9);
      expect(
        expanded.parts.single.measures.map((m) => m.number).toList(),
        List.generate(9, (index) => '${index + 1}'),
      );
    });

    test('summarises bars, length and skipped bars', () {
      final score = _score(measures: 6);
      final sequence = PlaybackSequence(
        marks: [
          SectionMark(startMeasureIndex: 0, name: 'INTRO'),
          SectionMark(startMeasureIndex: 2, name: 'VERSE'),
        ],
        steps: [PlaybackStep(sectionId: sectionIdAt(0), repeats: 3)],
      );

      final summary = performanceSummary(score, sequence);

      expect(summary.measures, 6);
      expect(summary.quarters, 24);
      expect(summary.skipped, 4);
    });

    test('maps playback time to the written bar that is playing', () {
      final map = [2, 3, 2, 3, 0];
      final lengths = [4.0, 4.0, 4.0, 2.0];

      // Bars play 4 + 2 + 4 + 2 + 4 = 16 quarters.
      expect(writtenMeasureAt(map, lengths, 0), 2);
      expect(writtenMeasureAt(map, lengths, 5 / 16), 3);
      expect(writtenMeasureAt(map, lengths, 7 / 16), 2);
      expect(writtenMeasureAt(map, lengths, 15 / 16), 0);
      expect(writtenMeasureAt(map, lengths, 1), 0);
    });

    test('uses the time signature, or the notes of a pickup bar', () {
      final score = MusicScore(
        parts: [
          MusicPart(
            id: 'P1',
            name: 'Piano',
            measures: [
              _measure(0, beats: 3, noteQuarters: 1, implicit: true),
              _measure(1, beats: 3, noteQuarters: 3),
              _measure(2, beats: 3, noteQuarters: 1),
            ],
          ),
        ],
      );

      expect(measureQuarterLengths(score), [1, 3, 3]);
    });
  });

  group('repeat signs', () {
    MusicScore withRepeats() => MusicScore(
      parts: [
        MusicPart(
          id: 'P1',
          name: 'Piano',
          measures: [
            _measure(0),
            _measure(1, barlines: [_barline('left', repeat: 'forward')]),
            _measure(
              2,
              barlines: [
                _barline('left', endingType: 'start', endings: [1]),
                _barline('right', repeat: 'backward'),
              ],
            ),
            _measure(
              3,
              barlines: [
                _barline('left', endingType: 'start', endings: [2]),
              ],
            ),
          ],
        ),
      ],
    );

    test('the written order follows repeats and endings', () {
      expect(writtenRepeatOrder(withRepeats()), [0, 1, 2, 1, 3]);
      expect(performanceMeasureMap(withRepeats(), PlaybackSequence.empty), [
        0,
        1,
        2,
        1,
        3,
      ]);
    });

    test('an explicit repeat count plays that many passes', () {
      final score = MusicScore(
        parts: [
          MusicPart(
            id: 'P1',
            name: 'Piano',
            measures: [
              _measure(
                0,
                barlines: [_barline('right', repeat: 'backward', times: 3)],
              ),
              _measure(1),
            ],
          ),
        ],
      );

      expect(writtenRepeatOrder(score), [0, 0, 0, 1]);
    });

    test('a custom order ignores repeat signs inside its sections', () {
      final score = withRepeats();
      final sequence = PlaybackSequence(
        marks: [SectionMark(startMeasureIndex: 0, name: 'VERSE')],
        steps: [PlaybackStep(sectionId: sectionIdAt(0))],
      );

      // Played once, the section leads out through its last ending.
      expect(performanceMeasureMap(score, sequence), [0, 1, 3]);
      final expanded = expandPlaybackSequence(score, sequence);
      expect(
        expanded.parts.single.measures.any((m) => m.repeatStart || m.repeatEnd),
        isFalse,
      );
    });
  });

  group('section ranges', () {
    test('a picked range becomes one section and the rest keeps its name', () {
      final score = _score(measures: 10, marks: {0: 'VERSE', 8: 'CHORUS'});
      final sequence = setSectionRange(
        score,
        PlaybackSequence.empty,
        start: 2,
        end: 4,
        name: 'CHORUS',
      );

      expect(scoreSections(score, sequence).map(_describe), [
        'm0 VERSE 0-1',
        'm2 CHORUS 2-4',
        'm5 VERSE 5-7',
        'm8 CHORUS 8-9',
      ]);
    });

    test('boundaries inside the range go, with their steps', () {
      final score = _score(
        measures: 8,
        marks: {0: 'INTRO', 3: 'VERSE', 6: 'CHORUS'},
      );
      var sequence = materializePlaybackSequence(score, PlaybackSequence.empty);
      sequence = sequence.copyWith(
        steps: [
          PlaybackStep(sectionId: sectionIdAt(3)),
          PlaybackStep(sectionId: sectionIdAt(6)),
        ],
      );
      sequence = setSectionRange(
        score,
        sequence,
        start: 2,
        end: 6,
        name: 'BRIDGE',
      );

      expect(scoreSections(score, sequence).map(_describe), [
        'm0 INTRO 0-1',
        'm2 BRIDGE 2-6',
        'm7 CHORUS 7-7',
      ]);
      expect(sequence.steps.map((s) => s.sectionId), isEmpty);
    });

    test('a range reaching the last bar leaves nothing after it', () {
      final score = _score(measures: 4);
      final sequence = setSectionRange(
        score,
        PlaybackSequence.empty,
        start: 1,
        end: 3,
        name: 'OUTRO',
      );
      expect(scoreSections(score, sequence).map(_describe), [
        'm0  0-0',
        'm1 OUTRO 1-3',
      ]);
    });
  });

  group('jumps', () {
    MusicScore song(List<MusicMeasure> measures) => MusicScore(
      parts: [MusicPart(id: 'P1', name: 'Voice', measures: measures)],
    );

    test('D.S. al Fine goes back to the segno and stops at Fine', () {
      final score = song([
        _measure(0),
        _measure(1),
        _measure(2, navigation: [MusicNavigation.segno]),
        _measure(3, navigation: [MusicNavigation.fine]),
        _measure(4),
        _measure(5, navigation: [MusicNavigation.dalSegno]),
      ]);

      expect(writtenRepeatOrder(score), [0, 1, 2, 3, 4, 5, 2, 3]);
      expect(hasNavigationJumps(score), isTrue);
    });

    test('D.C. al Fine goes back to the start', () {
      final score = song([
        _measure(0),
        _measure(1, navigation: [MusicNavigation.fine]),
        _measure(2),
        _measure(3, navigation: [MusicNavigation.daCapo]),
      ]);

      expect(writtenRepeatOrder(score), [0, 1, 2, 3, 0, 1]);
    });

    test('D.S. al Coda skips repeats and earlier endings after the jump', () {
      // Shaped like 주가 보이신 생명의 길: pickup, |: segno, 1st and 2nd
      // endings, To Coda, D.S. al Coda, then the coda.
      final score = song([
        _measure(0),
        _measure(
          1,
          barlines: [_barline('left', repeat: 'forward')],
          navigation: [MusicNavigation.segno],
        ),
        _measure(2),
        _measure(
          3,
          barlines: [
            _barline('left', endingType: 'start', endings: [1]),
            _barline('right', repeat: 'backward'),
          ],
        ),
        _measure(
          4,
          barlines: [
            _barline('left', endingType: 'start', endings: [2]),
          ],
        ),
        _measure(5, navigation: [MusicNavigation.toCoda]),
        _measure(6, navigation: [MusicNavigation.dalSegno]),
        _measure(7, navigation: [MusicNavigation.coda]),
        _measure(8),
      ]);

      expect(writtenRepeatOrder(score), [
        0, 1, 2, 3, 1, 2, 4, 5, 6, //
        1, 2, 4, 5, 7, 8,
      ]);
    });

    test('the coda keeps its repeats, counted from its endings', () {
      // 1-5. then 6.: six passes, the sixth taking the last ending.
      final score = song([
        _measure(0, navigation: [MusicNavigation.segno]),
        _measure(1, navigation: [MusicNavigation.toCoda]),
        _measure(2, navigation: [MusicNavigation.dalSegno]),
        _measure(
          3,
          barlines: [_barline('left', repeat: 'forward')],
          navigation: [MusicNavigation.coda],
        ),
        _measure(
          4,
          barlines: [
            _barline('left', endingType: 'start', endings: [1, 2, 3, 4, 5]),
            _barline('right', repeat: 'backward'),
          ],
        ),
        _measure(
          5,
          barlines: [
            _barline('left', endingType: 'start', endings: [6]),
          ],
        ),
      ]);

      expect(writtenRepeatOrder(score), [
        0, 1, 2, // up to the D.S.
        0, 1, // from the segno to To Coda, once
        3, 4, 3, 4, 3, 4, 3, 4, 3, 4, // passes 1-5 take the first ending
        3, 5, // pass 6 takes the last one
      ]);
    });

    test('an ending bracket can span several bars', () {
      final score = song([
        _measure(0, barlines: [_barline('left', repeat: 'forward')]),
        _measure(
          1,
          barlines: [
            _barline('left', endingType: 'start', endings: [1]),
          ],
        ),
        _measure(
          2,
          barlines: [
            _barline('right', endingType: 'stop', endings: [1]),
            _barline('right', repeat: 'backward'),
          ],
        ),
        _measure(
          3,
          barlines: [
            _barline('left', endingType: 'start', endings: [2]),
          ],
        ),
      ]);

      expect(writtenRepeatOrder(score), [0, 1, 2, 0, 3]);
    });

    test('a jump inside a repeat waits for the last pass', () {
      final score = song([
        _measure(0, navigation: [MusicNavigation.segno]),
        _measure(
          1,
          barlines: [_barline('right', repeat: 'backward')],
          navigation: [MusicNavigation.dalSegno],
        ),
        _measure(2),
      ]);

      // Both passes of bars 0-1, then the jump, then bars 0-1 once and on.
      expect(writtenRepeatOrder(score), [0, 1, 0, 1, 0, 1, 2]);
    });

    test('playing a score with jumps lays its bars out in jump order', () {
      final score = song([
        _measure(0, navigation: [MusicNavigation.segno]),
        _measure(1, navigation: [MusicNavigation.fine]),
        _measure(2, navigation: [MusicNavigation.dalSegno]),
      ]);

      final played = expandPlaybackSequence(score);
      expect(played.parts.single.measures.map((m) => m.number), [
        '1',
        '2',
        '3',
        '4',
        '5',
      ]);
      // Without jumps the written score is played as is.
      final plain = _score();
      expect(identical(expandPlaybackSequence(plain), plain), isTrue);
    });
  });

  group('jump conventions', () {
    MusicScore song(List<MusicMeasure> measures) => MusicScore(
      parts: [MusicPart(id: 'P1', name: 'Voice', measures: measures)],
    );

    test('To Coda written after the D.S. bar is still followed', () {
      // 1 2(segno) 3 4(D.S.) 5 6(To Coda) 7 8(coda): the second time
      // through goes on past the D.S. into 5 and 6, then to the coda.
      final score = song([
        _measure(0),
        _measure(1, navigation: [MusicNavigation.segno]),
        _measure(2),
        _measure(3, navigation: [MusicNavigation.dalSegno]),
        _measure(4),
        _measure(5, navigation: [MusicNavigation.toCoda]),
        _measure(6),
        _measure(7, navigation: [MusicNavigation.coda]),
      ]);

      expect(writtenRepeatOrder(score), [0, 1, 2, 3, 1, 2, 3, 4, 5, 7]);
    });

    test('without To Coda, repeats resume where the music is new', () {
      // A repeat before the D.S. plays once after it; a repeat in bars never
      // played before the D.S. (a "To Coda" the conversion missed) plays
      // with its endings.
      final score = song([
        _measure(0, navigation: [MusicNavigation.segno]),
        _measure(
          1,
          barlines: [
            _barline('left', endingType: 'start', endings: [1]),
            _barline(
              'right',
              endingType: 'stop',
              endings: [1],
              repeat: 'backward',
            ),
          ],
        ),
        _measure(
          2,
          barlines: [
            _barline('left', endingType: 'start', endings: [2]),
            _barline('right', endingType: 'discontinue', endings: [2]),
          ],
          navigation: [MusicNavigation.dalSegno],
        ),
        _measure(3, barlines: [_barline('left', repeat: 'forward')]),
        _measure(
          4,
          barlines: [
            _barline('left', endingType: 'start', endings: [1]),
            _barline(
              'right',
              endingType: 'stop',
              endings: [1],
              repeat: 'backward',
            ),
          ],
        ),
        _measure(
          5,
          barlines: [
            _barline('left', endingType: 'start', endings: [2]),
            _barline('right', endingType: 'discontinue', endings: [2]),
          ],
        ),
      ]);

      expect(writtenRepeatOrder(score), [0, 1, 0, 2, 0, 2, 3, 4, 3, 5]);
    });
  });

  group('custom order', () {
    MusicScore song(List<MusicMeasure> measures) => MusicScore(
      parts: [MusicPart(id: 'P1', name: 'Voice', measures: measures)],
    );

    // Verse 0-1 repeated, Chorus 2-5 with 1st ending (4) and 2nd ending (5),
    // D.S. back to the chorus.
    MusicScore withEndings() => song([
      _measure(
        0,
        mark: 'VERSE',
        barlines: [_barline('left', repeat: 'forward')],
      ),
      _measure(1, barlines: [_barline('right', repeat: 'backward')]),
      _measure(
        2,
        mark: 'CHORUS',
        barlines: [_barline('left', repeat: 'forward')],
        navigation: [MusicNavigation.segno],
      ),
      _measure(3),
      _measure(
        4,
        barlines: [
          _barline('left', endingType: 'start', endings: [1]),
          _barline(
            'right',
            endingType: 'stop',
            endings: [1],
            repeat: 'backward',
          ),
        ],
      ),
      _measure(
        5,
        barlines: [
          _barline('left', endingType: 'start', endings: [2]),
          _barline('right', endingType: 'discontinue', endings: [2]),
        ],
        navigation: [MusicNavigation.fine],
      ),
      _measure(6, mark: 'BRIDGE', navigation: [MusicNavigation.dalSegno]),
    ]);

    List<int> play(MusicScore score, List<(int, int)> steps) =>
        performanceMeasureMap(
          score,
          PlaybackSequence(
            steps: [
              for (final (start, repeats) in steps)
                PlaybackStep(sectionId: sectionIdAt(start), repeats: repeats),
            ],
          ),
        );

    test('each pass of a section takes its ending, the last pass the last', () {
      final score = withEndings();

      expect(play(score, [(2, 2)]), [2, 3, 4, 2, 3, 5]);
      expect(play(score, [(2, 3)]), [2, 3, 4, 2, 3, 4, 2, 3, 5]);
      // Played once, as after a D.S., the chorus leads out through the 2nd.
      expect(play(score, [(2, 1)]), [2, 3, 5]);
    });

    test('building the order from the score keeps its repeats and jumps', () {
      final score = withEndings();

      expect(writtenRepeatOrder(score), [
        0, 1, 0, 1, 2, 3, 4, 2, 3, 5, 6, 2, 3, 5, //
      ]);
      final built = writtenOrderSequence(score, PlaybackSequence.empty);
      expect(built.steps.map((s) => (s.sectionId, s.repeats, s.pass)), [
        (sectionIdAt(0), 2, null),
        (sectionIdAt(2), 2, null),
        (sectionIdAt(6), 1, null),
        (sectionIdAt(2), 1, null),
      ]);
      expect(performanceMeasureMap(score, built), writtenRepeatOrder(score));
    });

    test('jumps into the middle of sections split them, no bar lost', () {
      // Like 주가 보이신 생명의 길: the segno and the repeat start sit on the
      // second bar of the intro, the repeat's endings in the next section,
      // To Coda and the coda inside one long section.
      final score = song([
        _measure(0, mark: 'INTRO'),
        _measure(
          1,
          barlines: [_barline('left', repeat: 'forward')],
          navigation: [MusicNavigation.segno],
        ),
        _measure(2),
        _measure(3, mark: 'VERSE'),
        _measure(4),
        _measure(5, mark: 'BRIDGE'),
        _measure(
          6,
          barlines: [
            _barline('left', endingType: 'start', endings: [1]),
            _barline(
              'right',
              endingType: 'stop',
              endings: [1],
              repeat: 'backward',
            ),
          ],
        ),
        _measure(
          7,
          barlines: [
            _barline('left', endingType: 'start', endings: [2]),
            _barline('right', endingType: 'discontinue', endings: [2]),
          ],
        ),
        _measure(8, mark: 'CHORUS'),
        _measure(9, navigation: [MusicNavigation.toCoda]),
        _measure(10),
        _measure(11, navigation: [MusicNavigation.dalSegno]),
        _measure(12, navigation: [MusicNavigation.coda]),
        _measure(13),
      ]);

      final built = writtenOrderSequence(score, PlaybackSequence.empty);

      expect(performanceMeasureMap(score, built), writtenRepeatOrder(score));
      // Pieces keep their section's name and count as one section.
      final sections = scoreSections(score, built);
      expect(sections.map((s) => (s.startMeasureIndex, s.name, s.number)), [
        (0, 'INTRO', null),
        (1, 'INTRO', null),
        (3, 'VERSE', null),
        (5, 'BRIDGE', null),
        (8, 'CHORUS', null),
        (10, 'CHORUS', null),
        (12, 'CHORUS', null),
      ]);
      // The bridge's two passes go through the 1st, then the 2nd ending;
      // after the D.S. it plays once more, through the 2nd.
      final bridge = built.steps
          .where((s) => s.sectionId == sectionIdAt(5))
          .toList();
      expect(bridge.map((s) => (s.repeats, s.pass)), [
        (1, 1),
        (1, null),
        (1, null),
      ]);
    });

    test('Fine and brackets without a repeat sign are kept exactly', () {
      // D.S. al Fine with Fine inside a section, and 1./2. brackets whose
      // repeat sign was not recognized (both play, as written).
      final score = song([
        _measure(0, mark: 'VERSE'),
        _measure(1, navigation: [MusicNavigation.segno]),
        _measure(2, navigation: [MusicNavigation.fine]),
        _measure(3),
        _measure(
          4,
          mark: 'CHORUS',
          barlines: [
            _barline('left', endingType: 'start', endings: [1]),
          ],
        ),
        _measure(
          5,
          barlines: [
            _barline('left', endingType: 'start', endings: [2]),
            _barline('right', endingType: 'discontinue', endings: [2]),
          ],
          navigation: [MusicNavigation.dalSegno],
        ),
      ]);

      final built = writtenOrderSequence(score, PlaybackSequence.empty);

      expect(writtenRepeatOrder(score), [0, 1, 2, 3, 4, 5, 1, 2]);
      expect(performanceMeasureMap(score, built), writtenRepeatOrder(score));
    });

    test('two sections the user named alike stay two', () {
      final sequence = PlaybackSequence(
        marks: [
          SectionMark(startMeasureIndex: 0, name: 'CHORUS'),
          SectionMark(startMeasureIndex: 2, name: 'CHORUS'),
          SectionMark(startMeasureIndex: 3, name: 'CHORUS', continued: true),
        ],
      );

      expect(
        scoreSections(_score(), sequence).map((s) => (s.number, s.continued)),
        [(1, false), (2, false), (2, true)],
      );
      expect(
        PlaybackSequence.fromJson(sequence.toJson()).marks.last.continued,
        isTrue,
      );
    });

    test('the expanded copy keeps a section at the start of every pass', () {
      final score = withEndings();
      final sequence = PlaybackSequence(
        steps: [
          PlaybackStep(sectionId: sectionIdAt(0)),
          PlaybackStep(sectionId: sectionIdAt(2), repeats: 2),
          PlaybackStep(sectionId: sectionIdAt(0)),
        ],
      );

      expect(
        performanceSectionMarks(
          score,
          sequence,
        ).map((m) => (m.startMeasureIndex, m.name)),
        // The chorus played twice reads as two sections.
        [(0, 'VERSE'), (2, 'CHORUS'), (5, 'CHORUS'), (8, 'VERSE')],
      );
    });

    test('the origin tells copies of different versions or orders apart', () {
      final one = PlaybackSequence(steps: [PlaybackStep(sectionId: 'm0')]);
      final two = PlaybackSequence(
        steps: [PlaybackStep(sectionId: 'm0', repeats: 2)],
      );

      expect(performanceOrigin('a', one), performanceOrigin('a', one));
      expect(performanceOrigin('a', one), isNot(performanceOrigin('b', one)));
      expect(performanceOrigin('a', one), isNot(performanceOrigin('a', two)));
    });

    test('playback lays repeats out; an export keeps them written', () {
      final score = song([
        _measure(0, barlines: [_barline('right', repeat: 'backward')]),
        _measure(1),
      ]);

      expect(identical(expandPlaybackSequence(score), score), isTrue);
      final played = expandPlaybackSequence(
        score,
        PlaybackSequence.empty,
        true,
      );
      expect(played.measureCount, 3);
      expect(played.parts.single.measures.any((m) => m.repeatEnd), isFalse);
      final plain = _score();
      expect(
        identical(
          expandPlaybackSequence(plain, PlaybackSequence.empty, true),
          plain,
        ),
        isTrue,
      );
    });
  });

  group('bar edits', () {
    // Intro 0, Verse 1-2, Chorus 3-5.
    final sequence = PlaybackSequence(
      marks: [
        SectionMark(startMeasureIndex: 0, name: 'INTRO'),
        SectionMark(startMeasureIndex: 1, name: 'VERSE'),
        SectionMark(startMeasureIndex: 3, name: 'CHORUS'),
      ],
      steps: [
        PlaybackStep(sectionId: sectionIdAt(1), repeats: 2),
        PlaybackStep(sectionId: sectionIdAt(3)),
      ],
    );

    List<(int, String)> marksOf(PlaybackSequence s) => [
      for (final mark in s.marks) (mark.startMeasureIndex, mark.name),
    ];

    test('sections follow their bars and undo puts them back', () {
      final editor = MusicScoreEditor(_score(measures: 6));
      final base = editor.measureIds;

      editor.apply(const InsertMeasureCommand(afterMeasureIndex: 0));
      var next = remapSectionMarks(sequence, base, editor.measureIds);
      expect(marksOf(next), [(0, 'INTRO'), (2, 'VERSE'), (4, 'CHORUS')]);
      expect(next.steps.map((s) => s.sectionId), [
        sectionIdAt(2),
        sectionIdAt(4),
      ]);

      // Deleting the chorus's first bar starts the chorus at its next bar.
      editor.apply(const DeleteMeasureCommand(measureIndex: 4));
      next = remapSectionMarks(sequence, base, editor.measureIds);
      expect(marksOf(next), [(0, 'INTRO'), (2, 'VERSE'), (4, 'CHORUS')]);

      editor
        ..undo()
        ..undo();
      expect(
        marksOf(remapSectionMarks(sequence, base, editor.measureIds)),
        marksOf(sequence),
      );
    });

    test('the unnamed first section keeps its steps through bar edits', () {
      // Boundaries from bar 3 on: bars 1-2 are the unnamed first section.
      final first = PlaybackSequence(
        marks: [SectionMark(startMeasureIndex: 2, name: 'VERSE')],
        steps: [
          PlaybackStep(sectionId: sectionIdAt(0), repeats: 2),
          PlaybackStep(sectionId: sectionIdAt(2)),
        ],
      );
      final editor = MusicScoreEditor(_score(measures: 4));
      final base = editor.measureIds;

      editor.apply(const InsertMeasureCommand(afterMeasureIndex: -1));
      var next = remapSectionMarks(first, base, editor.measureIds);
      expect(marksOf(next), [(3, 'VERSE')]);
      expect(next.steps.map((s) => s.sectionId), [
        sectionIdAt(0),
        sectionIdAt(3),
      ]);

      // With its bars gone the first section is gone, and its steps with
      // it: they would play the verse, which now starts at the first bar.
      editor
        ..undo()
        ..apply(const DeleteMeasureCommand(measureIndex: 0))
        ..apply(const DeleteMeasureCommand(measureIndex: 0));
      next = remapSectionMarks(first, base, editor.measureIds);
      expect(marksOf(next), [(0, 'VERSE')]);
      expect(next.steps.map((s) => (s.sectionId, s.repeats)), [
        (sectionIdAt(0), 1),
      ]);
    });

    test('sections from printed rehearsal marks follow bar edits too', () {
      final score = _score(measures: 6, marks: {0: 'INTRO', 3: 'VERSE'});
      final order = PlaybackSequence(
        steps: [PlaybackStep(sectionId: sectionIdAt(3), repeats: 2)],
      );
      final editor = MusicScoreEditor(score);
      final base = editor.measureIds;

      editor.apply(const InsertMeasureCommand(afterMeasureIndex: 0));
      final next = remapSectionMarks(
        order,
        base,
        editor.measureIds,
        writtenMarks: rehearsalSectionMarks(score),
      );

      expect(marksOf(next), [(0, 'INTRO'), (4, 'VERSE')]);
      expect(next.steps.single.sectionId, sectionIdAt(4));
    });

    test('a step never plays no bar at all', () {
      // Only the 2nd-ending bar is in the section; a pass no bracket serves
      // plays the section as written instead of nothing.
      final score = MusicScore(
        parts: [
          MusicPart(
            id: 'P1',
            name: 'V',
            measures: [
              _measure(0, barlines: [_barline('left', repeat: 'forward')]),
              _measure(
                1,
                barlines: [
                  _barline('left', endingType: 'start', endings: [1]),
                  _barline(
                    'right',
                    endingType: 'stop',
                    endings: [1],
                    repeat: 'backward',
                  ),
                ],
              ),
              _measure(
                2,
                mark: 'OUT',
                barlines: [
                  _barline('left', endingType: 'start', endings: [2]),
                  _barline('right', endingType: 'discontinue', endings: [2]),
                ],
              ),
            ],
          ),
        ],
      );
      final sequence = PlaybackSequence(
        marks: [
          SectionMark(startMeasureIndex: 0, name: 'A'),
          SectionMark(startMeasureIndex: 2, name: 'OUT'),
        ],
        steps: [PlaybackStep(sectionId: sectionIdAt(2), pass: 7)],
      );

      expect(performanceMeasureMap(score, sequence), [2]);
    });

    test('a section whose bars are all gone is dropped with its steps', () {
      final editor = MusicScoreEditor(_score(measures: 6));
      final base = editor.measureIds;

      editor
        ..apply(const DeleteMeasureCommand(measureIndex: 1))
        ..apply(const DeleteMeasureCommand(measureIndex: 1));
      final next = remapSectionMarks(sequence, base, editor.measureIds);

      expect(marksOf(next), [(0, 'INTRO'), (1, 'CHORUS')]);
      expect(next.steps.map((s) => s.sectionId), [sectionIdAt(1)]);
    });

    test('moved and duplicated bars keep or get their own identity', () {
      final editor = MusicScoreEditor(_score(measures: 3));
      editor.apply(const DuplicateMeasureCommand(measureIndex: 0));
      expect(editor.measureIds, [0, 3, 1, 2]);
      editor.apply(const MoveMeasureCommand(fromIndex: 3, toIndex: 0));
      expect(editor.measureIds, [2, 0, 3, 1]);
    });
  });

  group('files', () {
    test('round-trips the current format', () {
      final sequence = PlaybackSequence(
        marks: [
          SectionMark(startMeasureIndex: 0, name: 'INTRO'),
          SectionMark(startMeasureIndex: 4, name: 'Solo'),
        ],
        steps: [
          PlaybackStep(sectionId: sectionIdAt(4), repeats: 2),
          PlaybackStep(sectionId: sectionIdAt(0)),
        ],
      );

      expect(PlaybackSequence.fromJson(sequence.toJson()), sequence);
    });

    test('converts start–end ranges and name-based items', () {
      final legacy = PlaybackSequence.fromJson({
        'items': [
          {'section': 'VERSE', 'repeats': 2},
          {'section': 'CHORUS', 'repeats': 1},
        ],
        'sections': [
          {'section': 'VERSE', 'start': 0, 'end': 1},
          {'section': 'CHORUS', 'start': 4, 'end': 5},
        ],
      });
      final score = _score(measures: 8);

      final materialized = materializePlaybackSequence(score, legacy);

      expect(scoreSections(score, materialized).map(_describe), [
        'm0 VERSE 0-1',
        'm2  2-3',
        'm4 CHORUS 4-5',
        'm6  6-7',
      ]);
      expect(materialized.steps, [
        PlaybackStep(sectionId: sectionIdAt(0), repeats: 2),
        PlaybackStep(sectionId: sectionIdAt(4)),
      ]);
    });

    test('converts name-based items that used rehearsal marks', () {
      final score = _score(
        measures: 6,
        marks: {0: 'VERSE', 2: 'CHORUS', 4: 'VERSE'},
      );
      final legacy = PlaybackSequence.fromJson({
        'items': [
          {'section': 'VERSE', 'repeats': 2},
        ],
      });

      final materialized = materializePlaybackSequence(score, legacy);

      // The old format played every section with the name.
      expect(materialized.steps, [
        PlaybackStep(sectionId: sectionIdAt(0), repeats: 2),
        PlaybackStep(sectionId: sectionIdAt(4), repeats: 2),
      ]);
      expect(materialized.marks.map((m) => m.startMeasureIndex), [0, 2, 4]);
    });
  });

  test('a pressed bar starts where the order plays it, nearest to now', () {
    // Bars 0..3 of one quarter, two, one and four quarters; the order plays
    // bar 2, bar 3, then bar 2 again.
    const lengths = [1.0, 2.0, 1.0, 4.0];
    const map = [2, 3, 2];
    expect(performanceStartOf(map, lengths, 2), 0);
    expect(performanceStartOf(map, lengths, 3), 1 / 6);
    // Pressed during the second pass: the second pass.
    expect(performanceStartOf(map, lengths, 2, near: 0.9), 5 / 6);
    // A bar the order skips cannot be played from.
    expect(performanceStartOf(map, lengths, 0), isNull);
    // The answer and the bar it names agree.
    expect(writtenMeasureAt(map, lengths, 1 / 6 + 0.001), 3);
  });
}

String _describe(ScoreSection section) =>
    '${section.id} ${section.name} '
    '${section.startMeasureIndex}-${section.endMeasureIndex}';

MusicBarline _barline(
  String location, {
  String? repeat,
  int? times,
  String? endingType,
  List<int> endings = const [],
}) => MusicBarline(
  location: location,
  xml: '<barline location="$location"/>',
  repeat: repeat,
  times: times,
  endingType: endingType,
  endingNumbers: endings,
);

void _dividingTests() {
  group('dividing a converted score', () {
    test('a mark the conversion misread keeps its place without its name', () {
      // A boxed "B" read as "프", a boxed letter read right, a Korean word.
      final score = _score(measures: 20, marks: {4: '프', 8: 'B', 12: '간주'});

      expect(isMisreadSectionName('프'), isTrue);
      expect(isMisreadSectionName('쁘'), isTrue);
      for (final name in ['A', 'B2', 'Verse', '간주', '후렴', '']) {
        expect(isMisreadSectionName(name), isFalse, reason: name);
      }
      expect(
        scoreSections(
          score,
          PlaybackSequence.empty,
        ).map((s) => (s.startMeasureIndex, s.endMeasureIndex, s.name)),
        [(0, 3, ''), (4, 7, ''), (8, 11, 'B'), (12, 19, '간주')],
      );
    });

    test('a misread mark makes the app label the sections itself', () {
      final clean = _score(measures: 8, marks: {0: 'A', 4: 'B'});
      final misread = _score(measures: 8, marks: {0: 'A', 4: '프'});

      expect(usesOwnSectionLabels(clean, PlaybackSequence.empty), isFalse);
      expect(usesOwnSectionLabels(misread, PlaybackSequence.empty), isTrue);
      expect(
        usesOwnSectionLabels(
          clean,
          PlaybackSequence(
            marks: [SectionMark(startMeasureIndex: 0, name: 'INTRO')],
          ),
        ),
        isTrue,
      );
    });

    test('naming a line of a nameless stretch names that line only', () {
      // Bars 1-11 have no name (the first mark is at bar 12); the first line
      // is bars 1-4.
      final score = _score(measures: 20, marks: {11: 'VERSE'});
      final named = nameSectionPick(
        score,
        PlaybackSequence.empty,
        start: 0,
        end: 3,
        extended: false,
        name: 'INTRO',
      );

      expect(
        scoreSections(
          score,
          named,
        ).map((s) => (s.startMeasureIndex, s.endMeasureIndex, s.name)),
        [(0, 3, 'INTRO'), (4, 10, ''), (11, 19, 'VERSE')],
      );
    });

    test('naming the first line of a named section renames the section', () {
      final score = _score(measures: 20, marks: {0: 'INTRO', 11: 'VERSE'});
      final named = nameSectionPick(
        score,
        PlaybackSequence.empty,
        start: 0,
        end: 3,
        extended: false,
        name: 'CHORUS',
      );

      expect(
        scoreSections(
          score,
          named,
        ).map((s) => (s.startMeasureIndex, s.endMeasureIndex, s.name)),
        [(0, 10, 'CHORUS'), (11, 19, 'VERSE')],
      );
    });
  });
}

MusicMeasure _measure(
  int index, {
  int beats = 4,
  double noteQuarters = 4,
  bool implicit = false,
  List<MusicBarline> barlines = const [],
  String? mark,
  List<MusicNavigation> navigation = const [],
}) {
  return MusicMeasure(
    number: '${index + 1}',
    implicit: implicit,
    barlines: barlines,
    attributes: MusicAttributes(
      divisions: 2,
      time: MusicTimeSignature(beats: beats, beatType: 4),
    ),
    events: [
      if (mark != null) MusicDirection(onset: 0, staff: 1, rehearsal: mark),
      for (final jump in navigation)
        MusicDirection(onset: 0, staff: 1, navigation: jump),
      MusicNote(
        onset: 0,
        duration: (noteQuarters * 2).round(),
        voice: '1',
        staff: 1,
        pitch: MusicPitch(step: PitchStep.c, octave: 4 + index % 2),
      ),
    ],
  );
}

MusicScore _score({int measures = 4, Map<int, String> marks = const {}}) {
  return MusicScore(
    parts: [
      MusicPart(
        id: 'P1',
        name: 'Piano',
        measures: [
          for (var index = 0; index < measures; index++)
            _measure(index, mark: marks[index]),
        ],
      ),
    ],
  );
}
