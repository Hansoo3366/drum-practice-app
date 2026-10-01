import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_editor.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_transpose.dart';

void main() {
  group('transposeScore', () {
    test('moves notes, chords, and key by two semitones to D', () {
      final result = const TransposeScoreCommand(semitones: 2).apply(_score());

      expect(result.parts.first.measures.first.attributes.keyFifths, 2);
      expect(result.parts[1].measures.first.attributes.keyFifths, 2);
      final note = result.parts.first.measures.first.events
          .whereType<MusicNote>()
          .first;
      expect(note.pitch?.step, PitchStep.d);
      expect(note.pitch?.alter, 0);
      expect(note.pitch?.octave, 4);
      expect(note.pitch?.midi, 62);
      expect(note.isRest, isFalse);

      final rest = result.parts.first.measures.first.events
          .whereType<MusicNote>()
          .firstWhere((event) => event.isRest);
      expect(rest.pitch, isNull);

      final harmony = result.parts.first.measures.first.events
          .whereType<MusicHarmony>()
          .single;
      expect(harmony.rootStep, PitchStep.g);
      expect(harmony.rootAlter, 0);
      expect(harmony.kind, 'major');
      expect(harmony.bassStep, PitchStep.d);
      expect(harmony.bassAlter, 0);
    });

    test('labels each measure key as a tonic on the staff', () {
      expect(keyTonicLabel(0), 'C');
      expect(keyTonicLabel(2), 'D');
      expect(keyTonicLabel(-2), 'B♭');
      expect(keyTonicLabel(14), 'D');
      expect(measureKeyFifths(_score(secondKeyFifths: -3)), [0, -3]);
    });

    test('spells C to D-flat when the flatter key has fewer accidentals', () {
      final result = const TransposeScoreCommand(semitones: 1).apply(_score());

      expect(result.parts.first.measures.first.attributes.keyFifths, -5);
      final note = result.parts.first.measures.first.events
          .whereType<MusicNote>()
          .first;
      expect(note.pitch?.step, PitchStep.d);
      expect(note.pitch?.alter, -1);
      expect(note.pitch?.midi, 61);
    });

    test('uses the chosen key spelling for the same semitone', () {
      final sharp = const TransposeScoreCommand(
        semitones: 1,
        fifthsDelta: 7,
      ).apply(_score());
      final note = sharp.parts.first.measures.first.events
          .whereType<MusicNote>()
          .first;

      expect(sharp.parts.first.measures.first.attributes.keyFifths, 7);
      expect(note.pitch?.step, PitchStep.c);
      expect(note.pitch?.alter, 1);
    });

    test('keeps written notes unchanged for a no-op interval', () {
      final source = _score();
      expect(
        identical(
          const TransposeScoreCommand(semitones: 0).apply(source),
          source,
        ),
        isTrue,
      );
    });

    test('raises an octave without changing the key', () {
      final result = const TransposeScoreCommand(semitones: 12).apply(_score());
      final note = result.parts.first.measures.first.events
          .whereType<MusicNote>()
          .first;

      expect(result.parts.first.measures.first.attributes.keyFifths, 0);
      expect(note.pitch?.step, PitchStep.c);
      expect(note.pitch?.octave, 5);
      expect(note.pitch?.midi, 72);
      final harmony = result.parts.first.measures.first.events
          .whereType<MusicHarmony>()
          .single;
      expect(harmony.rootStep, PitchStep.f);
      expect(harmony.bassStep, PitchStep.c);
    });

    test('transposes each measure key independently', () {
      final result = const TransposeScoreCommand(
        semitones: 2,
      ).apply(_score(secondKeyFifths: 1));

      expect(result.parts.first.measures[0].attributes.keyFifths, 2);
      expect(result.parts.first.measures[1].attributes.keyFifths, 3);
      final second = result.parts.first.measures[1].events
          .whereType<MusicNote>()
          .first;
      expect(second.pitch?.step, PitchStep.a);
      expect(second.pitch?.alter, 0);
    });

    test('is undoable on the editor history', () {
      final editor = MusicScoreEditor(_score());
      editor.apply(const TransposeScoreCommand(semitones: 2));

      expect(editor.isDirty, isTrue);
      expect(editor.score.parts.first.measures.first.attributes.keyFifths, 2);
      editor.undo();
      expect(editor.score.parts.first.measures.first.attributes.keyFifths, 0);
      expect(
        (editor.score.parts.first.measures.first.events.first as MusicNote)
            .pitch
            ?.step,
        PitchStep.c,
      );
    });

    test('rejects a pitch that leaves the MIDI range', () {
      expect(
        () => const TransposeScoreCommand(
          semitones: 2,
        ).apply(_score(note: const MusicPitch(step: PitchStep.g, octave: 9))),
        throwsFormatException,
      );
    });

    test('reports the score-specific semitone range before applying', () {
      final highest = _score(
        note: const MusicPitch(step: PitchStep.g, octave: 9),
      );
      final lowest = _score(
        note: const MusicPitch(step: PitchStep.c, octave: -1),
      );

      expect(validTransposeSemitones(highest).last, 0);
      expect(validTransposeSemitones(lowest).first, 0);
      expect(canTransposeScore(highest, semitones: 1), isFalse);
    });
  });

  test('chord symbols never get a double flat or double sharp', () {
    // A major down a major third to F: the letter shift takes F to D, so an
    // F flat chord would become D double flat; it is written as C.
    final moved = transposePitchClass(
      step: PitchStep.f,
      alter: -1,
      semitones: -4,
      letterShift: 5,
    );
    expect((moved.step, moved.alter), (PitchStep.c, 0));
    final sharp = simpleChordSpelling(PitchStep.f, 2);
    expect((sharp.step, sharp.alter), (PitchStep.g, 0));
    final plain = simpleChordSpelling(PitchStep.e, 1);
    expect((plain.step, plain.alter), (PitchStep.e, 1));
  });

  test('names the key of every bar, including minor keys', () {
    MusicMeasure bar(int fifths, [String? mode]) => MusicMeasure(
      number: '1',
      attributes: MusicAttributes(
        divisions: 1,
        keyFifths: fifths,
        keyMode: mode,
      ),
      events: const [],
    );
    final score = MusicScore(
      parts: [
        MusicPart(
          id: 'P1',
          name: 'Piano',
          measures: [bar(-1), bar(-2, 'minor'), bar(1), bar(4, 'minor')],
        ),
      ],
    );

    expect(measureKeyNames(score), ['F', 'Gm', 'G', 'C♯m']);
  });
}

