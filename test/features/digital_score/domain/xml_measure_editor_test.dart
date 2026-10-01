import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/xml_measure_editor.dart';
import 'package:xml/xml.dart';

const _editor = XmlMeasureEditor();
const _codec = MusicXmlCodec();

String _note(
  String step,
  int octave, {
  int alter = 0,
  int duration = 1,
  String type = 'quarter',
  String voice = '1',
  int staff = 1,
  String extra = '',
  String beam = '',
  String accidental = '',
  bool chord = false,
}) => '''
<note>${chord ? '<chord/>' : ''}<pitch><step>$step</step>${alter == 0 ? '' : '<alter>$alter</alter>'}<octave>$octave</octave></pitch><duration>$duration</duration>$extra<voice>$voice</voice><type>$type</type>${accidental.isEmpty ? '' : '<accidental>$accidental</accidental>'}<staff>$staff</staff>$beam</note>''';

String _rest({
  int duration = 1,
  String type = 'quarter',
  String voice = '1',
  int staff = 1,
}) =>
    '<note><rest/><duration>$duration</duration><voice>$voice</voice><type>$type</type><staff>$staff</staff></note>';

String _score(
  List<String> measures, {
  int divisions = 1,
  int fifths = 1,
  int staves = 2,
}) {
  final buffer = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<score-partwise version="4.0"><part-list>'
    '<score-part id="P1"><part-name>Piano</part-name></score-part>'
    '</part-list><part id="P1">',
  );
  for (var i = 0; i < measures.length; i++) {
    buffer.write('<measure number="${i + 1}">');
    if (i == 0) {
      buffer.write(
        '<attributes><divisions>$divisions</divisions>'
        '<key><fifths>$fifths</fifths></key>'
        '<time><beats>4</beats><beat-type>4</beat-type></time>'
        '<staves>$staves</staves>'
        '<clef number="1"><sign>G</sign><line>2</line></clef>'
        '${staves > 1 ? '<clef number="2"><sign>F</sign><line>4</line></clef>' : ''}'
        '</attributes>',
      );
    }
    buffer.write(measures[i]);
    buffer.write('</measure>');
  }
  buffer.write('</part></score-partwise>');
  return buffer.toString();
}

const _bass =
    '<backup><duration>4</duration></backup>'
    '<note><pitch><step>G</step><octave>2</octave></pitch><duration>4</duration>'
    '<voice>5</voice><type>whole</type><staff>2</staff></note>';

XmlNoteRef _ref(int noteIndex, {int measureIndex = 0}) =>
    XmlNoteRef(partIndex: 0, measureIndex: measureIndex, noteIndex: noteIndex);

List<XmlElement> _notes(String xml, {int measureIndex = 0}) =>
    XmlDocument.parse(xml)
        .findAllElements('measure')
        .elementAt(measureIndex)
        .findElements('note')
        .toList();

String? _pitchOf(XmlElement note) {
  final pitch = note.getElement('pitch');
  if (pitch == null) return null;
  final alter = pitch.getElement('alter')?.innerText ?? '0';
  return '${pitch.getElement('step')!.innerText}:$alter:'
      '${pitch.getElement('octave')!.innerText}';
}

List<String> _beams(String xml, {int measureIndex = 0}) => [
  for (final note in _notes(xml, measureIndex: measureIndex))
    note.findElements('beam').map((b) => b.innerText).join('+'),
];

/// Onset and duration of each note in a voice after decoding.
List<(int, int)> _timeline(String xml, String voice) {
  final score = _codec.decodeXml(xml);
  return [
    for (final note in score.parts.first.measures.first.notes)
      if (note.voice == voice && !note.isChord) (note.onset, note.duration),
  ];
}

