import 'package:flutter_notemus/flutter_notemus.dart' as nm;
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_profile.dart';
import 'package:page_a_diddle/features/digital_score/domain/performance_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/digital_score/presentation/midi_duration.dart';

String _score(String measures, {int divisions = 4, String time = '4/4'}) {
  final beats = time.split('/');
  return '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0"><part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
<part id="P1">${measures.replaceFirst('<measure number="1">', '<measure number="1"><attributes><divisions>$divisions</divisions><time><beats>${beats[0]}</beats><beat-type>${beats[1]}</beat-type></time><staves>2</staves><clef number="1"><sign>G</sign><line>2</line></clef><clef number="2"><sign>F</sign><line>4</line></clef></attributes>')}</part></score-partwise>''';
}

String _note(
  String step,
  int octave,
  int duration,
  String type, {
  int voice = 1,
  int staff = 1,
  bool chord = false,
  String tie = '',
  String extra = '',
}) =>
    '<note>${chord ? '<chord/>' : ''}<pitch><step>$step</step><octave>$octave</octave></pitch>'
    '<duration>$duration</duration>${tie.split(',').where((t) => t.isNotEmpty).map((t) => '<tie type="$t"/>').join()}'
    '<voice>$voice</voice><type>$type</type>$extra<staff>$staff</staff></note>';

/// (quarter-note time, pitch) of every note struck, in time order.
List<(double, int)> _struck(String xml) {
  final midi = playbackMidi(
    xml,
    options: nm.MidiGenerationOptions(defaultBpm: 120, includeMetronome: false),
  );
  final ons = [
    for (final track in midi.tracks)
      for (final e in track.events)
        if (e.type == nm.MidiEventType.noteOn && (e.velocity ?? 0) > 0)
          (e.tick / midi.ticksPerQuarter, e.note!),
  ]..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
  return ons;
}

void main() {
  test('a left hand written in voice 5 on staff 2 is played', () {
    // Bar 2 has no attributes or direction: the mapper's reader used to drop
    // its left hand.
    final xml = _score(
      '<measure number="1">${_note('C', 5, 16, 'whole')}<backup><duration>16</duration></backup>${_note('C', 3, 16, 'whole', voice: 5, staff: 2)}</measure>'
      '<measure number="2">${_note('D', 5, 16, 'whole')}<backup><duration>16</duration></backup>${_note('D', 3, 16, 'whole', voice: 5, staff: 2)}</measure>',
    );

    expect(_struck(xml), [(0.0, 48), (0.0, 72), (4.0, 50), (4.0, 74)]);
  });

  test('a voice entering mid-bar sounds where it is written', () {
    // After <backup>, <forward> moves the second voice to beat 3.
    final xml = _score(
      '<measure number="1">${_note('C', 5, 16, 'whole')}<backup><duration>16</duration></backup>'
      '<forward><duration>8</duration></forward>${_note('E', 4, 8, 'half', voice: 2)}</measure>',
    );

    expect(_struck(xml), [(0.0, 72), (2.0, 64)]);
  });

  test('a bar longer than its time signature plays to its end', () {
    // 2/4 with four beats in each bar (a change of time the conversion
    // missed): the second bar starts after the first, not on top of it.
    final xml = _score(
      '<measure number="1">${_note('C', 5, 8, 'half')}${_note('D', 5, 8, 'half')}</measure>'
      '<measure number="2">${_note('E', 5, 8, 'half')}${_note('F', 5, 8, 'half')}</measure>',
      time: '2/4',
    );

    expect(_struck(xml), [(0.0, 72), (2.0, 74), (4.0, 76), (6.0, 77)]);
  });

  test('ties hold, whatever voices and chords they are written in', () {
    final xml = _score(
      // A chain of three; a chord with one tied and one new note; a tie into
      // another voice in the next bar.
      '<measure number="1">'
      '${_note('C', 5, 4, 'quarter', tie: 'start')}'
      '${_note('C', 5, 4, 'quarter', tie: 'stop,start')}'
      '${_note('C', 5, 4, 'quarter', tie: 'stop')}'
      '${_note('E', 5, 4, 'quarter', tie: 'start')}'
      '</measure>'
      '<measure number="2">'
      '${_note('E', 5, 8, 'half', tie: 'stop', voice: 2)}'
      '${_note('G', 5, 8, 'half', chord: true, voice: 2)}'
      '${_note('A', 5, 8, 'half', voice: 2)}'
      '</measure>',
    );

    expect(_struck(xml), [(0.0, 72), (3.0, 76), (4.0, 79), (6.0, 81)]);
  });

  test('a tie end with no note held into it is struck', () {
    final xml = _score(
      '<measure number="1">${_note('C', 5, 8, 'half')}${_note('D', 5, 8, 'half', tie: 'stop')}</measure>',
    );

    expect(_struck(xml), [(0.0, 72), (2.0, 74)]);
  });

  test('a duplet starting with a rest keeps its place', () {
    // 9/8: a duplet (two in the time of three eighths), then a dotted quarter.
    const duplet =
        '<time-modification><actual-notes>2</actual-notes><normal-notes>3</normal-notes></time-modification>';
    final xml = _score(
      '<measure number="1">'
      '<note><rest/><duration>3</duration><voice>1</voice><type>eighth</type>$duplet<staff>1</staff><notations><tuplet type="start"/></notations></note>'
      '${_note('F', 5, 3, 'eighth', extra: duplet)}'
      '${_note('G', 5, 6, 'quarter', extra: '<dot/>')}'
      '${_note('A', 5, 6, 'quarter', extra: '<dot/>')}'
      '</measure>',
      time: '9/8',
    );

    expect(_struck(xml), [(0.75, 77), (1.5, 79), (3.0, 81)]);
  });

  test('the background build gives the same MIDI as the direct one', () async {
    final xml = _score(
      '<measure number="1">${_note('C', 5, 8, 'half', tie: 'start')}${_note('C', 5, 8, 'half', tie: 'stop')}'
      '<barline location="right"><repeat direction="backward"/></barline></measure>'
      '<measure number="2">${_note('D', 5, 16, 'whole')}</measure>',
    );
    final score = const MusicXmlCodec().decodeXml(xml);
    List<(int, int)> ons(nm.MidiSequence midi) => [
      for (final track in midi.tracks)
        for (final e in track.events)
          if (e.type == nm.MidiEventType.noteOn && (e.velocity ?? 0) > 0)
            (e.tick, e.note!),
    ];

    final direct = buildPlaybackMidi(
      engravingXml: xml,
      score: score,
      sequence: PlaybackSequence.empty,
      arrangement: ArrangementProfile.off,
      bpm: 120,
    );
    final background = await buildPlaybackMidiInBackground(
      engravingXml: xml,
      score: score,
      sequence: PlaybackSequence.empty,
      arrangement: ArrangementProfile.off,
      bpm: 120,
    );

    // The repeat is played out: C (held), C (held), D.
    final quarter = direct.sequence.ticksPerQuarter;
    expect(ons(direct.sequence), [
      (0, 72),
      (4 * quarter, 72),
      (8 * quarter, 74),
    ]);
    expect(ons(background.sequence), ons(direct.sequence));
    expect(background.programs, direct.programs);
    expect(background.levels, {0: 1.0});
    expect(direct.programs, {0: 0});
    // One part: nothing is turned down.
    expect(staffLevels(xml), [1.0, 1.0]);
  });

  test('each staff plays the instrument its part names', () {
    // A voice without an instrument, strings on two staves, brass on one.
    const xml =
        '<score-partwise version="4.0"><part-list>'
        '<score-part id="P1"><part-name>Voice</part-name></score-part>'
        '<score-part id="P2"><part-name>Strings</part-name><midi-instrument id="P2-I1">'
        '<midi-channel>2</midi-channel><midi-program>49</midi-program></midi-instrument></score-part>'
        '<score-part id="P3"><part-name>Brass</part-name><midi-instrument id="P3-I1">'
        '<midi-program>62</midi-program></midi-instrument></score-part>'
        '</part-list>'
        '<part id="P1"><measure number="1"><attributes><divisions>1</divisions></attributes>'
        '<note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration><voice>1</voice><type>whole</type></note></measure></part>'
        '<part id="P2"><measure number="1"><attributes><divisions>1</divisions><staves>2</staves></attributes>'
        '<note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>whole</type><staff>1</staff></note>'
        '<backup><duration>4</duration></backup>'
        '<note><pitch><step>C</step><octave>3</octave></pitch><duration>4</duration><voice>5</voice><type>whole</type><staff>2</staff></note></measure></part>'
        '<part id="P3"><measure number="1"><attributes><divisions>1</divisions></attributes>'
        '<note><pitch><step>G</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>whole</type></note></measure></part>'
        '</score-partwise>';

    expect(staffPrograms(xml), [0, 48, 48, 61]);
    // A part marked as sung plays on the piano.
    expect(
      staffPrograms(
        xml.replaceFirst(
          '<part-name>Voice</part-name>',
          '<part-name>Voice</part-name><midi-instrument id="P1-I1">'
              '<midi-program>54</midi-program></midi-instrument>',
        ),
      ),
      [0, 48, 48, 61],
    );
    final midi = playbackMidi(
      xml,
      options: nm.MidiGenerationOptions(
        defaultBpm: 120,
        includeMetronome: false,
      ),
    );
    expect(channelPrograms(midi, xml), {0: 0, 1: 48, 2: 48, 3: 61});
    // The exported file names the instruments too.
    final file = playbackMidiFile(
      PlaybackMidi(midi, channelPrograms(midi, xml), const {}),
    );
    expect(String.fromCharCodes(file.sublist(0, 4)), 'MThd');
    final changes = <int, int>{};
    for (var i = 0; i + 1 < file.length; i++) {
      // Program change: status 0xC0 | channel, then the program.
      if (file[i] & 0xF0 == 0xC0 && file[i - 1] == 0) {
        changes[file[i] & 0x0F] = file[i + 1];
      }
    }
    expect(changes, {0: 0, 1: 48, 2: 48, 3: 61});
    // The voice leads; held strings are quieter than the brass hits.
    expect(staffLevels(xml), [1.0, 0.22, 0.22, 0.35]);
    expect(channelLevels(midi, xml), {0: 1.0, 1: 0.22, 2: 0.22, 3: 0.35});
  });

  test('the copy for the player leaves a plain score as it is', () {
    final xml = _score(
      '<measure number="1">${_note('C', 5, 16, 'whole')}</measure>',
    );

    expect(midiReadyMusicXml(xml), xml);
    expect(withoutTies(xml), xml);
  });
}
