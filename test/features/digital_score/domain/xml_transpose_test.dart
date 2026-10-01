import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_transpose.dart';
import 'package:page_a_diddle/features/digital_score/domain/xml_transpose.dart';

// G major. Bar 1: D, F# (in the key), F natural (written), a triplet with a
// lyric, C# tied into bar 2. Bar 2 starts a new line; chords G and D/F#.
const _xml = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Voice</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>6</divisions><key><fifths>1</fifths></key><time><beats>4</beats><beat-type>4</beat-type></time><clef><sign>G</sign><line>2</line></clef></attributes>
      <harmony><root><root-step>G</root-step></root><kind>major</kind></harmony>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>6</duration><voice>1</voice><type>quarter</type><lyric number="1"><text>가</text></lyric></note>
      <note><pitch><step>F</step><alter>1</alter><octave>4</octave></pitch><duration>6</duration><voice>1</voice><type>quarter</type></note>
      <note><pitch><step>F</step><octave>4</octave></pitch><duration>2</duration><voice>1</voice><type>eighth</type><accidental>natural</accidental><time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes></time-modification><notations><tuplet type="start"/></notations></note>
      <note><pitch><step>G</step><octave>4</octave></pitch><duration>2</duration><voice>1</voice><type>eighth</type><time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes></time-modification></note>
      <note><pitch><step>A</step><octave>4</octave></pitch><duration>2</duration><voice>1</voice><type>eighth</type><time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes></time-modification><notations><tuplet type="stop"/></notations></note>
      <note><pitch><step>C</step><alter>1</alter><octave>5</octave></pitch><duration>6</duration><tie type="start"/><voice>1</voice><type>quarter</type><accidental>sharp</accidental><notations><tied type="start"/></notations></note>
    </measure>
    <measure number="2">
      <print new-system="yes"/>
      <harmony><root><root-step>D</root-step></root><kind>major</kind><bass><bass-step>F</bass-step><bass-alter>1</bass-alter></bass></harmony>
      <note><pitch><step>C</step><alter>1</alter><octave>5</octave></pitch><duration>6</duration><tie type="stop"/><voice>1</voice><type>quarter</type><notations><tied type="stop"/></notations></note>
      <note><rest/><duration>18</duration><voice>1</voice><type>half</type><dot/></note>
    </measure>
  </part>
