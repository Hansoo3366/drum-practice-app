import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/staff_note_input.dart';

void main() {
  final attributes = MusicAttributes(
    divisions: 4,
    time: const MusicTimeSignature(beats: 4, beatType: 4),
    staves: 2,
  );

  test('maps staff duration types onto measure divisions', () {
    expect(durationForType(attributes, 'quarter'), 4);
    expect(durationForType(attributes, 'eighth'), 2);
    expect(durationForType(attributes, 'whole'), 16);
    expect(onsetFromTicks(960, 4), 4);
  });

  test('builds a note or rest from a staff tap', () {
    final measure = MusicMeasure(
      number: '1',
      attributes: attributes,
      events: const [],
    );
    final note = noteFromStaffTap(
      measure: measure,
      staff: 1,
      onsetTicks: 0,
      midi: 64,
      durationType: 'quarter',
      rest: false,
    );
    final rest = noteFromStaffTap(
      measure: measure,
      staff: 2,
      onsetTicks: 960,
      midi: 55,
      durationType: 'half',
      rest: true,
    );

    expect(note.pitch?.step, PitchStep.e);
    expect(note.pitch?.octave, 4);
    expect(note.duration, 4);
    expect(rest.isRest, isTrue);
    expect(rest.onset, 4);
    expect(rest.duration, 8);
    expect(rest.voice, '2');
    expect(rest.staff, 2);
  });

  test('applies a selected accidental to a natural staff pitch', () {
    final sharp = pitchFromMidi(64, alter: 1);
    final flat = pitchFromMidi(67, alter: -1);

    expect(sharp.step, PitchStep.e);
    expect(sharp.alter, 1);
    expect(flat.step, PitchStep.g);
    expect(flat.alter, -1);
  });

  test('finds a rest at a staff placement', () {
    final score = MusicScore(
      parts: [
        MusicPart(
          id: 'P1',
          name: 'Piano',
          measures: [
            MusicMeasure(
              number: '1',
              attributes: attributes,
              events: [
                MusicNote(onset: 0, duration: 16, voice: '1', staff: 1),
              ],
            ),
          ],
        ),
      ],
    );

    expect(
      findNoteAt(
        score: score,
        partIndex: 0,
        measureIndex: 0,
        staff: 1,
        onset: 0,
        rest: true,
      )?.eventIndex,
      0,
    );
    expect(scoreHasHarmony(score), isFalse);
  });
}
