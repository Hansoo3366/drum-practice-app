import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';

/// Random section and order edits, as the structure panel makes them, on
/// scores of random length; after every edit the order must still make
/// sense: boundaries sorted, unique and on real bars, sections covering every
/// bar, every step naming a section that exists, nothing thrown.
void main() {
  test('random section edits keep the order sound', () {
    final random = Random(20261002);
    var edits = 0;
    for (var round = 0; round < 400; round++) {
      final count = 1 + random.nextInt(40);
      final marks = <int, String>{};
      // Some scores come with rehearsal marks of their own.
      if (random.nextBool()) {
        for (var i = 0; i < count; i += 1 + random.nextInt(8)) {
          marks[i] = ['INTRO', 'VERSE', 'CHORUS', 'A', '프'][random.nextInt(5)];
        }
      }
      final score = _score(measures: count, marks: marks);
      var sequence = PlaybackSequence.empty;
      final trail = <String>[];
      void check(String step) {
        trail.add(step);
        final where = 'round $round, $count bars, [${trail.join(' ')}]';
        final starts = sequence.marks.map((m) => m.startMeasureIndex).toList();
        expect(
          starts,
          orderedEquals([...starts]..sort()),
          reason: '$where: sorted',
        );
        expect(starts.toSet().length, starts.length, reason: '$where: unique');
        for (final start in starts) {
          expect(
            start,
            inInclusiveRange(0, count - 1),
            reason: '$where: in range',
          );
        }
        final sections = scoreSections(score, sequence);
        if (sections.isNotEmpty) {
          expect(
            sections.first.startMeasureIndex,
            0,
            reason: '$where: first bar covered',
          );
          expect(
            sections.last.endMeasureIndex,
            count - 1,
            reason: '$where: last bar covered',
          );
          for (var i = 1; i < sections.length; i++) {
            expect(
              sections[i].startMeasureIndex,
              sections[i - 1].endMeasureIndex + 1,
              reason: '$where: contiguous',
            );
          }
        }
        final ids = {for (final s in sections) s.id};
        for (final step in sequence.steps) {
          expect(
            ids,
            contains(step.sectionId),
            reason: '$where: step ${step.sectionId} exists',
          );
        }
        // What plays can always be laid out.
        final map = performanceMeasureMap(score, sequence);
        for (final bar in map) {
          expect(
            bar,
            inInclusiveRange(0, count - 1),
            reason: '$where: played bar',
          );
        }
        expect(
          performanceSummary(score, sequence).measures,
          map.length,
          reason: '$where: summary',
        );
      }

      check('start');
      for (var i = 0; i < 25; i++) {
        final bar = random.nextInt(count);
        final name = [
          'INTRO',
          'VERSE',
          'CHORUS',
          '',
          'Pre',
          '간주',
        ][random.nextInt(6)];
        switch (random.nextInt(8)) {
          case 0:
            sequence = setSectionBoundary(
              score,
              sequence,
              measureIndex: bar,
              name: name,
            );
            check('name@$bar=$name');
          case 7:
            // As the panel names a pick: one line, a drawn range, or the
            // section that starts here.
            final end = random.nextBool() ? null : bar + random.nextInt(9);
            sequence = nameSectionPick(
              score,
              sequence,
              start: bar,
              end: end,
              extended: random.nextBool(),
              name: name,
            );
            check('pick@$bar-$end=$name');
            // The bar picked starts a section now, whatever was there.
            expect(
              scoreSections(
                score,
                sequence,
              ).any((s) => s.startMeasureIndex == bar),
              isTrue,
              reason: 'round $round: picked bar $bar starts a section',
            );
          case 1:
            final end = min(count - 1, bar + random.nextInt(6));
            sequence = setSectionRange(
              score,
              sequence,
              start: bar,
              end: end,
              name: name,
            );
            check('range@$bar-$end=$name');
          case 2:
            sequence = removeSectionBoundary(
              score,
              sequence,
              measureIndex: bar,
            );
            check('merge@$bar');
          case 3:
            final sections = scoreSections(score, sequence);
            if (sections.isEmpty) continue;
            final pick = sections[random.nextInt(sections.length)];
            sequence = sequence.copyWith(
              steps: [
                ...sequence.steps,
                PlaybackStep(
                  sectionId: pick.id,
                  repeats: 1 + random.nextInt(3),
                ),
              ],
            );
            check('add-step ${pick.id}');
          case 4:
            if (sequence.steps.isEmpty) continue;
            final steps = sequence.steps.toList();
            final from = random.nextInt(steps.length);
            final to = random.nextInt(steps.length);
            steps.insert(to, steps.removeAt(from));
            sequence = sequence.copyWith(steps: steps);
            check('move-step $from>$to');
          case 5:
            if (sequence.steps.isEmpty) continue;
            final steps = sequence.steps.toList();
            steps.removeAt(random.nextInt(steps.length));
            sequence = sequence.copyWith(steps: steps);
            check('remove-step');
          case 6:
            sequence = writtenOrderSequence(score, sequence);
            check('from-score');
        }
        edits++;
        // A round trip through JSON changes nothing.
        expect(PlaybackSequence.fromJson(sequence.toJson()), sequence);
      }
    }
    expect(edits, greaterThan(5000));
  });
}

MusicScore _score({int measures = 4, Map<int, String> marks = const {}}) {
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
                divisions: 2,
                time: const MusicTimeSignature(beats: 4, beatType: 4),
              ),
              events: [
                if (marks[index] case final mark?)
                  MusicDirection(onset: 0, staff: 1, rehearsal: mark),
                MusicNote(
                  onset: 0,
                  duration: 8,
                  voice: '1',
                  staff: 1,
                  pitch: MusicPitch(step: PitchStep.c, octave: 4 + index % 2),
                ),
              ],
            ),
        ],
      ),
    ],
  );
}
