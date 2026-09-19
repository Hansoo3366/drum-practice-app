import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_profile.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';

void main() {
  group('ArrangementProfile', () {
    test('round-trips JSON and treats unknown styles as off', () {
      const profile = ArrangementProfile(style: ArrangementStyle.pulse);
      expect(
        ArrangementProfile.fromJson(profile.toJson()),
        const ArrangementProfile(style: ArrangementStyle.pulse),
      );
      expect(ArrangementProfile.fromJson({'style': 'unknown'}).isOff, isTrue);
      expect(ArrangementProfile.fromJson(null).isOff, isTrue);
    });
  });

  group('applyArrangement', () {
    test('leaves the written score unchanged when the profile is off', () {
      final source = _score();
      expect(
        identical(applyArrangement(source, ArrangementProfile.off), source),
        isTrue,
      );
    });

    test('adds a held block chord without rewriting the melody', () {
      final source = _score();
      final result = applyArrangement(
        source,
        const ArrangementProfile(style: ArrangementStyle.block),
      );

      expect(identical(result, source), isFalse);
      expect(source.noteCount, 1);
      final notes = result.parts.first.measures.first.notes.toList();
      expect(
        notes.where((note) => note.voice != arrangementVoice),
        hasLength(1),
      );
      expect(
        notes.where((note) => note.voice == arrangementVoice),
        hasLength(4),
      );

      final bass = notes.firstWhere(
        (note) => note.voice == arrangementVoice && note.staff == 2,
      );
      expect(bass.pitch?.step, PitchStep.c);
      expect(bass.pitch?.octave, 2);
      expect(bass.duration, 16);
      expect(bass.isChord, isFalse);

      final chord = notes
          .where((note) => note.voice == arrangementVoice && note.staff == 1)
          .toList();
      expect(chord.map((note) => note.pitch?.step), [
        PitchStep.c,
        PitchStep.e,
        PitchStep.g,
      ]);
      expect(chord.map((note) => note.isChord), [false, true, true]);
    });

    test('repeats the chord on each beat for pulse', () {
      final result = applyArrangement(
        _score(),
        const ArrangementProfile(style: ArrangementStyle.pulse),
      );
      final arranged = result.parts.first.measures.first.notes
          .where((note) => note.voice == arrangementVoice && note.staff == 2)
          .toList();
      expect(arranged.map((note) => note.onset), [0, 4, 8, 12]);
      expect(arranged.map((note) => note.duration), everyElement(4));
    });

    test('arpeggiates bass and chord tones for broken style', () {
      final result = applyArrangement(
        _score(),
        const ArrangementProfile(style: ArrangementStyle.broken),
      );
      final arranged = result.parts.first.measures.first.notes
          .where((note) => note.voice == arrangementVoice)
          .toList();
      expect(arranged, hasLength(8));
      expect(arranged.first.pitch?.step, PitchStep.c);
      expect(arranged.first.staff, 2);
      expect(arranged[1].pitch?.step, PitchStep.c);
      expect(arranged[1].staff, 1);
      expect(arranged.map((note) => note.duration), everyElement(2));
    });

    test('uses a slash bass and minor third', () {
      final result = applyArrangement(
        _score(
          harmony: const MusicHarmony(
            onset: 0,
            staff: 1,
            rootStep: PitchStep.a,
            kind: 'minor',
            bassStep: PitchStep.c,
          ),
        ),
        const ArrangementProfile(style: ArrangementStyle.block),
      );
      final arranged = result.parts.first.measures.first.notes
          .where((note) => note.voice == arrangementVoice)
          .toList();
      expect(
        arranged.firstWhere((note) => note.staff == 2).pitch?.step,
        PitchStep.c,
      );
      expect(
        arranged
            .where((note) => note.staff == 1)
            .map((note) => note.pitch?.step),
        [PitchStep.a, PitchStep.c, PitchStep.e],
      );
    });

    test('does not mutate the source events collection', () {
      final source = _score();
      applyArrangement(
        source,
        const ArrangementProfile(style: ArrangementStyle.block),
      );
      expect(source.parts.first.measures.first.events, hasLength(2));
    });
  });
}

MusicScore _score({
  MusicHarmony harmony = const MusicHarmony(
    onset: 0,
    staff: 1,
    rootStep: PitchStep.c,
    kind: 'major',
  ),
}) {
  return MusicScore(
    title: 'Arrangement',
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
                duration: 16,
                voice: '1',
                staff: 1,
                pitch: const MusicPitch(step: PitchStep.g, octave: 5),
                type: 'whole',
              ),
              harmony,
            ],
          ),
        ],
      ),
    ],
  );
}