MusicScore _score({
  int secondKeyFifths = 0,
  MusicPitch note = const MusicPitch(step: PitchStep.c, octave: 4),
}) {
  MusicMeasure measure({
    required String number,
    required int keyFifths,
    required List<MusicEvent> events,
  }) {
    return MusicMeasure(
      number: number,
      attributes: MusicAttributes(
        divisions: 4,
        keyFifths: keyFifths,
        time: const MusicTimeSignature(beats: 4, beatType: 4),
        staves: 2,
      ),
      events: events,
    );
  }

  return MusicScore(
    title: 'Transpose',
    parts: [
      MusicPart(
        id: 'P1',
        name: 'Piano',
        measures: [
          measure(
            number: '1',
            keyFifths: 0,
            events: [
              MusicNote(
                onset: 0,
                duration: 4,
                voice: '1',
                staff: 1,
                pitch: note,
                type: 'quarter',
              ),
              MusicNote(onset: 4, duration: 4, voice: '1', staff: 1),
              const MusicHarmony(
                onset: 0,
                staff: 1,
                rootStep: PitchStep.f,
                kind: 'major',
                bassStep: PitchStep.c,
              ),
            ],
          ),
          measure(
            number: '2',
            keyFifths: secondKeyFifths,
            events: [
              MusicNote(
                onset: 0,
                duration: 4,
                voice: '1',
                staff: 1,
                pitch: secondKeyFifths == 1
                    ? const MusicPitch(step: PitchStep.g, octave: 4)
                    : const MusicPitch(step: PitchStep.e, octave: 4),
              ),
            ],
          ),
        ],
      ),
      MusicPart(
        id: 'P2',
        name: 'Piano 2',
        measures: [
          measure(
            number: '1',
            keyFifths: 0,
            events: [
              MusicNote(
                onset: 0,
                duration: 4,
                voice: '1',
                staff: 2,
                pitch: const MusicPitch(step: PitchStep.c, octave: 3),
              ),
            ],
          ),
          measure(
            number: '2',
            keyFifths: secondKeyFifths,
            events: [MusicNote(onset: 0, duration: 4, voice: '1', staff: 2)],
          ),
        ],
      ),
    ],
  );
}
