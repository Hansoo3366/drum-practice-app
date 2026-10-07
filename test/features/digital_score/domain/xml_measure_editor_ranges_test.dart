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
  String extra = '',
  String voice = '1',
  int? staff,
}) =>
    '<note><pitch><step>$step</step>${alter == 0 ? '' : '<alter>$alter</alter>'}'
    '<octave>$octave</octave></pitch><duration>$duration</duration>$extra'
    '<voice>$voice</voice><type>$type</type>'
    '${staff == null ? '' : '<staff>$staff</staff>'}</note>';

String _bar(String steps, {int octave = 4}) =>
    [for (final step in steps.split('')) _note(step, octave)].join();

String _harmony(String root) =>
    '<harmony><root><root-step>$root</root-step></root><kind>major</kind></harmony>';

String _score(
  List<String> measures, {
  int fifths = 0,
  int staves = 1,
  String partList =
      '<score-part id="P1"><part-name>Voice</part-name></score-part>',
}) {
  final buffer = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<score-partwise version="4.0"><part-list>$partList</part-list>'
    '<part id="P1">',
  );
  for (var i = 0; i < measures.length; i++) {
    buffer.write('<measure number="${i + 1}">');
    if (i == 0) {
      buffer.write(
        '<attributes><divisions>1</divisions>'
        '<key><fifths>$fifths</fifths></key>'
        '<time><beats>4</beats><beat-type>4</beat-type></time>'
        '${staves > 1 ? '<staves>$staves</staves>' : ''}'
        '<clef${staves > 1 ? ' number="1"' : ''}><sign>G</sign><line>2</line></clef>'
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

XmlNoteRef _ref(int noteIndex, {int measureIndex = 0}) =>
    XmlNoteRef(partIndex: 0, measureIndex: measureIndex, noteIndex: noteIndex);

List<XmlElement> _measures(String xml) =>
    XmlDocument.parse(xml).findAllElements('measure').toList();

/// The steps of the notes of each bar, e.g. ["CDEF", "GABC"].
List<String> _steps(String xml) => [
  for (final measure in _codec.decodeXml(xml).parts.first.measures)
    [
      for (final note in measure.notes)
        note.pitch == null ? '-' : note.pitch!.step.name.toUpperCase(),
    ].join(),
];

List<int> _keys(String xml) => [
  for (final measure in _codec.decodeXml(xml).parts.first.measures)
    measure.attributes.keyFifths,
];

/// Onset and length of each note of a voice of a bar, after decoding.
List<(int, int)> _timeline(String xml, String voice, {int measureIndex = 0}) =>
    [
      for (final note
          in _codec.decodeXml(xml).parts.first.measures[measureIndex].notes)
        if (note.voice == voice && !note.isChord) (note.onset, note.duration),
    ];

void main() {
  group('a run of bars', () {
    test('is copied and pasted after another bar, without its place signs', () {
      final xml = _score([
        '<barline location="left"><repeat direction="forward"/></barline>'
            '<direction><direction-type><rehearsal>A</rehearsal></direction-type></direction>'
            '${_harmony('C')}${_bar('CDEF')}',
        '<print new-system="yes"/>${_bar('GABC')}',
        '${_bar('EEEE')}<barline location="right"><bar-style>light-heavy</bar-style></barline>',
      ]);

      final clip = _editor.copyMeasures(xml, 0, 1);
      final result = _editor.pasteMeasures(xml, _ref(0, measureIndex: 2), clip);

      expect(clip.length, 2);
      expect(_steps(result.xml), ['CDEF', 'GABC', 'EEEE', 'CDEF', 'GABC']);
      final bars = _measures(result.xml);
      expect(bars.map((b) => b.getAttribute('number')), [
        '1',
        '2',
        '3',
        '4',
        '5',
      ]);
      // The chord came along; the section box, the repeat and the line
      // break stayed where they were.
      expect(bars[3].findElements('harmony'), hasLength(1));
      expect(bars[3].findAllElements('rehearsal'), isEmpty);
      expect(bars[3].findElements('barline'), isEmpty);
      expect(bars[4].findElements('print'), isEmpty);
      // The piece still ends with its final barline.
      expect(bars[2].findElements('barline'), isEmpty);
      expect(
        bars[4].findAllElements('bar-style').single.innerText,
        'light-heavy',
      );
      expect(result.selection.measureIndex, 3);
    });

    test('pasted into another key it says its own, and the old one after', () {
      final source = _score([_bar('GABC')], fifths: 1);
      final target = _score([_bar('FFFF'), _bar('AAAA')], fifths: -1);

      final clip = _editor.copyMeasures(source, 0, 0);
      final result = _editor.pasteMeasures(target, _ref(0), clip);

      expect(_keys(result.xml), [-1, 1, -1]);
      expect(_steps(result.xml), ['FFFF', 'GABC', 'AAAA']);
    });

    test('is removed, but never the whole piece', () {
      final xml = _score([
        _bar('CCCC'),
        _bar('DDDD'),
        _bar('EEEE'),
        _bar('FFFF'),
      ]);

      final result = _editor.deleteMeasures(xml, 0, 1, 2);

      expect(_steps(result.xml), ['CCCC', 'FFFF']);
      expect(result.selection.measureIndex, 1);
      expect(
        () => _editor.deleteMeasures(xml, 0, 0, 3),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => _editor.deleteMeasures(xml, 0, 2, 5),
        throwsA(isA<FormatException>()),
      );
    });

    test('is moved to another key: notes, chords and key, then back', () {
      final xml = _score([
        '${_harmony('C')}${_bar('CDEF')}',
        '${_harmony('C')}${_bar('CDEF')}',
        '${_harmony('C')}${_bar('CDEF')}',
      ]);

      final result = _editor.transposeMeasures(xml, 0, 1, 1, 2);

      // A whole tone up: D major for the middle bar, C major around it.
      expect(_keys(result.xml), [0, 2, 0]);
      final decoded = _codec.decodeXml(result.xml);
      final middle = decoded.parts.first.measures[1];
      expect(
        [
          for (final note in middle.notes)
            '${note.pitch!.step.name}${note.pitch!.alter}',
        ],
        ['d0', 'e0', 'f1', 'g0'],
      );
      expect(
        middle.events.whereType<MusicHarmony>().single.rootStep,
        PitchStep.d,
      );
      expect(_steps(result.xml), ['CDEF', 'DEFG', 'CDEF']);
      // F♯ is in the key now: no accidental is written on it.
      expect(_measures(result.xml)[1].findAllElements('accidental'), isEmpty);
    });

    test('an octave up keeps the key', () {
      final xml = _score([_bar('CDEF'), _bar('CDEF')]);

      final result = _editor.transposeMeasures(xml, 0, 0, 0, 12);

      expect(_keys(result.xml), [0, 0]);
      final notes = _codec.decodeXml(result.xml).parts.first.measures[0].notes;
      expect(notes.map((n) => n.pitch!.octave), everyElement(5));
    });
  });

  group('voices', () {
    test('a second voice is added as rests under the first', () {
      final xml = _score([_bar('CDEF', octave: 5)]);

      final result = _editor.addVoice(xml, _ref(0));

      expect(_timeline(result.xml, '1'), [(0, 1), (1, 1), (2, 1), (3, 1)]);
      expect(_timeline(result.xml, '2'), [(0, 4)]);
      expect(result.selection.noteIndex, 4);
      // The new rest is written like any other: it can be made a note and
      // split, and the first voice stays where it is.
      var edited = _editor.restToNote(result.xml, result.selection).xml;
      edited = _editor.splitNote(edited, result.selection).xml;
      expect(_timeline(edited, '2'), [(0, 2), (2, 2)]);
      expect(_timeline(edited, '1'), [(0, 1), (1, 1), (2, 1), (3, 1)]);
    });

    test('a voice is taken out and the others keep their time', () {
      final xml = _score([_bar('CDEF', octave: 5)]);
      final two = _editor.addVoice(xml, _ref(0));

      // The second voice goes: the bar is as it was.
      final back = _editor.removeVoice(two.xml, two.selection);
      expect(_measures(back.xml).first.findElements('backup'), isEmpty);
      expect(_timeline(back.xml, '1'), [(0, 1), (1, 1), (2, 1), (3, 1)]);

      // The first voice goes: the second begins the bar now.
      final first = _editor.removeVoice(two.xml, _ref(0));
      expect(_measures(first.xml).first.findElements('backup'), isEmpty);
      expect(_timeline(first.xml, '2'), [(0, 4)]);
      expect(_timeline(first.xml, '1'), isEmpty);

      expect(
        () => _editor.removeVoice(xml, _ref(0)),
        throwsA(isA<FormatException>()),
      );
    });

    test('a pickup bar gets a voice as long as itself', () {
      final xml = _score([_note('C', 5), _bar('CDEF', octave: 5)]);

      final result = _editor.addVoice(xml, _ref(0));

      expect(_timeline(result.xml, '2'), [(0, 1)]);
    });
  });

  group('staves', () {
    test('a lead sheet gets a bass staff with a rest in every bar', () {
      final xml = _score([
        '${_harmony('C')}${_bar('CDEF', octave: 5)}',
        _note('G', 4, duration: 4, type: 'whole'),
      ]);

      final result = _editor.addStaff(xml, 0);

      expect(_editor.staffCount(result.xml, 0), 2);
      final decoded = _codec.decodeXml(result.xml);
      final first = decoded.parts.first.measures.first;
      expect(first.attributes.staves, 2);
      expect(
        (first.attributes.clefs[1]?.sign, first.attributes.clefs[2]?.sign),
        ('G', 'F'),
      );
      for (final measure in decoded.parts.first.measures) {
        final below = measure.notes.where((n) => n.staff == 2).toList();
        expect(below, hasLength(1));
        expect(
          (below.single.isRest, below.single.onset, below.single.duration),
          (true, 0, 4),
        );
      }
      expect(_timeline(result.xml, '1'), [(0, 1), (1, 1), (2, 1), (3, 1)]);
      expect(
        () => _editor.addStaff(result.xml, 0),
        throwsA(isA<FormatException>()),
      );
    });

    test('the second staff is taken away and the first keeps its time', () {
      final grand = _score([
        '${_note('C', 5, duration: 2, type: 'half', staff: 1)}'
            '<backup><duration>2</duration></backup>'
            '${_note('C', 3, duration: 4, type: 'whole', voice: '5', staff: 2)}'
            '<backup><duration>2</duration></backup>'
            '${_harmony('G')}'
            '${_note('D', 5, duration: 2, type: 'half', staff: 1)}',
      ], staves: 2);

      final result = _editor.removeStaff(grand, 0);

      expect(_editor.staffCount(result.xml, 0), 1);
      final measure = _codec.decodeXml(result.xml).parts.first.measures.first;
      expect(measure.attributes.staves, 1);
      expect(
        [for (final note in measure.notes) (note.pitch!.step, note.onset)],
        [(PitchStep.c, 0), (PitchStep.d, 2)],
      );
      // The chord symbol is still at the third beat.
      expect(measure.events.whereType<MusicHarmony>().single.onset, 2);
      expect(_measures(result.xml).first.findElements('backup'), isEmpty);
      expect(_measures(result.xml).first.findAllElements('staff'), isEmpty);

      // And a staff added is a staff that can be removed again.
      final lead = _score([_bar('CDEF', octave: 5)]);
      final again = _editor.removeStaff(_editor.addStaff(lead, 0).xml, 0);
      expect(_steps(again.xml), ['CDEF']);
      expect(_measures(again.xml).first.findElements('backup'), isEmpty);
    });
  });

  group('the part and the page', () {
    test('a part is given an instrument the player knows', () {
      final xml = _score([_bar('CDEF')]);

      expect(_editor.instrumentOf(xml, 0), (name: 'Voice', program: 0));

      final result = _editor.setInstrument(xml, 0, 'Strings', 48);

      expect(_editor.instrumentOf(result.xml, 0), (
        name: 'Strings',
        program: 48,
      ));
      final part = XmlDocument.parse(
        result.xml,
      ).findAllElements('score-part').single;
      expect(part.childElements.map((e) => e.name.local), [
        'part-name',
        'score-instrument',
        'midi-instrument',
      ]);
      // MusicXML counts programs from 1.
      expect(part.findAllElements('midi-program').single.innerText, '49');
      expect(_codec.decodeXml(result.xml).parts.first.name, 'Strings');

      final changed = _editor.setInstrument(result.xml, 0, 'Flute', 73);
      expect(
        XmlDocument.parse(changed.xml).findAllElements('midi-instrument'),
        hasLength(1),
      );
      expect(_editor.instrumentOf(changed.xml, 0).program, 73);
    });

    test('a bar is made to begin a new line or page, and to follow again', () {
      final xml = _score([_bar('CDEF'), _bar('GABC'), _bar('EEEE')]);

      var result = _editor.toggleBreak(xml, 0, 1, page: false);
      expect(_editor.barSigns(result.xml, 0, 1).lineBreak, isTrue);
      expect(_editor.barSigns(result.xml, 0, 2).lineBreak, isFalse);
      expect(_measures(result.xml)[1].childElements.first.name.local, 'print');

      result = _editor.toggleBreak(result.xml, 0, 1, page: true);
      expect(_editor.barSigns(result.xml, 0, 1).pageBreak, isTrue);

      result = _editor.toggleBreak(result.xml, 0, 1, page: false);
      result = _editor.toggleBreak(result.xml, 0, 1, page: true);
      expect(_measures(result.xml)[1].findElements('print'), isEmpty);
      expect(
        () => _editor.toggleBreak(xml, 0, 0, page: false),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('one part for the screen', () {
    test('a part stands alone, without the page and the other parts', () {
      const two =
          '<score-partwise version="4.0">'
          '<credit page="1"><credit-words>Title</credit-words></credit>'
          '<part-list><score-part id="P1"><part-name>Voice</part-name></score-part>'
          '<score-part id="P2"><part-name>Piano</part-name></score-part></part-list>'
          '<part id="P1"><measure number="1"><attributes><divisions>1</divisions></attributes>'
          '<note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration></note></measure></part>'
          '<part id="P2"><measure number="1"><attributes><divisions>1</divisions></attributes>'
          '<note><pitch><step>E</step><octave>3</octave></pitch><duration>2</duration></note>'
          '<note><pitch><step>G</step><octave>3</octave></pitch><duration>2</duration></note></measure>'
          '<measure number="2"><print new-system="yes"/>'
          '<note><rest/><duration>4</duration></note></measure></part>'
          '</score-partwise>';

      final alone = partAloneXml(two, 1);
      final document = XmlDocument.parse(alone);

      expect(document.findAllElements('part').single.getAttribute('id'), 'P2');
      expect(
        document.findAllElements('score-part').single.getAttribute('id'),
        'P2',
      );
      expect(document.findAllElements('credit'), isEmpty);
      // Lines are laid out for the screen, not as the page had them.
      expect(document.findAllElements('print'), isEmpty);
      expect(document.findAllElements('measure'), hasLength(2));
      // The score it was taken from is as it was.
      expect(two, contains('<print new-system="yes"/>'));
      expect(() => partAloneXml(two, 2), throwsA(isA<FormatException>()));
    });

    test('a part is cut into lines that stand on their own', () {
      final xml = _score([
        _bar('CDEF'),
        '<print new-system="yes"/>${_bar('GABC')}',
        '<attributes><key><fifths>2</fifths></key></attributes>${_bar('DEFG')}',
        _bar('AAAA'),
        _bar('BBBB'),
      ], fifths: -1);

      final chunks = partChunks(xml, 0, const [0, 2, 4]);

      expect(chunks, hasLength(3));
      // Each line is a score: it decodes alone, in the key it is in.
      final decoded = [for (final chunk in chunks) _codec.decodeXml(chunk)];
      expect(
        [for (final score in decoded) score.parts.first.measures.length],
        [2, 2, 1],
      );
      expect(
        [
          for (final score in decoded)
            score.parts.first.measures.first.attributes.keyFifths,
        ],
        [-1, 2, 2],
      );
      for (final score in decoded) {
        final time = score.parts.first.measures.first.attributes.time;
        expect((time?.beats, time?.beatType), (4, 4));
      }
      // Bars keep their numbers, and the written line break is gone.
      expect(
        [
          for (final chunk in chunks)
            XmlDocument.parse(
              chunk,
            ).findAllElements('measure').map((m) => m.getAttribute('number')),
        ],
        [
          ['1', '2'],
          ['3', '4'],
          ['5'],
        ],
      );
      expect(chunks.join(), isNot(contains('<print')));
      // A second line repeats the time only to be read, not to be printed.
      expect(chunks[0], isNot(contains('print-object')));
      expect(chunks[1], contains('<time print-object="no">'));
    });

    test('the lines of a score are those it writes, long or short', () {
      final xml = _score([
        _bar('CDEF'),
        _bar('GABC'),
        _bar('DEFG'),
        '<print new-system="yes"/>${_bar('AAAA')}',
        '<print new-page="yes"/>${_bar('BBBB')}',
      ]);

      expect(writtenLineStarts(xml, 0), [0, 3, 4]);
      // Lines as written: three bars, then one, then one.
      expect(
        [
          for (final chunk in partChunks(xml, 0, writtenLineStarts(xml, 0)))
            XmlDocument.parse(chunk).findAllElements('measure').length,
        ],
        [3, 1, 1],
      );
      // A score that writes no breaks has no lines of its own.
      expect(
        writtenLineStarts(_score([_bar('CDEF'), _bar('GABC')]), 0),
        isEmpty,
      );
    });

    test('an edit changes the text of its own line only', () {
      final xml = _score([
        _bar('CDEF'),
        _bar('GABC'),
        _bar('DEFG'),
        _bar('AAAA'),
      ]);
      final before = partChunks(xml, 0, const [0, 2]);

      final edited = _editor.moveDiatonic(xml, _ref(0, measureIndex: 2), 1).xml;
      final after = partChunks(edited, 0, const [0, 2]);

      expect(after[0], before[0]);
      expect(after[1], isNot(before[1]));
    });

    test('a line is engraved with its notes named and no repeated time', () {
      final xml = _score([_bar('CDEF'), _bar('GABC'), _bar('DEFG')]);
      final chunk = partChunks(xml, 0, const [0, 2])[1];
      final decoded = _codec.decodeXml(chunk).parts.first.measures;

      final shown = chunkForDisplay(chunk, decoded, 2);

      final document = XmlDocument.parse(shown);
      expect(document.findAllElements('time'), isEmpty);
      expect(document.findAllElements('key'), hasLength(1));
      expect(
        document.findAllElements('note').map((n) => n.getAttribute('id')),
        ['p0-m2-e0', 'p0-m2-e1', 'p0-m2-e2', 'p0-m2-e3'],
      );
      // The chunk it was made from still says its time, for whoever reads it.
      expect(chunk, contains('<time'));
    });

    test('every note is named for the event it decodes to', () {
      final xml = _score([
        '${_harmony('C')}${_bar('CD', octave: 5)}'
            '<note><chord/><pitch><step>F</step><octave>5</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type></note>'
            '${_bar('EF', octave: 5)}',
        _bar('GABC'),
      ]);
      final alone = partAloneXml(xml, 0);
      final decoded = _codec.decodeXml(alone);

      final tagged = tagPartNotes(alone, decoded);

      final ids = [
        for (final note in XmlDocument.parse(tagged).findAllElements('note'))
          note.getAttribute('id'),
      ];
      // The chord symbol is event 0 of the first bar; the notes follow it.
      expect(ids.take(5), [
        'p0-m0-e1',
        'p0-m0-e2',
        'p0-m0-e3',
        'p0-m0-e4',
        'p0-m0-e5',
      ]);
      expect(ids.skip(5).first, startsWith('p0-m1-e'));
      final first = decoded.parts.first.measures.first;
      expect(first.events[1], isA<MusicNote>());
      expect(first.events[0], isA<MusicHarmony>());
    });
  });
}
