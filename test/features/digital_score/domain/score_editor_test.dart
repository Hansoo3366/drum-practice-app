import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_editor.dart';

void main() {
  group('MusicScoreEditor', () {
    test('applies event edits and keeps undo, redo, and dirty state', () {
      final editor = MusicScoreEditor(_score());
      const address = ScoreEventAddress(
        partIndex: 0,
        measureIndex: 0,
        eventIndex: 0,
      );

      editor.apply(
        ReplaceScoreEventCommand(
          address: address,
          event: MusicNote(
            onset: 4,
            duration: 4,
            voice: '1',
            staff: 1,
            pitch: const MusicPitch(step: PitchStep.d, octave: 4),
            type: 'quarter',
          ),
        ),
      );

      expect(editor.isDirty, isTrue);
      expect(
        (editor.score.parts.first.measures.first.events.first as MusicNote)
            .onset,
        4,
      );
      editor.undo();
      expect(editor.isDirty, isFalse);
      expect(
        (editor.score.parts.first.measures.first.events.first as MusicNote)
            .onset,
        0,
      );
      editor.redo();
      expect(editor.isDirty, isTrue);
      editor.markSaved();
      expect(editor.isDirty, isFalse);

      editor.apply(const DeleteScoreEventCommand(address));
      expect(editor.score.parts.first.measures.first.events, isEmpty);
      editor.undo();
      expect(editor.score.parts.first.measures.first.events, hasLength(1));
    });

    test('drops redo branch when a new edit follows undo', () {
      final editor = MusicScoreEditor(_score());
      editor.apply(
        InsertScoreEventCommand(
          partIndex: 0,
          measureIndex: 0,
          event: MusicNote(onset: 4, duration: 4, voice: '1', staff: 1),
        ),
      );
      editor.undo();

      editor.apply(
        const InsertScoreEventCommand(
          partIndex: 0,
          measureIndex: 0,
          event: MusicHarmony(
            onset: 0,
            staff: 1,
            rootStep: PitchStep.c,
            kind: 'major',
          ),
        ),
      );

      expect(editor.canRedo, isFalse);
      expect(
        editor.score.parts.first.measures.first.events
            .whereType<MusicHarmony>(),
        hasLength(1),
      );
    });
  });

  group('measure commands', () {
    test('updates key and time on every part at the same measure', () {
      final result = const UpdateMeasureAttributesCommand(
        measureIndex: 0,
        keyFifths: 3,
        time: MusicTimeSignature(beats: 6, beatType: 8),
      ).apply(_score(partCount: 2));

      for (final part in result.parts) {
        final attributes = part.measures.first.attributes;
        expect(attributes.keyFifths, 3);
        expect(attributes.time?.beats, 6);
        expect(attributes.time?.beatType, 8);
      }
    });

    test('sets a section mark on every part at the same measure', () {
      final marked = const UpdateMeasureSectionCommand(
        measureIndex: 0,
        section: 'chorus',
      ).apply(_score(partCount: 2));

      for (final part in marked.parts) {
        expect(measurePlaybackSection(part.measures.first), 'CHORUS');
      }

      final cleared = const UpdateMeasureSectionCommand(
        measureIndex: 0,
        section: null,
      ).apply(marked);
      for (final part in cleared.parts) {
        expect(measurePlaybackSection(part.measures.first), isNull);
      }
    });

    test('inserts and deletes aligned grand-staff measures', () {
      final inserted = const InsertMeasureCommand(
        afterMeasureIndex: 0,
      ).apply(_score(partCount: 2));

      expect(
        inserted.parts.map((part) => part.measures.length),
        everyElement(2),
      );
      for (final part in inserted.parts) {
        final rests = part.measures[1].notes.toList();
        expect(rests, hasLength(2));
        expect(rests.every((note) => note.isRest), isTrue);
        expect(rests.map((note) => note.staff), [1, 2]);
        expect(rests.map((note) => note.duration), [16, 16]);
      }

      final deleted = const DeleteMeasureCommand(
        measureIndex: 0,
      ).apply(inserted);
      expect(
        deleted.parts.map((part) => part.measures.length),
        everyElement(1),
      );
      expect(deleted.parts.first.measures.first.number, '1');
      expect(
        () => const DeleteMeasureCommand(measureIndex: 0).apply(deleted),
        throwsFormatException,
      );

      final two = const InsertMeasureCommand(
        afterMeasureIndex: 0,
      ).apply(_score());
      final moved = const MoveMeasureCommand(
        fromIndex: 0,
        toIndex: 1,
      ).apply(two);
      expect(moved.parts.first.measures.map((measure) => measure.number), [
        '1',
        '2',
      ]);
      expect(
        moved.parts.first.measures.first.notes.every((note) => note.isRest),
        isTrue,
      );
      expect(
        moved.parts.first.measures[1].notes.any((note) => !note.isRest),
        isTrue,
      );
    });
  });

  test('maps an alphaTab note hit back to the source event', () {
    final address = findRenderedNoteAddress(
      score: _score(),
      partIndex: 0,
      measureIndex: 0,
      staff: 1,
      onsetTicks: 0,
      midi: 60,
    );

    expect(
      address,
      const ScoreEventAddress(partIndex: 0, measureIndex: 0, eventIndex: 0),
    );
  });

  test('normalizes simultaneous notes as a MusicXML chord', () {
    final score = InsertScoreEventCommand(
      partIndex: 0,
      measureIndex: 0,
      event: MusicNote(
        onset: 0,
        duration: 4,
        voice: '1',
        staff: 1,
        pitch: const MusicPitch(step: PitchStep.e, octave: 4),
      ),
    ).apply(_score());

    final notes = score.parts.first.measures.first.notes.toList();
    expect(notes.map((note) => note.isChord), [false, true]);

    final afterRootDelete = const DeleteScoreEventCommand(
      ScoreEventAddress(partIndex: 0, measureIndex: 0, eventIndex: 0),
    ).apply(score);
    expect(
      afterRootDelete.parts.first.measures.first.notes.single.isChord,
      isFalse,
    );
  });

  test('rejects a rest overlapping the same voice and onset', () {
    expect(
      () => InsertScoreEventCommand(
        partIndex: 0,
        measureIndex: 0,
        event: MusicNote(onset: 0, duration: 4, voice: '1', staff: 1),
      ).apply(_score()),
      throwsFormatException,
    );
  });

  test('score collections cannot be mutated outside edit commands', () {
    final score = _score();

    expect(() => score.parts.add(score.parts.first), throwsUnsupportedError);
    expect(() => score.parts.first.measures.clear(), throwsUnsupportedError);
    expect(
      () => score.parts.first.measures.first.events.clear(),
      throwsUnsupportedError,
    );
  });
}

MusicScore _score({int partCount = 1}) {
  return MusicScore(
    title: 'Editable',
    parts: [
      for (var partIndex = 0; partIndex < partCount; partIndex++)
        MusicPart(
          id: 'P${partIndex + 1}',
          name: 'Piano ${partIndex + 1}',
          measures: [
            MusicMeasure(
              number: '1',
              attributes: MusicAttributes(
                divisions: 4,
                time: const MusicTimeSignature(beats: 4, beatType: 4),
                staves: 2,
                clefs: const {
                  1: MusicClef(sign: 'G', line: 2),
                  2: MusicClef(sign: 'F', line: 4),
                },
              ),
              events: [
                MusicNote(
                  onset: 0,
                  duration: 4,
                  voice: '1',
                  staff: 1,
                  pitch: const MusicPitch(step: PitchStep.c, octave: 4),
                  type: 'quarter',
                ),
              ],
            ),
          ],
        ),
    ],
  );
}