</score-partwise>
''';

int _count(String xml, String tag) =>
    RegExp('<$tag[\\s>/]').allMatches(xml).length;

void main() {
  const codec = MusicXmlCodec();

  test('moves pitches, key and chords like the model, keeps the rest', () {
    final out = transposeMusicXml(_xml, semitones: 2, fifthsDelta: 2);
    final score = codec.decodeXml(out);
    final model = transposeScore(
      codec.decodeXml(_xml),
      semitones: 2,
      fifthsDelta: 2,
    );

    String spell(MusicScore s) => [
      for (final m in s.parts.first.measures) ...[
        'k${m.attributes.keyFifths}',
        for (final e in m.events)
          switch (e) {
            MusicNote(:final pitch?) =>
              '${pitch.step.name}${pitch.alter}${pitch.octave}',
            MusicHarmony h =>
              '${h.rootStep.name}${h.rootAlter}/${h.bassStep?.name}${h.bassAlter}',
            _ => '',
          },
      ],
    ].join(' ');
    expect(spell(score), spell(model));
    expect(spell(score), 'k3 a0/null0 e04 g14 g04 a04 b04 d15 k3 e0/g1 d15 ');
    // Nothing else moved: the lyric, the triplet, the tie and the line break.
    for (final tag in [
      'lyric',
      'time-modification',
      'tuplet',
      'tie',
      'tied',
      'print',
      'dot',
      'rest',
    ]) {
      expect(_count(out, tag), _count(_xml, tag), reason: tag);
    }
    expect(out, contains('<text>가</text>'));
  });

  test('writes the accidentals the new spelling needs', () {
    final out = transposeMusicXml(_xml, semitones: 2, fifthsDelta: 2);
    final accidentals = RegExp(
      r'<accidental>([a-z-]+)</accidental>',
    ).allMatches(out).map((m) => m.group(1)).toList();
    // G# is in A major: no sign. G natural keeps its (now needed) natural.
    // D# needs a sharp; tied into bar 2 it is not written again.
    expect(accidentals, ['natural', 'sharp']);
    final bar2 = out.substring(out.indexOf('<measure number="2">'));
    expect(bar2, isNot(contains('<accidental>')));
  });

  test('a key past seven sharps wraps to flats, chords stay simple', () {
    const xml =
        '''<?xml version="1.0"?><score-partwise version="4.0"><part-list><score-part id="P1"><part-name>V</part-name></score-part></part-list><part id="P1"><measure number="1"><attributes><divisions>1</divisions><key><fifths>6</fifths></key></attributes><harmony><root><root-step>B</root-step></root><kind>major</kind></harmony><note><pitch><step>A</step><alter>1</alter><octave>4</octave></pitch><duration>4</duration><type>whole</type></note></measure></part></score-partwise>''';
    // F# major up a whole tone: G# major (8 sharps) is written as A flat.
    final out = transposeMusicXml(xml, semitones: 2, fifthsDelta: 2);
    final score = codec.decodeXml(out);
    final bar = score.parts.first.measures.single;
    expect(bar.attributes.keyFifths, -4);
    final chord = bar.events.whereType<MusicHarmony>().single;
    // B up a tone, spelled in A flat: D flat.
    expect((chord.rootStep, chord.rootAlter), (PitchStep.d, -1));
    final note = bar.notes.single.pitch!;
    expect(note.midi, 72);
  });

  group('what is drawn reads as what sounds', () {
    String part(String measures) =>
        '<score-partwise version="4.0"><part-list><score-part id="P1"><part-name>V</part-name></score-part></part-list><part id="P1">$measures</part></score-partwise>';
    String note(String step, {int alter = 0, String extra = ''}) =>
        '<note><pitch><step>$step</step>${alter == 0 ? '' : '<alter>$alter</alter>'}<octave>4</octave></pitch><duration>1</duration>$extra<type>quarter</type></note>';
    List<String> keys(String xml) => [
      for (final m in RegExp(r'<fifths>(-?\d+)</fifths>').allMatches(xml))
        m.group(1)!,
    ];

    test('a score without a key signature gets one', () {
      // C major with no <key>: up a tone the E becomes F#, which only the
      // new signature shows.
      final xml = part(
        '<measure number="1"><attributes><divisions>1</divisions><time><beats>4</beats><beat-type>4</beat-type></time></attributes>'
        '${note('C')}${note('E')}</measure>',
      );

      final out = transposeMusicXml(xml, semitones: 2, fifthsDelta: 2);

      expect(out, contains('<divisions>1</divisions><key><fifths>2</fifths>'));
      expect(
        codec.decodeXml(out).parts.first.measures.first.attributes.keyFifths,
        2,
      );
      expect(_count(out, 'accidental'), 0);
    });

    test('a key overridden at the start of a bar is dropped', () {
      // Two keys before the first note: the second one counts, but an
      // engraver may draw the first.
      final xml = part(
        '<measure number="1"><attributes><divisions>1</divisions><key><fifths>0</fifths></key></attributes>'
        '<attributes><key><fifths>1</fifths></key></attributes>${note('F', alter: 1)}</measure>',
      );

      final out = transposeMusicXml(xml, semitones: 1, fifthsDelta: 7);

      expect(keys(out), ['-4']);
      expect(out, contains('<step>G</step>'));
      expect(_count(out, 'accidental'), 0);
    });

    test('a piece that changes key stays in flats or in sharps', () {
      // G then C, up a semitone: A flat then D flat, not C sharp.
      final xml = part(
        '<measure number="1"><attributes><divisions>1</divisions><key><fifths>1</fifths></key></attributes>${note('G')}</measure>'
        '<measure number="2"><attributes><key><fifths>0</fifths></key></attributes>${note('C')}</measure>',
      );

      final out = transposeMusicXml(xml, semitones: 1, fifthsDelta: 7);

      expect(keys(out), ['-4', '-5']);
      expect(out, contains('<step>D</step><alter>-1</alter>'));
    });

    test('a key change in the middle of a bar applies from there', () {
      final xml = part(
        '<measure number="1"><attributes><divisions>1</divisions><key><fifths>0</fifths></key></attributes>${note('F')}'
        '<attributes><key><fifths>1</fifths></key></attributes>${note('F', alter: 1)}</measure>',
      );

      final out = transposeMusicXml(xml, semitones: 2, fifthsDelta: 2);

      // D major then A major: G natural, then G sharp from the new key.
      expect(keys(out), ['2', '3']);
      expect(_count(out, 'accidental'), 0);
    });

    test('an accidental tied over the barline is written again after it', () {
      // C major: F# tied into bar 2, then another F#.
      final xml = part(
        '<measure number="1"><attributes><divisions>1</divisions><key><fifths>0</fifths></key></attributes>'
        '${note('F', alter: 1, extra: '<tie type="start"/>')}</measure>'
        '<measure number="2">${note('F', alter: 1, extra: '<tie type="stop"/>')}${note('F', alter: 1)}</measure>',
      );

      final out = transposeMusicXml(xml, semitones: 12, fifthsDelta: 0);

      final second = RegExp(
        r'<measure number="2">(.*)</measure>',
      ).firstMatch(out)!.group(1)!;
      final notes = second.split('</note>');
      expect(notes[0], isNot(contains('<accidental>')));
      expect(notes[1], contains('<accidental>sharp</accidental>'));
    });
  });

  test('no-op interval returns the file unchanged', () {
    expect(transposeMusicXml(_xml, semitones: 0, fifthsDelta: 0), _xml);
  });
}
