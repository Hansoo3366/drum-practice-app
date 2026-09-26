import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/note_input.dart';
import 'package:page_a_diddle/features/digital_score/domain/staff_note_input.dart';

void main() {
  test('a quarter replaces part of a whole rest and keeps the bar full', () {
    final result = writeNoteInput(
      _grandStaff(),
      const NoteInputRequest(
        partIndex: 0,
        measureIndex: 0,
        staff: 1,
        onsetTicks: 960,
        midi: 60,
        durationType: 'quarter',
      ),
    );

    final notes = _notes(result.score, staff: 1);
    expect(result.changed, isTrue);
    expect(notes.map((note) => note.duration), [1, 1, 2]);
    expect(notes[0].isRest, isTrue);
    expect(notes[1].pitch?.step, PitchStep.c);
    expect(notes[1].pitch?.octave, 4);
    expect(notes[1].voice, '1');
    expect(notes.map((note) => note.end).last, 4);
    expect(_notes(result.score, staff: 2).single.voice, '2');
    expect(_notes(result.score, staff: 2).single.isRest, isTrue);
    expect(result.caret.onset, 2);
    expect(result.caret.measureIndex, 0);
  });

  test(
    'a longer note consumes the following note and a shorter one leaves a rest',
    () {
      final withTwoQuarters = writeNoteInput(
        writeNoteInput(
          _grandStaff(),
          const NoteInputRequest(
            partIndex: 0,
            measureIndex: 0,
            staff: 1,
            onsetTicks: 0,
            midi: 60,
            durationType: 'quarter',
          ),
        ).score,
        const NoteInputRequest(
          partIndex: 0,
          measureIndex: 0,
          staff: 1,
          onsetTicks: 960,
          midi: 62,
          durationType: 'quarter',
        ),
      ).score;

      final half = writeNoteInput(
        withTwoQuarters,
        const NoteInputRequest(
          partIndex: 0,
          measureIndex: 0,
          staff: 1,
          onsetTicks: 0,
          midi: 64,
          durationType: 'half',
        ),
      );
      final sounding = _notes(
        half.score,
        staff: 1,
      ).where((note) => !note.isRest);
      expect(sounding.map((note) => note.duration), [2]);
      expect(sounding.single.pitch?.step, PitchStep.e);

      final shortened = writeNoteInput(
        half.score,
        const NoteInputRequest(
          partIndex: 0,
          measureIndex: 0,
          staff: 1,
          onsetTicks: 0,
          midi: 64,
          durationType: 'quarter',
        ),
      );
      final after = _notes(shortened.score, staff: 1);
      expect(after.first.duration, 1);
      expect(after.first.isRest, isFalse);
      expect(after[1].isRest, isTrue);
      expect(after.fold<int>(0, (sum, note) => sum + note.duration), 4);
    },
  );

  test('deleting a note restores a rest', () {
    final written = writeNoteInput(
      _grandStaff(),
      const NoteInputRequest(
        partIndex: 0,
        measureIndex: 0,
        staff: 1,
        onsetTicks: 0,
        midi: 60,
        durationType: 'quarter',
      ),
    );
    final deleted = deleteNoteRestoringRest(written.score, written.address!);

    expect(_notes(deleted.score, staff: 1).single.isRest, isTrue);
    expect(_notes(deleted.score, staff: 1).single.duration, 4);
    expect(deleted.caret.onset, 0);
  });

  test('chord entry adds a pitch and ignores the same pitch', () {
    final root = writeNoteInput(
      _grandStaff(),
      const NoteInputRequest(
        partIndex: 0,
        measureIndex: 0,
        staff: 1,
        onsetTicks: 0,
        midi: 60,
        durationType: 'quarter',
      ),
    );
    final chord = writeNoteInput(
      root.score,
      const NoteInputRequest(
        partIndex: 0,
        measureIndex: 0,
        staff: 1,
        onsetTicks: 0,
        midi: 64,
        durationType: 'whole',
        chord: true,
      ),
    );
    final sounding = _notes(
      chord.score,
      staff: 1,
    ).where((note) => !note.isRest);
    expect(sounding.map((note) => note.pitch?.step), [
      PitchStep.c,
      PitchStep.e,
    ]);
    expect(sounding.map((note) => note.duration), [1, 1]);
    expect(sounding.map((note) => note.isChord), [false, true]);

    final duplicate = writeNoteInput(
      chord.score,
      const NoteInputRequest(
        partIndex: 0,
        measureIndex: 0,
        staff: 1,
        onsetTicks: 0,
        midi: 64,
        durationType: 'quarter',
        chord: true,
      ),
    );
    expect(duplicate.changed, isFalse);
  });

  test('semitone edits spell up with sharps and down with flats', () {
    expect(
      pitchBySemitone(const MusicPitch(step: PitchStep.e, octave: 4), 1).step,
      PitchStep.f,
    );
    expect(
      pitchBySemitone(const MusicPitch(step: PitchStep.e, octave: 4), 1).alter,
      0,
    );
    final sharp = pitchBySemitone(
      const MusicPitch(step: PitchStep.f, octave: 4),
      1,
    );
    expect(sharp.step, PitchStep.f);
    expect(sharp.alter, 1);
    final flat = pitchBySemitone(
      const MusicPitch(step: PitchStep.e, octave: 4),
      -1,
    );
    expect(flat.step, PitchStep.e);
    expect(flat.alter, -1);

    final written = writeNoteInput(
      _grandStaff(),
      const NoteInputRequest(
        partIndex: 0,
        measureIndex: 0,
        staff: 1,
        onsetTicks: 0,
        midi: 64,
        durationType: 'quarter',
      ),
    );
    final raised = repitchNote(written.score, written.address!, semitones: 1);
    expect(
      _notes(
        raised.score,
        staff: 1,
      ).firstWhere((note) => !note.isRest).pitch?.step,
      PitchStep.f,
    );
  });

  test('a duration that crosses the barline ties into the next measure', () {
    final result = writeNoteInput(
      _grandStaff(),
      const NoteInputRequest(
        partIndex: 0,
        measureIndex: 0,
        staff: 1,
        onsetTicks: 0,
        midi: 60,
        durationType: 'whole',
        dots: 1,
      ),
    );

    expect(result.score.measureCount, 2);
    final first = _notes(
      result.score,
      staff: 1,
    ).where((note) => !note.isRest).single;
    final second = _notes(
      result.score,
      staff: 1,
      measureIndex: 1,
    ).where((note) => !note.isRest).single;
    expect(first.duration, 4);
    expect(first.tieStart, isTrue);
    expect(second.duration, 2);
    expect(second.tieStop, isTrue);
    expect(second.pitch?.step, PitchStep.c);
    expect(result.caret.measureIndex, 1);
    expect(result.caret.onset, 2);
  });

  test('the same voice on both staves stays independent', () {
    final score = _grandStaff(sharedVoice: true);
    final result = writeNoteInput(
      score,
      const NoteInputRequest(
        partIndex: 0,
        measureIndex: 0,
        staff: 1,
        onsetTicks: 0,
        midi: 60,
        durationType: 'quarter',
      ),
    );

    final left = _notes(result.score, staff: 2).single;
    expect(left.isRest, isTrue);
    expect(left.isChord, isFalse);
    expect(left.voice, '1');
    expect(
      _notes(
        result.score,
        staff: 1,
      ).where((note) => !note.isRest).single.isChord,
      isFalse,
    );
  });

  test('letter entry stays near the previous note', () {
    expect(midiForLetter('c', previousMidi: null, staff: 1), 60);
    expect(midiForLetter('c', previousMidi: 64, staff: 1), 60);
    expect(midiForLetter('d', previousMidi: 72, staff: 1), 74);
  });
}

List<MusicNote> _notes(
  MusicScore score, {
  required int staff,
  int measureIndex = 0,
}) {
  return [
    for (final event in score.parts.first.measures[measureIndex].events)
      if (event is MusicNote && event.staff == staff) event,
  ];
}

MusicScore _grandStaff({bool sharedVoice = false}) {
  final attributes = MusicAttributes(
    divisions: 1,
    keyFifths: 0,
    time: const MusicTimeSignature(beats: 4, beatType: 4),
    staves: 2,
    clefs: const {
      1: MusicClef(sign: 'G', line: 2),
      2: MusicClef(sign: 'F', line: 4),
    },
  );
  return MusicScore(
    parts: [
      MusicPart(
        id: 'P1',
        name: 'Piano',
        measures: [
          MusicMeasure(
            number: '1',
            attributes: attributes,
            events: [
              MusicNote(onset: 0, duration: 4, voice: '1', staff: 1),
              MusicNote(
                onset: 0,
                duration: 4,
                voice: sharedVoice ? '1' : '2',
                staff: 2,
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
