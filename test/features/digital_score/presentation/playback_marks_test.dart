import 'package:flutter_notemus/flutter_notemus.dart' as nm;
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_profile.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
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

  group('a hairpin is heard', () {
    test('under a crescendo every note is louder than the one before', () {
      final xml = _editor
          .addSpan(_score, _ref(0), _ref(3), SpanKind.crescendo)
          .xml;

      final plain = _played(_score);
      final notes = _played(xml);

      expect(notes[0].velocity, plain[0].velocity);
      for (var i = 1; i < 4; i++) {
        expect(notes[i].velocity, greaterThan(notes[i - 1].velocity));
      }
      // About a mark louder by its end, not a jump to the loudest: the
      // last note, three quarters along, is most of the way there.
      expect(
        notes[3].velocity / plain[3].velocity,
        inInclusiveRange(1.15, 1.3),
      );
      // Only how loud: when and how long stay as written.
      expect(
        [for (final note in notes) (note.tick, note.key, note.length)],
        [for (final note in plain) (note.tick, note.key, note.length)],
      );
    });

    test('a diminuendo goes down to the mark that follows it', () {
      final loud = _editor.setDynamic(_score, _ref(0), 'ff').xml;
      final soft = _editor.setDynamic(loud, _ref(3), 'pp').xml;
      final marked = _played(soft);
      final xml = _editor
          .addSpan(soft, _ref(0), _ref(3), SpanKind.diminuendo)
          .xml;

      final notes = _played(xml);

      // From ff down to pp, step by step; the marks stay what they were.
      expect(notes[0].velocity, marked[0].velocity);
      expect(notes[3].velocity, marked[3].velocity);
      expect(notes[1].velocity, lessThan(notes[0].velocity));
      expect(notes[2].velocity, lessThan(notes[1].velocity));
      expect(notes[2].velocity, greaterThan(notes[3].velocity));
    });

    test('what a hairpin reached holds until the next dynamic mark', () {
      // Two bars: a crescendo over the first two notes, mf on the last
      // note of the second bar.
      final two = _score.replaceFirst(
        '</measure>',
        '</measure><measure number="2">'
            '${_note('C', 5)}${_note('D', 5)}${_note('E', 5)}${_note('F', 5)}'
            '</measure>',
      );
      XmlNoteRef second(int note) =>
          XmlNoteRef(partIndex: 0, measureIndex: 1, noteIndex: note);
      final swelled = _editor
          .addSpan(two, _ref(0), _ref(1), SpanKind.crescendo)
          .xml;
      final xml = _editor.setDynamic(swelled, second(3), 'mf').xml;

      final plain = _played(two);
      final notes = _played(xml);

      expect(notes, hasLength(8));
      // Louder than written from the end of the hairpin on…
      for (var i = 2; i < 7; i++) {
        expect(notes[i].velocity, greaterThan(plain[i].velocity), reason: '$i');
        expect(notes[i].velocity, notes[2].velocity, reason: '$i');
      }
      // …until the mark, which is played as it says.
      final marked = _played(_editor.setDynamic(two, second(3), 'mf').xml);
      expect(notes[7].velocity, marked[7].velocity);
    });
  });

  group('what the score says of its tempo is heard', () {
    // Four bars of four quarters.
    final four = _score.replaceFirst(
      '</measure>',
      '</measure>${[for (var i = 2; i <= 4; i++) '<measure number="$i">'
            '${_note('C', 5)}${_note('D', 5)}${_note('E', 5)}${_note('F', 5)}'
            '</measure>'].join()}',
    );
    nm.MidiSequence midi(String xml) => playbackMidi(
      xml,
      options: const nm.MidiGenerationOptions(
        defaultBpm: 120,
        includeMetronome: false,
      ),
    );
    double msOfBar(String xml, int bar) {
      final sequence = midi(xml);
      final timing = MidiTiming(sequence, fallbackBpm: 120);
      final tpq = sequence.ticksPerQuarter;
      return timing.msAt((bar + 1) * 4 * tpq) - timing.msAt(bar * 4 * tpq);
    }

    test('a ritardando makes its bars longer, beat by beat', () {
      final xml = _editor.addWords(four, 0, 1, 'rit.').xml;

      // Two seconds a bar as written.
      expect(msOfBar(four, 1), closeTo(2000, 1));
      expect(msOfBar(xml, 0), closeTo(2000, 1));
      // It holds for two bars: each slower than the one before.
      expect(msOfBar(xml, 1), greaterThan(2100));
      expect(msOfBar(xml, 2), greaterThan(msOfBar(xml, 1)));
      // Then the score goes on as it was written.
      expect(msOfBar(xml, 3), closeTo(2000, 1));
    });

    test('"a tempo" ends it, and an accelerando goes the other way', () {
      final slowed = _editor.addWords(four, 0, 1, 'ritardando').xml;
      final back = _editor.addWords(slowed, 0, 2, 'a tempo').xml;
      expect(msOfBar(back, 1), greaterThan(2100));
      expect(msOfBar(back, 2), closeTo(2000, 1));

      final faster = _editor.addWords(four, 0, 1, 'accel.').xml;
      expect(msOfBar(faster, 1), lessThan(1950));
      expect(msOfBar(faster, 2), lessThan(msOfBar(faster, 1)));
      // Words that say nothing of the tempo change nothing.
      expect(
        msOfBar(_editor.addWords(four, 0, 1, 'with feeling').xml, 1),
        closeTo(2000, 1),
      );
    });

    test('a note under a fermata is held twice as long', () {
      final xml = _editor
          .toggleArticulation(
            four,
            XmlNoteRef(partIndex: 0, measureIndex: 1, noteIndex: 3),
            'fermata',
          )
          .xml;

      // The last beat of bar 2 lasts two: the bar is a beat longer.
      expect(msOfBar(xml, 1), closeTo(2500, 2));
      // An angled fermata is a short hold, a square one a long hold.
      final at = XmlNoteRef(partIndex: 0, measureIndex: 1, noteIndex: 3);
      expect(
        msOfBar(_editor.setFermataShape(xml, at, 'angled').xml, 1),
        closeTo(2250, 2),
      );
      expect(
        msOfBar(_editor.setFermataShape(xml, at, 'square').xml, 1),
        closeTo(3000, 2),
      );
      expect(msOfBar(xml, 0), closeTo(2000, 1));
      expect(msOfBar(xml, 2), closeTo(2000, 1));
    });

    test('under "Swing" the eighth between two beats comes late', () {
      String eighth(String step) =>
          '<note><pitch><step>$step</step><octave>5</octave></pitch>'
          '<duration>1</duration><voice>1</voice><type>eighth</type></note>';
      final eighths =
          '<?xml version="1.0" encoding="UTF-8"?>'
          '<score-partwise version="4.0"><part-list>'
          '<score-part id="P1"><part-name>Voice</part-name></score-part>'
          '</part-list><part id="P1">'
          '${[
            for (var bar = 1; bar <= 2; bar++) '<measure number="$bar">'
                  '${bar == 1 ? '<attributes><divisions>2</divisions><key><fifths>0</fifths></key>'
                            '<time><beats>4</beats><beat-type>4</beat-type></time>'
                            '<clef><sign>G</sign><line>2</line></clef></attributes>' : ''}'
                  '${[for (final step in 'CDEFGABC'.split('')) eighth(step)].join()}'
                  '</measure>',
          ].join()}'
          '</part></score-partwise>';
      final swung = _editor.addWords(eighths, 0, 0, 'Swing').xml;
      final straightAgain = _editor.addWords(swung, 0, 1, 'Straight').xml;

      final plain = _played(eighths);
      final notes = _played(straightAgain);
      final tpq = midi(eighths).ticksPerQuarter;

      expect(notes, hasLength(16));
      for (var i = 0; i < 8; i++) {
        // On the beat as written; between the beats two thirds along.
        expect(
          notes[i].tick,
          i.isEven ? plain[i].tick : (i ~/ 2) * tpq + tpq * 2 ~/ 3,
          reason: 'note $i',
        );
      }
      // The note on the beat lasts up to the late one.
      expect(notes[0].length, greaterThan(plain[0].length));
      // From "Straight" on, as written.
      for (var i = 8; i < 16; i++) {
        expect(notes[i].tick, plain[i].tick, reason: 'note $i');
      }
    });
  });

  test('a part goes on with another instrument from the bar that says so', () {
    final two = _score.replaceFirst(
      '</measure>',
      '</measure><measure number="2">'
          '${_note('C', 5)}${_note('D', 5)}${_note('E', 5)}${_note('F', 5)}'
          '</measure>',
    );
    final xml = _editor.setInstrumentChange(two, 0, 1, (
      name: 'Strings',
      program: 48,
    )).xml;
    expect(_editor.barSigns(xml, 0, 1).instrument, 'Strings');
    expect(_editor.barSigns(xml, 0, 0).instrument, isNull);

    final midi = buildPlaybackMidi(
      engravingXml: xml,
      score: const MusicXmlCodec().decodeXml(xml),
      sequence: PlaybackSequence.empty,
      arrangement: ArrangementProfile.off,
      bpm: 120,
    );
    final tpq = midi.sequence.ticksPerQuarter;
    final notes = [
      for (final track in midi.sequence.tracks)
        for (final event in track.events)
          if (event.type == nm.MidiEventType.noteOn &&
              (event.velocity ?? 0) > 0)
            event,
    ]..sort((a, b) => a.tick.compareTo(b.tick));

    expect(notes, hasLength(8));
    final before = notes.first.channel;
    final after = notes.last.channel;
    // The first bar on the part's own channel, the second on another.
    expect(notes.take(4).map((e) => e.channel).toSet(), {before});
    expect(notes.skip(4).map((e) => e.channel).toSet(), {after});
    expect(after, isNot(before));
    expect(notes[4].tick, 4 * tpq);
    expect(midi.programs[before], 0);
    expect(midi.programs[after], 48);
    // Every note ends on the channel it began on.
    for (final track in midi.sequence.tracks) {
      final open = <(int, int)>{};
      for (final event in track.events) {
        final note = event.note;
        if (note == null) continue;
        if (event.type == nm.MidiEventType.noteOn &&
            (event.velocity ?? 0) > 0) {
          open.add((event.channel, note));
        } else {
          expect(open.remove((event.channel, note)), isTrue);
        }
      }
      expect(open, isEmpty);
    }

    // "Strings" over the bar is a name, not a word to play faster by.
    final timing = MidiTiming(midi.sequence, fallbackBpm: 120);
    expect(timing.msAt(8 * tpq) - timing.msAt(4 * tpq), closeTo(2000, 1));

    // The change is taken away again.
    final plain = _editor.setInstrumentChange(xml, 0, 1, null).xml;
    expect(plain, isNot(contains('<midi-instrument')));
  });

  test('a mixer: levels, parts made silent, parts heard alone', () {
    expect(mixedLevels(3), [1.0, 1.0, 1.0]);
    expect(mixedLevels(3, levels: {1: 0.5}, muted: {2}), [1.0, 0.5, 0.0]);
    // A part heard alone silences the others, whatever their levels.
    expect(mixedLevels(3, levels: {0: 0.8, 1: 0.5}, solo: {1}), [
      0.0,
      0.5,
      0.0,
    ]);
    // Silent wins over alone.
    expect(mixedLevels(2, muted: {0}, solo: {0}), [0.0, 0.0]);

    // Every channel of the sequence belongs to the part that plays it.
    final score = const MusicXmlCodec().decodeXml(_score);
    final sequence = playbackMidi(
      _score,
      options: const nm.MidiGenerationOptions(
        defaultBpm: 120,
        includeMetronome: false,
      ),
    );
    expect(channelParts(sequence, score).values.toSet(), {0});
  });

  test('a tacet note is written and not played', () {
    final xml = _editor.toggleTacet(_score, _ref(1)).xml;
    expect(_editor.describe(xml, _ref(1)).tacet, isTrue);
    expect(xml, contains('<play><mute>on</mute></play>'));

    final plain = _played(_score);
    final notes = _played(xml);

    // D is passed over; the others sound when and as they did.
    expect(notes, hasLength(3));
    expect(
      [for (final note in notes) (note.tick, note.key)],
      [
        for (final (index, note) in plain.indexed)
          if (index != 1) (note.tick, note.key),
      ],
    );
    final again = _editor.toggleTacet(xml, _ref(1)).xml;
    expect(again, isNot(contains('<play>')));
    expect(_played(again), hasLength(4));
  });

  test('the metronome clicks on every beat, higher on the first of a bar', () {
    final sequence = playbackMidi(
      _score,
      options: const nm.MidiGenerationOptions(
        defaultBpm: 120,
        includeMetronome: false,
      ),
    );
    final tpq = sequence.ticksPerQuarter;

    // Two bars of four beats, then one of 6/8 with two beats.
    final clicked = withMetronomeClicks(
      nm.MidiSequence(
        ticksPerQuarter: tpq,
        tracks: [
          nm.MidiTrack(
            name: 'Voice',
            channel: 0,
            events: [
              const nm.MidiEvent.noteOn(
                tick: 0,
                channel: 0,
                note: 60,
                velocity: 80,
              ),
              nm.MidiEvent.noteOff(tick: tpq * 11, channel: 0, note: 60),
            ],
          ),
        ],
      ),
      const [
        (quarters: 4, beat: 1),
        (quarters: 4, beat: 1),
        (quarters: 3, beat: 1.5),
      ],
    );

    final clicks = [
      for (final event in clicked.tracks.last.events)
        if (event.type == nm.MidiEventType.noteOn)
          (event.tick ~/ (tpq ~/ 2), event.note),
    ];
    expect(clicked.tracks, hasLength(2));
    expect(clicked.tracks.last.channel, metronomeChannel);
    // In half beats: bar 1 at 0, bar 2 at 8, bar 3 at 16 and its second
    // beat three eighths on.
    expect(clicks, [
      (0, 88),
      (2, 81),
      (4, 81),
      (6, 81),
      (8, 88),
      (10, 81),
      (12, 81),
      (14, 81),
      (16, 88),
      (19, 81),
    ]);
    // The music itself is as it was.
    expect(clicked.tracks.first.events, hasLength(2));
  });
}