void main() {
  group('pitch', () {
    test('moves a note one staff step using the key signature', () {
      final xml = _score([
        '<direction placement="below"><direction-type><dynamics><p/></dynamics>'
            '</direction-type><staff>1</staff></direction>'
            '${_note('E', 5, extra: '', beam: '<notations><slur type="start" number="1"/></notations><lyric><text>la</text></lyric>')}'
            '${_note('D', 5)}${_note('C', 5)}${_note('B', 4)}$_bass',
      ]);

      final result = _editor.moveDiatonic(xml, _ref(0), 1);
      final note = _notes(result.xml).first;

      expect(_pitchOf(note), 'F:1:5');
      expect(note.getElement('accidental'), isNull);
      expect(result.xml, contains('<dynamics><p/></dynamics>'));
      expect(note.findAllElements('slur'), hasLength(1));
      expect(note.getElement('lyric')?.innerText, 'la');
      _codec.decodeXml(result.xml);
    });

    test('uses an earlier accidental in the bar as the context', () {
      final xml = _score([
        '${_note('F', 5, accidental: 'natural')}${_note('E', 5)}'
            '${_note('C', 5)}${_note('B', 4)}$_bass',
      ]);

      final result = _editor.moveDiatonic(xml, _ref(1), 1);
      final note = _notes(result.xml)[1];

      expect(_pitchOf(note), 'F:0:5');
      expect(note.getElement('accidental'), isNull);
    });

    test('shows a natural and restores the sharp on a later note', () {
      final xml = _score([
        '${_note('F', 5, alter: 1)}${_note('F', 5, alter: 1)}'
            '${_note('C', 5)}${_note('B', 4)}$_bass',
      ]);

      final result = _editor.setAlter(xml, _ref(0), 0);
      final notes = _notes(result.xml);

      expect(_pitchOf(notes[0]), 'F:0:5');
      expect(notes[0].getElement('accidental')?.innerText, 'natural');
      expect(notes[1].getElement('accidental')?.innerText, 'sharp');
    });

    test('keeps tied notes on the same pitch across the barline', () {
      final tieStart = '<tie type="start"/>';
      final xml = _score([
        '${_note('C', 5, duration: 3, type: 'half', extra: tieStart)}'
            '${_note('A', 5, duration: 1, type: 'quarter', extra: tieStart)}$_bass',
        '${_note('A', 5, extra: '<tie type="stop"/>')}${_note('G', 5, duration: 3, type: 'half')}'
            '$_bass',
      ]).replaceFirst('<type>half</type>', '<type>half</type><dot/>');

      final result = _editor.moveDiatonic(xml, _ref(1), -1);

      expect(_pitchOf(_notes(result.xml)[1]), 'G:0:5');
      expect(_pitchOf(_notes(result.xml, measureIndex: 1).first), 'G:0:5');
      expect(
        _notes(result.xml, measureIndex: 1).first.getElement('accidental'),
        isNull,
      );
    });

    test('shifts an octave and refuses rests', () {
      final xml = _score([
        '${_note('B', 4, duration: 4, type: 'whole')}$_bass',
      ]);

      expect(
        _pitchOf(_notes(_editor.shiftOctave(xml, _ref(0), 1).xml).first),
        'B:0:5',
      );
      final rest = _score(['${_rest(duration: 4, type: 'whole')}$_bass']);
      expect(
        () => _editor.moveDiatonic(rest, _ref(0), 1),
        throwsFormatException,
      );
    });
  });

  group('chords', () {
    test('adds a third above the top note as a chord member', () {
      final xml = _score([
        '${_note('C', 5)}${_note('E', 5, chord: true)}'
            '${_note('D', 5)}${_note('C', 5)}${_note('B', 4)}$_bass',
      ]);

      final result = _editor.addChordNote(xml, _ref(0));
      final notes = _notes(result.xml);

      expect(result.selection.noteIndex, 2);
      expect(_pitchOf(notes[2]), 'G:0:5');
      expect(notes[2].getElement('chord'), isNotNull);
      final decoded = _codec.decodeXml(result.xml);
      final first = decoded.parts.first.measures.first.notes.take(3);
      expect(first.map((n) => n.onset).toSet(), {0});
    });

    test('removing a chord head promotes the next member', () {
      final xml =
          _score(
                [
                      '${_note('C', 5, beam: '<beam number="1">begin</beam>', duration: 1, type: 'eighth')}'
                          '${_note('E', 5, chord: true, type: 'eighth')}'
                          '${_note('D', 5, beam: '<beam number="1">end</beam>', type: 'eighth')}'
                          '${_rest(duration: 3, type: 'half')}$_bass',
                    ]
                    .map(
                      (m) => m.replaceAll(
                        '<duration>1</duration>',
                        '<duration>1</duration>',
                      ),
                    )
                    .toList(),
                divisions: 2,
              )
              .replaceAll(
                '<rest/><duration>3</duration>',
                '<rest/><duration>6</duration>',
              )
              .replaceAll(
                '<backup><duration>4</duration>',
                '<backup><duration>8</duration>',
              )
              .replaceAll('<duration>4</duration>\n', '');

      final fixed = xml
          .replaceAll(
            '<type>whole</type><staff>2</staff>',
            '<type>whole</type><staff>2</staff>',
          )
          .replaceFirst(
            '<step>G</step><octave>2</octave></pitch><duration>4</duration>',
            '<step>G</step><octave>2</octave></pitch><duration>8</duration>',
          );
      final result = _editor.deleteNote(fixed, _ref(0));
      final notes = _notes(result.xml);

      expect(_pitchOf(notes[0]), 'E:0:5');
      expect(notes[0].getElement('chord'), isNull);
      expect(notes[0].getElement('beam')?.innerText, 'begin');
      _codec.decodeXml(result.xml);
    });

    test('deleting a single note leaves a rest and splits its beam', () {
      final xml =
          _score([
                '${_note('C', 5, type: 'eighth', beam: '<beam number="1">begin</beam>')}'
                    '${_note('D', 5, type: 'eighth', beam: '<beam number="1">continue</beam>')}'
                    '${_note('E', 5, type: 'eighth', beam: '<beam number="1">end</beam>')}'
                    '${_rest(duration: 5, type: 'half')}$_bass',
              ], divisions: 2)
              .replaceAll(
                '<backup><duration>4</duration>',
                '<backup><duration>8</duration>',
              )
              .replaceFirst(
                '<step>G</step><octave>2</octave></pitch><duration>4</duration>',
                '<step>G</step><octave>2</octave></pitch><duration>8</duration>',
              );

      final result = _editor.deleteNote(xml, _ref(1));
      final notes = _notes(result.xml);

      expect(notes[1].getElement('rest'), isNotNull);
      expect(notes[1].getElement('pitch'), isNull);
      expect(_beams(result.xml).take(3), ['', '', '']);
    });

    test('turns a rest into a middle-line note for each clef', () {
      final xml = _score([
        '${_rest(duration: 4, type: 'whole')}'
            '<backup><duration>4</duration></backup>'
            '${_rest(duration: 4, type: 'whole', voice: '5', staff: 2)}',
      ]);

      final treble = _editor.restToNote(xml, _ref(0));
      final bass = _editor.restToNote(xml, _ref(1));

      expect(_pitchOf(_notes(treble.xml).first), 'B:0:4');
      expect(_pitchOf(_notes(bass.xml)[1]), 'D:0:3');
    });

    test('a whole-bar rest without a type gets one', () {
      final xml = _score([
        '<note><rest measure="yes"/><duration>4</duration><voice>1</voice>'
            '<staff>1</staff></note>$_bass',
      ]);

      final result = _editor.restToNote(xml, _ref(0));

      expect(_notes(result.xml).first.getElement('type')?.innerText, 'whole');
    });
  });

  group('duration', () {
    test('shortening leaves a rest and keeps the other staff aligned', () {
      final xml = _score([
        '${_note('C', 5)}${_note('D', 5)}${_note('E', 5)}${_note('F', 5)}$_bass',
      ]);

      final result = _editor.setDuration(xml, _ref(1), 'eighth', 0);

      final notes = _notes(result.xml);
      expect(notes[1].getElement('type')?.innerText, 'eighth');
      expect(notes[2].getElement('rest'), isNotNull);
      expect(notes[2].getElement('type')?.innerText, 'eighth');
      expect(_timeline(result.xml, '1'), [
        (0, 2),
        (2, 1),
        (3, 1),
        (4, 2),
        (6, 2),
      ]);
      expect(_timeline(result.xml, '5'), [(0, 8)]);
      final divisions = XmlDocument.parse(
        result.xml,
      ).findAllElements('divisions').map((e) => e.innerText).toList();
      expect(divisions, ['2']);
    });

    test('scaled divisions are restored in the next measure', () {
      final xml = _score([
        '${_note('C', 5)}${_note('D', 5)}${_note('E', 5)}${_note('F', 5)}$_bass',
        '${_note('G', 5, duration: 4, type: 'whole')}$_bass',
      ]);

      final result = _editor.setDuration(xml, _ref(0), 'eighth', 0);
      final decoded = _codec.decodeXml(result.xml);

      expect(decoded.parts.first.measures[1].attributes.divisions, 1);
      expect(decoded.parts.first.measures[1].notes.first.duration, 4);
    });

    test('lengthening overwrites the following notes', () {
      final xml = _score([
        '${_note('C', 5)}${_note('D', 5)}${_note('E', 5)}${_note('F', 5)}$_bass',
      ]);

      final result = _editor.setDuration(xml, _ref(0), 'half', 0);

      expect(_notes(result.xml).map(_pitchOf).take(3), [
        'C:0:5',
        'E:0:5',
        'F:0:5',
      ]);
      expect(_timeline(result.xml, '1'), [(0, 2), (2, 1), (3, 1)]);
    });

    test('a partly covered note becomes a rest', () {
      final xml = _score([
        '${_note('C', 5)}${_note('D', 5, duration: 2, type: 'half')}'
            '${_note('F', 5)}$_bass',
      ]);

      final result = _editor.setDuration(xml, _ref(0), 'half', 0);
      final notes = _notes(result.xml);

      expect(notes[1].getElement('rest'), isNotNull);
      expect(_timeline(result.xml, '1'), [(0, 2), (2, 1), (3, 1)]);
    });

    test('dotted values fill with a rest on the next beat', () {
      final xml = _score([
        '${_note('C', 5, duration: 2, type: 'half')}${_note('E', 5, duration: 2, type: 'half')}$_bass',
      ]);

      final result = _editor.setDuration(xml, _ref(0), 'quarter', 1);

      expect(_timeline(result.xml, '1'), [(0, 3), (3, 1), (4, 4)]);
      expect(_notes(result.xml)[1].getElement('rest'), isNotNull);
    });

    test('refuses notes that would cross the barline', () {
      final xml = _score([
        '${_note('C', 5, duration: 3, type: 'half')}${_note('D', 5)}$_bass',
      ]).replaceFirst('<type>half</type>', '<type>half</type><dot/>');

      expect(
        () => _editor.setDuration(xml, _ref(1), 'half', 0),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            '마디 길이를 넘습니다.',
          ),
        ),
      );
    });

    test('shortening a tied note drops only its outgoing tie', () {
      final xml = _score([
        '${_note('C', 5, duration: 2, type: 'half', extra: '<tie type="stop"/>')}'
            '${_note('D', 5, duration: 2, type: 'half', extra: '<tie type="start"/>', beam: '<notations><tied type="start"/></notations>')}'
            '$_bass',
        '${_note('D', 5, duration: 4, type: 'whole', extra: '<tie type="stop"/>', beam: '<notations><tied type="stop"/></notations>')}'
            '$_bass',
      ]);

      final result = _editor.setDuration(xml, _ref(1), 'quarter', 0);

      final notes = _notes(result.xml);
      expect(notes[0].findElements('tie').single.getAttribute('type'), 'stop');
      expect(notes[1].findElements('tie'), isEmpty);
      expect(notes[1].findAllElements('tied'), isEmpty);
      final next = _notes(result.xml, measureIndex: 1).first;
      expect(next.findElements('tie'), isEmpty);
      expect(next.findAllElements('tied'), isEmpty);
      expect(_timeline(result.xml, '1'), [(0, 2), (2, 1), (3, 1)]);
    });

    test('refuses tuplets', () {
      const tripletEighth =
          '<type>eighth</type><time-modification><actual-notes>3</actual-notes>'
          '<normal-notes>2</normal-notes></time-modification>';
      final xml = _score(
        [
              '${_note('C', 5, duration: 2, type: 'eighth')}'
                      '${_note('D', 5, duration: 2, type: 'eighth')}'
                      '${_note('E', 5, duration: 2, type: 'eighth')}'
                      '${_note('F', 5, duration: 6, type: 'half')}'
                  .replaceAll('<type>eighth</type>', tripletEighth),
            ]
            .map(
              (m) =>
                  '$m<backup><duration>12</duration></backup>'
                  '<note><pitch><step>G</step><octave>2</octave></pitch>'
                  '<duration>12</duration><voice>5</voice><type>whole</type>'
                  '<staff>2</staff></note>',
            )
            .toList(),
        divisions: 3,
      );

      expect(
        () => _editor.setDuration(xml, _ref(0), 'quarter', 0),
        throwsFormatException,
      );
    });

    test('re-beams only the edited beats, joining halves of a 4/4 bar', () {
      final eighths = [
        for (final step in ['D', 'E', 'F', 'G', 'A', 'B'])
          _note(step, 5, type: 'eighth'),
      ].join();
      final xml = _score([
        '${_note('C', 5, duration: 2)}$eighths'
            '<backup><duration>8</duration></backup>'
            '<note><pitch><step>G</step><octave>2</octave></pitch>'
            '<duration>8</duration><voice>5</voice><type>whole</type>'
            '<staff>2</staff></note>',
      ], divisions: 2);

      final result = _editor.setDuration(xml, _ref(0), 'eighth', 0);

      // C and the fill rest share beat 1; D-E sit in beat 2 of the same half
      // bar and get beamed. The untouched second half keeps no beams.
      expect(_beams(result.xml).take(8), [
        '',
        '',
        'begin',
        'end',
        '',
        '',
        '',
        '',
      ]);
      _codec.decodeXml(result.xml);
    });

    test('a note from a rest joins its beat with a sixteenth hook', () {
      final xml = _score([
        '${_note('C', 5, duration: 4)}${_note('D', 5, duration: 4)}'
            '${_note('E', 5, duration: 8, type: 'half')}'
            '<backup><duration>16</duration></backup>'
            '<note><pitch><step>G</step><octave>2</octave></pitch>'
            '<duration>16</duration><voice>5</voice><type>whole</type>'
            '<staff>2</staff></note>',
      ], divisions: 4);

      var result = _editor.setDuration(xml, _ref(0), 'eighth', 1);
      expect(_notes(result.xml)[1].getElement('type')?.innerText, '16th');
      result = _editor.restToNote(result.xml, _ref(1));

      expect(_beams(result.xml).take(3), ['begin', 'end+backward hook', '']);
    });
  });

  group('harmony', () {
    test('adds, replaces and removes a chord symbol at the note', () {
      final xml = _score([
        '${_note('C', 5)}${_note('D', 5)}${_note('E', 5)}${_note('F', 5)}$_bass',
      ]);

      var result = _editor.setHarmony(xml, _ref(1), 'F#m7/C#');
      var score = _codec.decodeXml(result.xml);
      var harmony = score.parts.first.measures.first.events
          .whereType<MusicHarmony>()
          .single;
      expect(harmony.onset, 1);
      expect(harmony.rootStep, PitchStep.f);
      expect(harmony.rootAlter, 1);
      expect(harmony.kind, 'minor-seventh');
      expect(harmony.bassStep, PitchStep.c);
      expect(_editor.describe(result.xml, _ref(1)).harmony, 'F#m7/C#');

      result = _editor.setHarmony(result.xml, _ref(1), 'Bbmaj7');
      score = _codec.decodeXml(result.xml);
      harmony = score.parts.first.measures.first.events
          .whereType<MusicHarmony>()
          .single;
      expect(harmony.rootStep, PitchStep.b);
      expect(harmony.rootAlter, -1);
      expect(harmony.kind, 'major-seventh');

      result = _editor.setHarmony(result.xml, _ref(1), '');
      expect(result.xml, isNot(contains('<harmony')));
    });

    test('parses common chord spellings', () {
      expect(parseChordSymbol('C').kind, 'major');
      expect(parseChordSymbol('Am').kind, 'minor');
      expect(parseChordSymbol('G7').kind, 'dominant');
      expect(parseChordSymbol('Bm7b5').kind, 'half-diminished');
      expect(parseChordSymbol('E♭sus4').rootAlter, -1);
      expect(parseChordSymbol('Dadd9').kind, 'major');
      expect(parseChordSymbol('Dadd9').text, 'add9');
      expect(parseChordSymbol('F#m9').kind, 'minor-ninth');
      expect(() => parseChordSymbol('H7'), throwsFormatException);
    });
  });

  test('maps decoded event indexes to note indexes around harmony', () {
    final xml = _editor
        .setHarmony(
          _score([
            '${_note('C', 5)}${_note('D', 5)}${_note('E', 5)}${_note('F', 5)}$_bass',
          ]),
          _ref(2),
          'Am',
        )
        .xml;
    final measure = _codec.decodeXml(xml).parts.first.measures.first;
    final harmonyIndex = measure.events.indexWhere((e) => e is MusicHarmony);

    expect(xmlNoteIndexForEvent(measure, harmonyIndex), isNull);
    expect(xmlNoteIndexForEvent(measure, harmonyIndex + 1), 2);
    expect(eventIndexForXmlNote(measure, 2), harmonyIndex + 1);
  });

  test('isolates one bar with the clef, key and time of earlier bars', () {
    final xml = _score([
      '${_note('C', 5, duration: 4, type: 'whole')}$_bass',
      '${_note('D', 5, duration: 4, type: 'whole')}$_bass',
    ], fifths: 3);

    final isolated = isolateMeasureXml(xml, 0, 1);
    final score = _codec.decodeXml(isolated);

    expect(score.measureCount, 1);
    final measure = score.parts.first.measures.single;
    expect(measure.attributes.keyFifths, 3);
    expect(measure.attributes.staves, 2);
    expect(measure.notes.first.pitch?.step, PitchStep.d);
    expect(measureCountOf(xml, 0), 2);
  });

  test('tags isolated notes with codec event ids, skipping harmony', () {
    final xml = _editor
        .setHarmony(
          _score([
            '${_note('C', 5)}${_note('D', 5)}${_note('E', 5)}${_note('F', 5)}$_bass',
          ]),
          _ref(1),
          'G',
        )
        .xml;
    final isolated = isolateMeasureXml(xml, 0, 0);
    final measure = _codec.decodeXml(isolated).parts.first.measures.first;

    final ids = _notes(
      tagIsolatedNotes(isolated, measure),
    ).map((note) => note.getAttribute('id')).toList();

    expect(ids, ['p0-m0-e0', 'p0-m0-e2', 'p0-m0-e3', 'p0-m0-e4', 'p0-m0-e5']);
  });

  test('lengthening fills beats missing from a converted bar', () {
    // Only two of four beats were recognised in the right hand.
    final xml = _score([
      '${_note('C', 5)}${_note('D', 5)}'
          '<backup><duration>2</duration></backup>'
          '<note><pitch><step>G</step><octave>2</octave></pitch>'
          '<duration>4</duration><voice>5</voice><type>whole</type>'
          '<staff>2</staff></note>',
    ]);

    final result = _editor.setDuration(xml, _ref(1), 'half', 1);

    expect(_timeline(result.xml, '1'), [(0, 1), (1, 3)]);
    expect(_timeline(result.xml, '5'), [(0, 4)]);
    expect(result.xml, contains('<backup><duration>4</duration></backup>'));
    expect(
      () => _editor.setDuration(result.xml, _ref(1), 'whole', 0),
      throwsFormatException,
    );
  });

  group('performance copy', () {
    final xml = _score([
      '<barline location="left"><bar-style>heavy-light</bar-style>'
          '<repeat direction="forward"/></barline>'
          '<direction><direction-type><dynamics><f/></dynamics></direction-type>'
          '<staff>1</staff></direction>'
          '${_note('C', 5, duration: 4, type: 'whole')}$_bass',
      '${_note('D', 5, duration: 4, type: 'whole')}$_bass'
          '<barline location="right"><bar-style>light-heavy</bar-style>'
          '<repeat direction="backward"/></barline>',
      '<attributes><key><fifths>-2</fifths></key></attributes>'
          '${_note('E', 5, alter: -1, duration: 4, type: 'whole')}$_bass',
    ]);

    test('a repeated first bar keeps no restated time; jumps start a line', () {
      const xml =
          '''<score-partwise version="3.1"><part-list><score-part id="P1"><part-name>V</part-name></score-part></part-list>
<part id="P1">
<measure number="1"><attributes><divisions>1</divisions><key><fifths>1</fifths></key><time><beats>4</beats><beat-type>4</beat-type></time><clef><sign>G</sign><line>2</line></clef></attributes>
<note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration><voice>1</voice><type>whole</type></note></measure>
<measure number="2"><print new-system="yes"/><note><pitch><step>D</step><octave>5</octave></pitch><duration>4</duration><voice>1</voice><type>whole</type></note></measure>
</part></score-partwise>''';
      final expanded = expandMusicXml(xml, [0, 1, 0, 1]);
      final measures = XmlDocument.parse(
        expanded,
      ).findAllElements('measure').toList();
      expect(measures.first.findAllElements('time'), hasLength(1));
      expect(measures[2].findAllElements('time'), isEmpty);
      expect(measures[2].findAllElements('clef'), isEmpty);
      bool newLine(XmlElement m) => m
          .findElements('print')
          .any((p) => p.getAttribute('new-system') == 'yes');
      expect(measures.map(newLine), [false, true, true, true]);
    });

    test('a bar with two attributes keeps the state the last one sets', () {
      // A converter left a stale <attributes> (key 0, divisions 1) before
      // the real one (key 1, divisions 4) in bar 2.
      const xml =
          '''<score-partwise version="3.1"><part-list><score-part id="P1"><part-name>V</part-name></score-part></part-list>
<part id="P1">
<measure number="1"><attributes><divisions>4</divisions><key><fifths>1</fifths></key><time><beats>4</beats><beat-type>4</beat-type></time><clef><sign>G</sign><line>2</line></clef></attributes>
<note><pitch><step>C</step><octave>5</octave></pitch><duration>16</duration><voice>1</voice><type>whole</type></note></measure>
<measure number="2"><attributes><divisions>1</divisions><key><fifths>0</fifths></key><time><beats>4</beats><beat-type>4</beat-type></time></attributes><attributes><divisions>4</divisions><key><fifths>1</fifths></key><time><beats>4</beats><beat-type>4</beat-type></time><clef><sign>G</sign><line>2</line></clef></attributes>
<note><pitch><step>D</step><octave>5</octave></pitch><duration>16</duration><voice>1</voice><type>whole</type></note></measure>
</part></score-partwise>''';
      final expandedXml = expandMusicXml(xml, [0, 1, 0, 1]);
      final expanded = _codec.decodeXml(expandedXml);
      for (final measure in expanded.parts.single.measures) {
        expect(measure.attributes.keyFifths, 1);
        expect(measure.attributes.divisions, 4);
        expect(measure.notes.single.duration, 16);
      }
      // The stale key is gone, so no cancelled key signature is drawn.
      expect(expandedXml, isNot(contains('<fifths>0</fifths>')));
    });

    test('user sections replace printed rehearsal boxes, source untouched', () {
      const xml =
          '''<score-partwise version="3.1"><part-list><score-part id="P1"><part-name>V</part-name></score-part></part-list>
<part id="P1">
<measure number="1"><attributes><divisions>1</divisions></attributes>
<direction><direction-type><rehearsal enclosure="square">A</rehearsal></direction-type></direction>
<note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration><voice>1</voice><type>whole</type></note></measure>
<measure number="2"><direction><direction-type><rehearsal>프</rehearsal></direction-type><direction-type><words>rit.</words></direction-type></direction>
<note><pitch><step>D</step><octave>5</octave></pitch><duration>4</duration><voice>1</voice><type>whole</type></note></measure>
</part></score-partwise>''';
      final shown = withSectionRehearsals(xml, [
        (measureIndex: 0, label: 'Intro'),
        (measureIndex: 1, label: 'Verse'),
      ]);
      final doc = XmlDocument.parse(shown);
      expect(doc.findAllElements('rehearsal').map((e) => e.innerText), [
        'Intro',
        'Verse',
      ]);
      // Other text in the same direction stays; the box sits after attributes.
      expect(doc.findAllElements('words').single.innerText, 'rit.');
      final first = doc.findAllElements('measure').first.childElements.toList();
      expect(first[0].name.local, 'attributes');
      expect(first[1].findAllElements('rehearsal').single.innerText, 'Intro');
      // The source string is unchanged.
      expect(xml, contains('>A</rehearsal>'));
      expect(xml, contains('>프</rehearsal>'));
    });

    test('an expanded copy drops jumps it has already followed', () {
      const xml =
          '''<score-partwise version="3.1"><part-list><score-part id="P1"><part-name>V</part-name></score-part></part-list>
<part id="P1">
<measure number="1"><attributes><divisions>1</divisions></attributes>
<direction><direction-type><segno/></direction-type><sound segno="segno"/></direction>
<note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration><voice>1</voice><type>whole</type></note></measure>
<measure number="2"><note><pitch><step>D</step><octave>5</octave></pitch><duration>4</duration><voice>1</voice><type>whole</type></note>
<direction><direction-type><words>D.S. al Fine</words></direction-type><sound dalsegno="segno"/></direction></measure>
</part></score-partwise>''';
      final expanded = expandMusicXml(xml, [0, 1, 0]);
      expect(expanded, isNot(contains('dalsegno')));
      expect(expanded, isNot(contains('D.S. al Fine')));
      expect(RegExp('<segno/>').allMatches(expanded).length, 2);
    });

    test('copies bars in order, keeps markings and drops repeats', () {
      final expanded = expandMusicXml(xml, [2, 0, 1, 0]);
      final document = XmlDocument.parse(expanded);
      final measures = document.findAllElements('measure').toList();

      expect(measures.map((m) => m.getAttribute('number')), [
        '1',
        '2',
        '3',
        '4',
      ]);
      expect(expanded, contains('<f/>'));
      expect(document.findAllElements('repeat'), isEmpty);
      final score = _codec.decodeXml(expanded);
      final bars = score.parts.first.measures;
      expect(bars.map((m) => m.notes.first.pitch!.step), [
        PitchStep.e,
        PitchStep.c,
        PitchStep.d,
        PitchStep.c,
      ]);
      // Jumping back to bar 1 restates the key in force there (1 sharp).
      expect(bars[0].attributes.keyFifths, -2);
      expect(bars[1].attributes.keyFifths, 1);
      expect(bars[1].attributes.staves, 2);
      expect(bars[3].attributes.keyFifths, 1);
    });

    test('the codec keeps repeat signs through a round trip', () {
      final score = _codec.decodeXml(xml);
      expect(score.parts.first.measures.first.repeatStart, isTrue);
      expect(score.parts.first.measures[1].repeatEnd, isTrue);

      final again = _codec.decodeXml(
        String.fromCharCodes(_codec.encodeMusicXml(score)),
      );
      expect(again.parts.first.measures.first.repeatStart, isTrue);
      expect(again.parts.first.measures[1].repeatEnd, isTrue);
      expect(again.parts.first.measures[1].repeatTimes, 2);
    });
  });

  test('the codec keeps lyrics through a round trip and a transposition', () {
    final xml = _score([
      '${_note('C', 5, beam: '<lyric number="1"><syllabic>begin</syllabic><text>사</text></lyric>')}'
          '${_note('D', 5, beam: '<lyric number="1"><syllabic>end</syllabic><text>랑</text></lyric>')}'
          '${_note('E', 5, duration: 2, type: 'half')}$_bass',
    ]);

    final score = _codec.decodeXml(xml);
    final moved = score.copyWith(
      parts: [
        for (final part in score.parts)
          part.copyWith(
            measures: [
              for (final measure in part.measures)
                measure.copyWith(
                  events: [
                    for (final event in measure.events)
                      event is MusicNote && event.pitch != null
                          ? event.copyWith(
                              pitch: MusicPitch(
                                step: event.pitch!.step,
                                octave: event.pitch!.octave - 1,
                              ),
                            )
                          : event,
                  ],
                ),
            ],
          ),
      ],
    );
    final encoded = utf8.decode(_codec.encodeMusicXml(moved));

    expect(encoded, contains('<text>사</text>'));
    expect(encoded, contains('<syllabic>end</syllabic>'));
    expect(
      _codec.decodeXml(encoded).parts.first.measures.first.notes.first.lyrics,
      hasLength(1),
    );
  });

  group('edits found by fuzzing real scores', () {
    const tieStart = '<tie type="start"/>';
    const tieStop = '<tie type="stop"/>';

    bool hasTie(XmlElement note, String type) =>
        note.findElements('tie').any((t) => t.getAttribute('type') == type);

    test('a longer note cuts the ties of the notes it overwrites', () {
      // C | D E~ | ~E: making C a half note overwrites D and the first E.
      final xml = _score([
        '${_note('C', 5)}${_note('D', 5)}${_note('E', 5, extra: tieStart)}'
            '${_note('E', 5, extra: tieStop)}',
      ], staves: 1);

      final result = _editor.setDuration(xml, _ref(0), 'half', 1);

      final notes = _notes(result.xml);
      expect(notes, hasLength(2));
      expect(hasTie(notes[1], 'stop'), isFalse);
    });

    test('a note freed from its tie gets its accidental back', () {
      // F natural (written) tied over the barline: in the next bar it has no
      // sign of its own. Overwriting the first one leaves the second alone.
      final xml = _score([
        '${_note('C', 5, duration: 3, type: 'half')}'
            '${_note('F', 5, extra: tieStart, accidental: 'natural')}',
        '${_note('F', 5, extra: tieStop)}${_note('G', 5, duration: 3, type: 'half')}',
      ], staves: 1);

      final result = _editor.setDuration(xml, _ref(0), 'whole', 0);

      final next = _notes(result.xml, measureIndex: 1).first;
      expect(hasTie(next, 'stop'), isFalse);
      expect(next.getElement('accidental')?.innerText, 'natural');
    });

    test('an overwritten note leaves no sign another note relied on', () {
      // G major: F natural, then F with no sign (still natural). Overwriting
      // the first F gives the second its natural.
      final xml = _score([
        '${_note('C', 5)}${_note('F', 5, accidental: 'natural')}'
            '${_note('F', 5)}${_note('G', 5)}',
      ], staves: 1);

      final result = _editor.setDuration(xml, _ref(0), 'half', 0);

      final notes = _notes(result.xml);
      expect(notes, hasLength(3));
      expect(notes[1].getElement('accidental')?.innerText, 'natural');
    });

    test('the picked note of a chord stays picked after retiming', () {
      final xml = _score([
        '${_note('C', 5, duration: 2, type: 'half')}'
            '${_note('E', 5, duration: 2, type: 'half', chord: true)}'
            '${_note('G', 5, duration: 2, type: 'half')}',
      ], staves: 1);

      final result = _editor.setDuration(xml, _ref(1), 'quarter', 0);

      expect(result.selection.noteIndex, 1);
    });

    test('a beam cut by a new rest is not left without a beginning', () {
      // Four beamed eighths; shortening the second to a 16th puts a rest in
      // the group. No note may keep "continue" or "end" on its own.
      String eighth(String step, String beam) =>
          _note(step, 5, type: 'eighth', beam: '<beam number="1">$beam</beam>');
      final xml = _score(
        [
          '${eighth('C', 'begin')}${eighth('D', 'continue')}'
              '${eighth('E', 'continue')}${eighth('F', 'end')}'
              '${_note('G', 5, duration: 4, type: 'half')}',
        ],
        divisions: 2,
        staves: 1,
      );

      final result = _editor.setDuration(xml, _ref(1), '16th', 0);

      var open = false;
      for (final note in _notes(result.xml)) {
        final beam = note
            .findElements('beam')
            .where((b) => b.getAttribute('number') == '1')
            .map((b) => b.innerText)
            .firstOrNull;
        if (beam == null) {
          expect(open, isFalse, reason: 'a beam was left open');
          continue;
        }
        expect(note.getElement('rest'), isNull);
        if (beam == 'begin') {
          expect(open, isFalse);
          open = true;
        } else {
          expect(open, isTrue, reason: '"$beam" without a beginning');
          if (beam == 'end') open = false;
        }
      }
      expect(open, isFalse);
    });

    test('a chord symbol over an overwritten note stays on its beat', () {
      const g =
          '<harmony><root><root-step>G</root-step></root><kind>major</kind></harmony>';
      const d =
          '<harmony><root><root-step>D</root-step></root><kind>major</kind></harmony>';
      // C | G chord on beat 2 | D chord on beat 3.
      final xml = _score([
        '${_note('C', 5)}$g${_note('D', 5)}$d${_note('E', 5)}${_note('F', 5)}',
      ], staves: 1);

      final result = _editor.setDuration(xml, _ref(0), 'half', 0);

      final harmonies = _codec
          .decodeXml(result.xml)
          .parts
          .first
          .measures
          .first
          .events
          .whereType<MusicHarmony>()
          .toList();
      // G still sounds on beat 2 (inside the half note), D on beat 3; they
      // are not stacked on the E.
      expect(harmonies.map((h) => (h.rootStep, h.onset)), [
        (PitchStep.g, 1),
        (PitchStep.d, 2),
      ]);
      expect(_editor.describe(result.xml, _ref(1)).harmony, 'D');
    });

    test('a chord symbol kept by its offset can be replaced in place', () {
      const g =
          '<harmony><root><root-step>G</root-step></root><kind>major</kind></harmony>';
      final xml = _score([
        '${_note('C', 5)}$g${_note('D', 5)}${_note('E', 5)}${_note('F', 5)}',
      ], staves: 1);
      // The half note covers beat 2; shortening it again puts a rest there,
      // under the G that stayed on its beat.
      var result = _editor.setDuration(xml, _ref(0), 'half', 0);
      result = _editor.setDuration(result.xml, result.selection, 'quarter', 0);
      expect(_editor.describe(result.xml, _ref(1)).harmony, 'G');

      result = _editor.setHarmony(result.xml, _ref(1), 'Am');

      final harmonies = _codec
          .decodeXml(result.xml)
          .parts
          .first
          .measures
          .first
          .events
          .whereType<MusicHarmony>()
          .toList();
      expect(harmonies.map((h) => (h.rootStep, h.onset)), [(PitchStep.a, 1)]);
    });

    test('only the last note of a bar is tied into the next bar', () {
      // G~ G | G: a converter left a tie end on the first note of bar 2
      // although the last note of bar 1 starts no tie. Raising it must not
      // drag the first G of bar 1 along.
      final xml = _score([
        '${_note('G', 4, duration: 2, type: 'half', extra: tieStart)}'
            '${_note('G', 4, duration: 2, type: 'half', extra: tieStop)}',
        '${_note('G', 4, duration: 4, type: 'whole', extra: tieStop)}',
      ], staves: 1);

      final result = _editor.moveDiatonic(xml, _ref(0, measureIndex: 1), 1);

      String step(XmlElement note) =>
          note.getElement('pitch')!.getElement('step')!.innerText;
      expect(_notes(result.xml).map(step), ['G', 'G']);
      expect(_notes(result.xml, measureIndex: 1).map(step), ['A']);
    });

    test('chord symbols need a root and a bass that can be read', () {
      for (final text in ['C/H', 'A/', 'Cm/', 'C##', 'Bbb', 'H', '7']) {
        expect(
          () => parseChordSymbol(text),
          throwsFormatException,
          reason: text,
        );
      }
      expect(parseChordSymbol('Bb/D').bassStep, PitchStep.d);
      expect(parseChordSymbol('F#m7b5').rootAlter, 1);
      expect(parseChordSymbol('Cb').rootAlter, -1);
    });
  });
}
