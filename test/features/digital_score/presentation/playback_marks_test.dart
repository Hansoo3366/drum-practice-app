import 'package:flutter_notemus/flutter_notemus.dart' as nm;
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/domain/xml_measure_editor.dart';
import 'package:page_a_diddle/features/digital_score/presentation/midi_duration.dart';

const _editor = XmlMeasureEditor();

String _note(String step, int octave) =>
    '<note><pitch><step>$step</step><octave>$octave</octave></pitch>'
    '<duration>1</duration><voice>1</voice><type>quarter</type></note>';

final _score =
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<score-partwise version="4.0"><part-list>'
    '<score-part id="P1"><part-name>Voice</part-name></score-part>'
    '</part-list><part id="P1"><measure number="1">'
    '<attributes><divisions>1</divisions><key><fifths>0</fifths></key>'
    '<time><beats>4</beats><beat-type>4</beat-type></time>'
    '<clef><sign>G</sign><line>2</line></clef></attributes>'
    '${_note('C', 5)}${_note('D', 5)}${_note('E', 5)}${_note('F', 5)}'
    '</measure></part></score-partwise>';

XmlNoteRef _ref(int noteIndex) =>
    XmlNoteRef(partIndex: 0, measureIndex: 0, noteIndex: noteIndex);

/// The notes of the MIDI made for [xml]: (tick, key, velocity, length).
List<({int tick, int key, int velocity, int length})> _played(String xml) {
  final sequence = playbackMidi(
    xml,
    options: const nm.MidiGenerationOptions(
      defaultBpm: 120,
      includeMetronome: false,
    ),
  );
  final notes = <({int tick, int key, int velocity, int length})>[];
  for (final track in sequence.tracks) {
    final open = <int, nm.MidiEvent>{};
    for (final event in track.events) {
      final key = event.note;
      if (key == null) continue;
      final on =
          event.type == nm.MidiEventType.noteOn && (event.velocity ?? 0) > 0;
      if (on) {
        open[key] = event;
      } else if (open.remove(key) case final start?) {
        notes.add((
          tick: start.tick,
          key: key,
          velocity: start.velocity ?? 0,
          length: event.tick - start.tick,
        ));
      }
    }
  }
  return notes..sort((a, b) => a.tick.compareTo(b.tick));
}

/// What the editor writes is what the player plays: a mark that only showed
/// on the page would be a correction the ear cannot check.
void main() {
  test('a dynamic changes how loud the notes after it are', () {
    final soft = _editor.setDynamic(_score, _ref(0), 'pp').xml;
    final loud = _editor.setDynamic(soft, _ref(2), 'ff').xml;

    final notes = _played(loud);

    expect(notes, hasLength(4));
    expect(notes[0].velocity, lessThan(notes[2].velocity));
    expect(notes[1].velocity, notes[0].velocity);
    expect(notes[3].velocity, notes[2].velocity);
  });

  test('a staccato note is cut short and an accent is louder', () {
    final plain = _played(_score);
    final marked = _played(
      _editor
          .toggleArticulation(
            _editor.toggleArticulation(_score, _ref(0), 'staccato').xml,
            _ref(1),
            'accent',
          )
          .xml,
    );

    expect(marked[0].length, lessThan(plain[0].length));
    expect(marked[1].velocity, greaterThan(plain[1].velocity));
    expect(marked[2].length, plain[2].length);
  });

  test('notes under 8va sound an octave higher', () {
    final raised = _editor
        .addSpan(_score, _ref(1), _ref(2), SpanKind.octaveUp)
        .xml;

    expect(_played(raised).map((n) => n.key), [72, 86, 88, 77]);
  });

  test('a triplet plays three notes in the time of its beat', () {
    final triplet = _editor.makeTuplet(_score, _ref(1), 3, 2).xml;

    final notes = _played(triplet);
    final beat = notes[1].tick - notes[0].tick;

    expect(notes, hasLength(6));
    expect(notes[2].tick - notes[1].tick, closeTo(beat / 3, 1));
    expect(notes[4].tick - notes[1].tick, beat);
  });

  test('a tempo mark sets the speed of the bars after it', () {
    final marked = _editor.setTempo(_score, 0, 0, 60).xml;
    final sequence = playbackMidi(
      marked,
      options: const nm.MidiGenerationOptions(
        defaultBpm: 120,
        includeMetronome: false,
      ),
    );

    final tempos = [
      for (final track in sequence.tracks)
        for (final event in track.events)
          if (event.type == nm.MidiEventType.tempo) event.bpm,
    ];
    expect(tempos, contains(60));
  });
}
