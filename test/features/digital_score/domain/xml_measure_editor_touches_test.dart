import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/digital_score/domain/xml_measure_editor.dart';
import 'package:xml/xml.dart';

const _editor = XmlMeasureEditor();
const _codec = MusicXmlCodec();

String _note(
  String step,
  int octave, {
  int alter = 0,
  int duration = 2,
  String type = 'quarter',
  String extra = '',
}) =>
    '<note><pitch><step>$step</step>${alter == 0 ? '' : '<alter>$alter</alter>'}'
    '<octave>$octave</octave></pitch><duration>$duration</duration>'
    '<voice>1</voice><type>$type</type>$extra</note>';

String _rest({int duration = 2, String type = 'quarter'}) =>
    '<note><rest/><duration>$duration</duration><voice>1</voice>'
    '<type>$type</type></note>';

/// A single staff in 4/4, two divisions to the quarter.
String _score(List<String> measures, {int fifths = 0}) {
  final buffer = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<score-partwise version="4.0"><part-list>'
    '<score-part id="P1"><part-name>Voice</part-name></score-part>'
    '</part-list><part id="P1">',
  );
  for (var i = 0; i < measures.length; i++) {
    buffer.write('<measure number="${i + 1}">');
    if (i == 0) {
      buffer.write(
        '<attributes><divisions>2</divisions>'
        '<key><fifths>$fifths</fifths></key>'
        '<time><beats>4</beats><beat-type>4</beat-type></time>'
        '<clef><sign>G</sign><line>2</line></clef></attributes>',
      );
    }
    buffer
      ..write(measures[i])
      ..write('</measure>');
  }
  buffer.write('</part></score-partwise>');
  return buffer.toString();
}

XmlNoteRef _ref(int noteIndex, {int measureIndex = 0}) =>
    XmlNoteRef(partIndex: 0, measureIndex: measureIndex, noteIndex: noteIndex);

List<XmlElement> _notes(String xml, {int measureIndex = 0}) =>
    XmlDocument.parse(xml)
        .findAllElements('measure')
        .elementAt(measureIndex)
        .findElements('note')
        .toList();

/// The notes of a bar as read back: "c4", "f#4", "r", a chord as "c4+e4".
List<String> _read(String xml, {int measureIndex = 0}) {
  final notes = _codec.decodeXml(xml).parts.first.measures[measureIndex].notes;
  final out = <String>[];
  for (final note in notes) {
    final name = note.isRest
        ? 'r'
        : '${note.pitch!.step.name}${switch (note.pitch!.alter) {
            > 0 => '#' * note.pitch!.alter,
            < 0 => 'b' * -note.pitch!.alter,
            _ => '',
          }}${note.pitch!.octave}';
    if (note.isChord && out.isNotEmpty) {
      out[out.length - 1] = '${out.last}+$name';
    } else {
      out.add(name);
    }
  }
  return out;
}

String _beams(String xml) => [
  for (final note in _notes(xml)) note.getElement('beam')?.innerText ?? '-',
].join(' ');

void main() {
  final quarters =
      '${_note('C', 4)}${_note('D', 4)}${_note('E', 4)}${_note('F', 4)}';
  String eighth(String step) => _note(step, 4, duration: 1, type: 'eighth');
  final eighths = [
    for (final step in 'CDEFGABC'.split('')) eighth(step),
  ].join();

  group('fingering', () {
    test('a finger is written at the note, changed and taken off', () {
      final xml = _score([quarters]);

      final one = _editor.setFingering(xml, _ref(1), 3).xml;
      expect(_editor.describe(one, _ref(1)).fingering, '3');
      expect(
        one,
        contains(
          '<notations><technical><fingering>3</fingering></technical></notations>',
        ),
      );
      expect(_editor.describe(one, _ref(0)).fingering, isNull);

      final other = _editor.setFingering(one, _ref(1), 1).xml;
      expect(_editor.describe(other, _ref(1)).fingering, '1');
      expect('<fingering>'.allMatches(other), hasLength(1));

      final none = _editor.setFingering(other, _ref(1), null).xml;
      expect(none, isNot(contains('<notations>')));
      expect(_codec.decodeXml(one).measureCount, 1);
    });

    test('each note of a chord has its own, and a rest has none', () {
      final xml = _score([
        '${_note('C', 4)}'
            '<note><chord/><pitch><step>E</step><octave>4</octave></pitch>'
            '<duration>2</duration><voice>1</voice><type>quarter</type></note>'
            '${_rest()}${_rest(duration: 4, type: 'half')}',
      ]);

      final low = _editor.setFingering(xml, _ref(0), 1).xml;
      final both = _editor.setFingering(low, _ref(1), 3).xml;

      expect(_editor.describe(both, _ref(0)).fingering, '1');
      expect(_editor.describe(both, _ref(1)).fingering, '3');
      expect(
        () => _editor.setFingering(xml, _ref(2), 2),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => _editor.setFingering(xml, _ref(0), 6),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('the other spelling of a note', () {
    test('a sharp is the flat above it, and back', () {
      final xml = _score([
        '${_note('F', 4, alter: 1)}${_note('B', 4, alter: -1)}'
            '${_note('E', 4)}${_note('C', 5)}',
      ]);

      final flat = _editor.respell(xml, _ref(0)).xml;
      expect(_read(flat).first, 'gb4');
      expect(_read(_editor.respell(flat, _ref(0)).xml).first, 'f#4');
      expect(_read(_editor.respell(xml, _ref(1)).xml)[1], 'a#4');
      // A plain note takes the neighbour a half step away; the octave
      // goes with the letter.
      expect(_read(_editor.respell(xml, _ref(2)).xml)[2], 'fb4');
      expect(_read(_editor.respell(xml, _ref(3)).xml)[3], 'b#4');
    });

    test('it sounds as before', () {
      final xml = _score([quarters]);
      for (var i = 0; i < 4; i++) {
        final before = _editor.describe(xml, _ref(i)).pitch!.midi;
        final after = _editor
            .describe(_editor.respell(xml, _ref(i)).xml, _ref(i))
            .pitch!
            .midi;
        expect(after, before, reason: 'note $i');
      }
    });
  });

  group('the slash of a grace note', () {
    test('goes and comes back', () {
      final graced = _editor.addGraceNote(_score([quarters]), _ref(1));
      expect(_editor.describe(graced.xml, graced.selection).graceSlash, isTrue);

      final plain = _editor.toggleGraceSlash(graced.xml, graced.selection).xml;
      expect(_editor.describe(plain, graced.selection).graceSlash, isFalse);
      expect(plain, contains('<grace/>'));
      final again = _editor.toggleGraceSlash(plain, graced.selection).xml;
      expect(_editor.describe(again, graced.selection).graceSlash, isTrue);
      expect(
        () => _editor.toggleGraceSlash(graced.xml, _ref(0)),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('a pickup bar', () {
    test('is said to be one, and an ordinary bar again', () {
      final xml = _score([_note('G', 4), quarters]);
      expect(_editor.barSigns(xml, 0, 0).pickup, isFalse);

      final pickup = _editor.setPickup(xml, 0, 0, pickup: true).xml;
      expect(_editor.barSigns(pickup, 0, 0).pickup, isTrue);
      expect(_editor.barSigns(pickup, 0, 1).pickup, isFalse);
      expect(pickup, contains('<measure number="1" implicit="yes">'));
      expect(_codec.decodeXml(pickup).measureCount, 2);

      final plain = _editor.setPickup(pickup, 0, 0, pickup: false).xml;
      expect(plain, isNot(contains('implicit')));
    });
  });

  group('beams', () {
    test('notes are joined under one beam', () {
      final xml = _score([eighths]);

      final joined = _editor.setBeam(xml, 0, 0, [0, 1, 2, 3], join: true).xml;

      expect(_beams(joined), 'begin continue continue end - - - -');
      expect(_codec.decodeXml(joined).measureCount, 1);
    });

    test('the first and last picked are enough: what lies between joins', () {
      final joined = _editor.setBeam(_score([eighths]), 0, 0, [
        4,
        7,
      ], join: true).xml;
      expect(_beams(joined), '- - - - begin continue continue end');
    });

    test('a note taken out of a beam leaves the others joined', () {
      final joined = _editor.setBeam(_score([eighths]), 0, 0, [
        0,
        3,
      ], join: true).xml;

      // The last of four: three stay joined.
      final three = _editor.setBeam(joined, 0, 0, [3], join: false).xml;
      expect(_beams(three), 'begin continue end - - - - -');
      // One of the middle: the one left alone has a flag of its own.
      final split = _editor.setBeam(joined, 0, 0, [1], join: false).xml;
      expect(_beams(split), '- - begin end - - - -');
    });

    test('joining notes of a beam into a shorter one splits the beam', () {
      final joined = _editor.setBeam(_score([eighths]), 0, 0, [
        0,
        3,
      ], join: true).xml;

      final pairs = _editor.setBeam(joined, 0, 0, [2, 3], join: true).xml;

      expect(_beams(pairs), 'begin end begin end - - - -');
    });

    test('quarters and rests take no beam', () {
      expect(
        () => _editor.setBeam(_score([quarters]), 0, 0, [0, 1], join: true),
        throwsA(isA<FormatException>()),
      );
      final gap = _score([
        '${eighth('C')}${_rest(duration: 1, type: 'eighth')}${eighth('E')}'
            '${eighth('F')}${_rest(duration: 4, type: 'half')}',
      ]);
      expect(
        () => _editor.setBeam(gap, 0, 0, [0, 2], join: true),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('picked notes made a tuplet', () {
    test(
      'three eighths read where a triplet was written set the bar right',
      () {
        // A quarter, three eighths, two quarters: an eighth too long.
        final xml = _score([
          '${_note('C', 4)}${eighth('D')}${eighth('E')}${eighth('F')}'
              '${_note('G', 4)}${_note('A', 4)}',
        ]);
        expect(
          _codec.decodeXml(xml).parts.first.measures.first.durationDivisions,
          9,
        );

        final result = _editor.groupTuplet(xml, 0, 0, [1, 2, 3]);

        final bar = _codec.decodeXml(result.xml).parts.first.measures.first;
        // The triplet takes one beat; the two quarters come an eighth
        // earlier and the bar is four beats.
        final divisions = bar.attributes.divisions;
        expect(bar.durationDivisions / divisions, 4);
        expect(
          [for (final note in bar.notes) note.onset / divisions],
          [0, 1, closeTo(4 / 3, 1e-9), closeTo(5 / 3, 1e-9), 2, 3],
        );
        expect(_read(result.xml), ['c4', 'd4', 'e4', 'f4', 'g4', 'a4']);
        expect('<time-modification>'.allMatches(result.xml), hasLength(3));
        expect(result.xml, contains('<tuplet type="start" bracket="yes"/>'));
        expect(result.xml, contains('<tuplet type="stop"/>'));
        expect(_editor.describe(result.xml, result.selection).inTuplet, isTrue);
        // It is taken apart again as any tuplet.
        expect(
          () => _editor.groupTuplet(result.xml, 0, 0, [1, 2, 3]),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test('in a bar that was full the freed time becomes a rest', () {
      final xml = _score([eighths]);

      final result = _editor.groupTuplet(xml, 0, 0, [0, 1, 2]);

      final bar = _codec.decodeXml(result.xml).parts.first.measures.first;
      expect(bar.durationDivisions / bar.attributes.divisions, 4);
      final notes = bar.notes.toList();
      expect(notes, hasLength(9));
      expect(notes.last.isRest, isTrue);
      expect(notes.last.duration / bar.attributes.divisions, 0.5);
    });

    test('the other staff of a piano bar stays where it is', () {
      const piano =
          '<?xml version="1.0" encoding="UTF-8"?>'
          '<score-partwise version="4.0"><part-list>'
          '<score-part id="P1"><part-name>Piano</part-name></score-part>'
          '</part-list><part id="P1"><measure number="1">'
          '<attributes><divisions>2</divisions><key><fifths>0</fifths></key>'
          '<time><beats>2</beats><beat-type>4</beat-type></time><staves>2</staves>'
          '<clef number="1"><sign>G</sign><line>2</line></clef>'
          '<clef number="2"><sign>F</sign><line>4</line></clef></attributes>';
      String up(String step, int duration, String type) =>
          '<note><pitch><step>$step</step><octave>5</octave></pitch>'
          '<duration>$duration</duration><voice>1</voice><type>$type</type>'
          '<staff>1</staff></note>';
      // Three eighths and a quarter over a half note: the upper staff is
      // an eighth too long, and the backup with it.
      final xml =
          '$piano${up('C', 1, 'eighth')}${up('D', 1, 'eighth')}'
          '${up('E', 1, 'eighth')}${up('F', 2, 'quarter')}'
          '<backup><duration>5</duration></backup>'
          '<note><pitch><step>C</step><octave>3</octave></pitch><duration>4</duration>'
          '<voice>5</voice><type>half</type><staff>2</staff></note>'
          '</measure></part></score-partwise>';

      final result = _editor.groupTuplet(xml, 0, 0, [0, 1, 2]);

      final bar = _codec.decodeXml(result.xml).parts.first.measures.first;
      final divisions = bar.attributes.divisions;
      final low = bar.notes.firstWhere((note) => note.staff == 2);
      expect(low.onset, 0);
      expect(bar.durationDivisions / divisions, 2);
      expect(
        [
          for (final note in bar.notes)
            if (note.staff == 1) note.onset / divisions,
        ],
        [0, closeTo(1 / 3, 1e-9), closeTo(2 / 3, 1e-9), 1],
      );
    });

    test('only notes of one value that follow one another', () {
      final xml = _score([
        '${eighth('C')}${eighth('D')}${_note('E', 4)}${eighth('F')}'
            '${eighth('G')}${_note('A', 4)}',
      ]);
      // A quarter among them.
      expect(
        () => _editor.groupTuplet(xml, 0, 0, [0, 1, 2]),
        throwsA(isA<FormatException>()),
      );
      // Not next to one another.
      expect(
        () => _editor.groupTuplet(xml, 0, 0, [0, 1, 3]),
        throwsA(isA<FormatException>()),
      );
      // One note is no group.
      expect(
        () => _editor.groupTuplet(xml, 0, 0, [0]),
        throwsA(isA<FormatException>()),
      );
      // Two are a duplet: in the time of three.
      final duplet = _editor.groupTuplet(xml, 0, 0, [0, 1]).xml;
      expect(duplet, contains('<actual-notes>2</actual-notes>'));
      expect(duplet, contains('<normal-notes>3</normal-notes>'));
    });
  });

  group('bars on a line', () {
    test('the lines break every so many bars, in place of the old breaks', () {
      final xml = _score([
        quarters,
        quarters,
        '<print new-system="yes"/>$quarters',
        quarters,
        '<print new-page="yes"/>$quarters',
        quarters,
      ]);
      expect(writtenLineStarts(xml, 0), [0, 2, 4]);

      final three = _editor.setBarsPerLine(xml, 0, 3).xml;
      expect(writtenLineStarts(three, 0), [0, 3]);
      expect(three, isNot(contains('new-page')));

      final none = _editor.setBarsPerLine(three, 0, null).xml;
      expect(writtenLineStarts(none, 0), isEmpty);
      expect(none, isNot(contains('<print')));
      expect(_codec.decodeXml(three).measureCount, 6);
    });
  });

  group('a chord tone by its pitch', () {
    test('is added where it is named, spelled as the key writes it', () {
      // Two flats: the black key above A is B flat.
      final xml = _score([quarters], fifths: -2);

      final added = _editor.addChordPitch(xml, _ref(0), 70);

      expect(_read(added.xml).first, 'c4+bb4');
      expect(added.selection.noteIndex, 1);
      expect(
        () => _editor.addChordPitch(added.xml, _ref(0), 70),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('a run of notes copied to another place', () {
    test('each note there takes the pitch and value of a copied one', () {
      final xml = _score([
        '${eighth('C')}${eighth('D')}${_note('E', 4)}'
            '${_rest()}${_note('G', 4)}',
        quarters,
      ]);

      final clip = _editor.copyNotes(xml, [_ref(0), _ref(1), _ref(2), _ref(3)]);
      expect(clip.length, 4);
      final pasted = _editor.pasteNotes(xml, _ref(0, measureIndex: 1), clip);

      // Two eighths in the place of the first quarter, then E, then the
      // rest; the last note of the bar is as it was.
      expect(_read(pasted.xml, measureIndex: 1), ['c4', 'd4', 'e4', 'r', 'f4']);
      final bar = _codec.decodeXml(pasted.xml).parts.first.measures[1];
      expect(bar.notes.map((note) => note.onset), [0, 1, 2, 4, 6]);
      expect(bar.durationDivisions, 8);
      // The bar it was copied from is untouched.
      expect(_read(pasted.xml), _read(xml));
    });

    test(
      'a chord is copied as a chord, and the run goes on over the barline',
      () {
        final xml = _score([
          '${_note('C', 4)}'
              '<note><chord/><pitch><step>E</step><octave>4</octave></pitch>'
              '<duration>2</duration><voice>1</voice><type>quarter</type></note>'
              '${_note('D', 4)}${_note('E', 4)}${_note('F', 4)}',
          quarters,
        ]);

        // The chord and the note after it, written from the last note of
        // bar 1 on.
        final clip = _editor.copyNotes(xml, [_ref(1), _ref(2)]);
        expect(clip.length, 2);
        final pasted = _editor.pasteNotes(xml, _ref(4), clip);

        expect(_read(pasted.xml), ['c4+e4', 'd4', 'e4', 'c4+e4']);
        expect(_read(pasted.xml, measureIndex: 1), ['d4', 'd4', 'e4', 'f4']);
        expect(pasted.selection, _ref(0, measureIndex: 1));
      },
    );

    test(
      'pasted as a notation program pastes, lengths flow over the barline',
      () {
        // Bar 1: a half note and two quarters. Bar 2 and 3: four quarters.
        final xml = _score([
          '${_note('C', 4, duration: 4, type: 'half')}${_note('D', 4)}${_note('E', 4)}',
          quarters,
          quarters,
        ]);

        // The half note and a quarter, written from the last quarter of bar
        // 2 on: the half note is cut at the barline and tied over.
        final clip = _editor.copyNotes(xml, [_ref(0), _ref(1)]);
        final pasted = _editor.pasteNotesFlowing(
          xml,
          _ref(3, measureIndex: 1),
          clip,
        );

        expect(_read(pasted.xml, measureIndex: 1), ['c4', 'd4', 'e4', 'c4']);
        // A quarter of C tied in, the copied D, and the bar goes on as it
        // was: its third and fourth notes.
        expect(_read(pasted.xml, measureIndex: 2), ['c4', 'd4', 'e4', 'f4']);
        final bars = _codec.decodeXml(pasted.xml).parts.first.measures;
        expect(bars[1].notes.last.tieStart, isTrue);
        expect(bars[2].notes.first.tieStop, isTrue);
        expect(bars[2].notes.map((n) => n.onset), [0, 2, 4, 6]);
        for (final bar in bars) {
          expect(bar.durationDivisions / bar.attributes.divisions, 4);
        }
        // The first bar is untouched, and the first pasted note is picked.
        expect(_read(pasted.xml), _read(xml));
        expect(pasted.selection, _ref(3, measureIndex: 1));
      },
    );

    test('a note the copied ones cut into leaves a rest; what follows stays', () {
      final xml = _score([
        '${eighth('C')}${eighth('D')}${_note('E', 4)}'
            '${_note('F', 4, duration: 4, type: 'half')}',
        '${_note('G', 4, duration: 4, type: 'half')}${_note('A', 4)}${_note('B', 4)}',
      ]);

      // Three eighths' worth (C, D, and the quarter E) over the half note
      // G: it covers a beat and a half... two eighths and a quarter.
      final clip = _editor.copyNotes(xml, [_ref(0), _ref(1), _ref(2)]);
      final pasted = _editor.pasteNotesFlowing(
        xml,
        _ref(0, measureIndex: 1),
        clip,
      );

      // C D E take the half note's two beats exactly; A and B stay.
      expect(_read(pasted.xml, measureIndex: 1), [
        'c4',
        'd4',
        'e4',
        'a4',
        'b4',
      ]);
      final bar = _codec.decodeXml(pasted.xml).parts.first.measures[1];
      expect(bar.notes.map((n) => n.onset), [0, 1, 2, 4, 6]);

      // Two eighths over a quarter in the middle of a half note cut it:
      // the rest of the half is a rest.
      final two = _editor.copyNotes(xml, [_ref(0), _ref(1)]);
      final cut = _editor.pasteNotesFlowing(xml, _ref(3), two);
      expect(_read(cut.xml), ['c4', 'd4', 'e4', 'c4', 'd4', 'r']);
    });

    test('a chord, two staves or a tuplet is not for flowing', () {
      final chord = _score([
        '${_note('C', 4)}'
            '<note><chord/><pitch><step>E</step><octave>4</octave></pitch>'
            '<duration>2</duration><voice>1</voice><type>quarter</type></note>'
            '${_note('D', 4)}${_note('E', 4)}${_note('F', 4)}',
      ]);
      final clip = _editor.copyNotes(chord, [_ref(0)]);
      expect(
        () => _editor.pasteNotesFlowing(chord, _ref(2), clip),
        throwsA(isA<FormatException>()),
      );
      // The note-for-note paste takes it.
      expect(_read(_editor.pasteNotes(chord, _ref(2), clip).xml)[1], 'c4+e4');
    });

    test('more than there is room for stops at the end', () {
      final xml = _score([quarters]);
      final clip = _editor.copyNotes(xml, [
        for (var i = 0; i < 4; i++) _ref(i),
      ]);

      final pasted = _editor.pasteNotes(xml, _ref(2), clip);

      expect(_read(pasted.xml), ['c4', 'd4', 'c4', 'd4']);
    });
  });

  group('how notes look', () {
    test('a stem is told where to stand, hidden, and left alone again', () {
      final xml = _score([quarters]);

      final up = _editor.setStem(xml, _ref(0), 'up').xml;
      expect(_editor.describe(up, _ref(0)).stem, 'up');
      expect(_notes(up).first.getElement('stem')?.innerText, 'up');
      final none = _editor.setStem(up, _ref(0), 'none').xml;
      expect(_editor.describe(none, _ref(0)).stem, 'none');
      final auto = _editor.setStem(none, _ref(0), null).xml;
      expect(auto, isNot(contains('<stem>')));
      expect(
        () => _editor.setStem(xml, _ref(0), 'sideways'),
        throwsA(isA<FormatException>()),
      );
      expect(_codec.decodeXml(none).measureCount, 1);
    });

    test('a notehead is a slash or stands in parentheses', () {
      final xml = _score([quarters]);

      final slash = _editor.setNotehead(xml, _ref(1), 'slash').xml;
      expect(_editor.describe(slash, _ref(1)).notehead, 'slash');
      expect(slash, contains('<notehead>slash</notehead>'));
      final ghost = _editor.setNotehead(slash, _ref(1), 'parentheses').xml;
      expect(_editor.describe(ghost, _ref(1)).notehead, 'parentheses');
      expect('<notehead'.allMatches(ghost), hasLength(1));
      final plain = _editor.setNotehead(ghost, _ref(1), null).xml;
      expect(plain, isNot(contains('<notehead')));
      expect(_read(ghost), _read(xml));
    });

    test('marks go above or below, and all come off at once', () {
      var xml = _score([quarters]);
      xml = _editor.toggleArticulation(xml, _ref(0), 'staccato').xml;
      xml = _editor.toggleArticulation(xml, _ref(0), 'accent').xml;
      xml = _editor.toggleArticulation(xml, _ref(0), 'fermata').xml;

      final below = _editor.setMarkPlacement(xml, _ref(0), 'below').xml;
      expect(below, contains('<staccato placement="below"/>'));
      expect(below, contains('<accent placement="below"/>'));
      expect(below, contains('<fermata type="inverted"/>'));
      final auto = _editor.setMarkPlacement(below, _ref(0), null).xml;
      expect(auto, isNot(contains('placement=')));
      expect(auto, contains('<fermata/>'));

      final clear = _editor.clearMarks(below, _ref(0)).xml;
      expect(clear, isNot(contains('<notations>')));
      expect(
        () => _editor.clearMarks(clear, _ref(0)),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => _editor.setMarkPlacement(clear, _ref(0), 'above'),
        throwsA(isA<FormatException>()),
      );
    });

    test('the slides of a jazz player are written like other marks', () {
      final xml = _editor
          .toggleArticulation(_score([quarters]), _ref(2), 'falloff')
          .xml;
      expect(xml, contains('<articulations><falloff/></articulations>'));
      expect(_editor.describe(xml, _ref(2)).articulations, {'falloff'});
      expect(
        _editor.toggleArticulation(xml, _ref(2), 'falloff').xml,
        isNot(contains('falloff')),
      );
    });

    test('an accidental comes off: the note is what the key says', () {
      // Two flats; the first note is B natural, the second E natural.
      final xml = _score([
        '${_note('B', 4)}${_note('E', 4)}${_note('F', 4, alter: 1)}'
            '${_note('G', 4)}',
      ], fifths: -2);

      expect(_read(_editor.clearAccidental(xml, _ref(0)).xml).first, 'bb4');
      expect(_read(_editor.clearAccidental(xml, _ref(1)).xml)[1], 'eb4');
      expect(_read(_editor.clearAccidental(xml, _ref(2)).xml)[2], 'f4');
      expect(
        () => _editor.clearAccidental(xml, _ref(3)),
        throwsA(isA<FormatException>()),
      );
    });

    test('a note is doubled a third above, an octave below', () {
      final xml = _score([quarters], fifths: 2);

      final third = _editor.doubleAt(xml, _ref(1), 2);
      // D with the F of the key above it: F sharp.
      expect(_read(third.xml)[1], 'd4+f#4');
      expect(third.selection, _ref(1));
      final octave = _editor.doubleAt(xml, _ref(0), -7).xml;
      expect(_read(octave).first, 'c4+c3');
      expect(
        () => _editor.doubleAt(third.xml, _ref(1), 2),
        throwsA(isA<FormatException>()),
      );
    });

    test('a rest is hidden and shown again; it still counts', () {
      final xml = _score([
        '${_note('C', 4)}${_rest()}${_note('E', 4)}${_note('F', 4)}',
      ]);

      final hidden = _editor.toggleHidden(xml, _ref(1)).xml;
      expect(_editor.describe(hidden, _ref(1)).hidden, isTrue);
      expect(_notes(hidden)[1].getAttribute('print-object'), 'no');
      final bar = _codec.decodeXml(hidden).parts.first.measures.first;
      expect(bar.notes.map((n) => n.onset), [0, 2, 4, 6]);
      final shown = _editor.toggleHidden(hidden, _ref(1)).xml;
      expect(shown, isNot(contains('print-object')));
    });

    test(
      'a written time or key signature is hidden; an unwritten one is not',
      () {
        final xml = _score([quarters, quarters]);

        final hidden = _editor.toggleSignatureHidden(xml, 0, 0).xml;
        expect(hidden, contains('<time print-object="no">'));
        expect(hidden, isNot(contains('<key print-object')));
        expect(
          _editor.toggleSignatureHidden(hidden, 0, 0).xml,
          isNot(contains('print-object')),
        );
        expect(
          _editor.toggleSignatureHidden(xml, 0, 0, key: true).xml,
          contains('<key print-object="no">'),
        );
        // Bar 2 states none of its own.
        expect(
          () => _editor.toggleSignatureHidden(xml, 0, 1),
          throwsA(isA<FormatException>()),
        );
        expect(_codec.decodeXml(hidden).measureCount, 2);
      },
    );

    test('several empty bars go in at once', () {
      final xml = _score([quarters, eighths]);

      final result = _editor.insertMeasures(xml, 0, 0, 3);

      final bars = _codec.decodeXml(result.xml).parts.first.measures;
      expect(bars, hasLength(5));
      expect(_read(result.xml), ['c4', 'd4', 'e4', 'f4']);
      for (final index in [1, 2, 3]) {
        expect(_read(result.xml, measureIndex: index), ['r']);
      }
      expect(bars[4].notes, hasLength(8));
      expect(result.selection, _ref(0, measureIndex: 1));
    });

    test('a caesura is written like a breath mark', () {
      final xml = _editor
          .toggleArticulation(_score([quarters]), _ref(3), 'caesura')
          .xml;
      expect(xml, contains('<articulations><caesura/></articulations>'));
      expect(_editor.describe(xml, _ref(3)).articulations, {'caesura'});
    });

    test('a bar is filled with rhythm slashes under its chord symbols', () {
      const chord =
          '<harmony><root><root-step>G</root-step></root><kind>major</kind></harmony>';
      final xml = _score([
        quarters,
        '${_note('C', 4)}${_note('D', 4)}$chord${_note('E', 4)}${_note('F', 4)}',
      ]);

      final result = _editor.fillWithSlashes(xml, 0, 1, 1);

      final bar = _notes(result.xml, measureIndex: 1);
      expect(bar, hasLength(4));
      for (final note in bar) {
        expect(note.getElement('notehead')?.innerText, 'slash');
        expect(note.getElement('stem')?.innerText, 'none');
        expect(note.getElement('type')?.innerText, 'quarter');
      }
      // The chord symbol is where it was: on the third beat.
      final measure = XmlDocument.parse(
        result.xml,
      ).findAllElements('measure').elementAt(1);
      final order = [
        for (final child in measure.childElements)
          if (child.name.local == 'note' || child.name.local == 'harmony')
            child.name.local,
      ];
      expect(order, ['note', 'note', 'harmony', 'note', 'note']);
      // The bar before is untouched and the file still reads.
      expect(_read(result.xml), ['c4', 'd4', 'e4', 'f4']);
      final decoded = _codec.decodeXml(result.xml).parts.first.measures[1];
      expect(decoded.notes.map((n) => n.onset), [0, 2, 4, 6]);
    });

    test('a fermata is short, usual or long by its shape', () {
      final xml = _score([quarters]);

      final long = _editor.setFermataShape(xml, _ref(3), 'square').xml;
      expect(long, contains('<fermata>square</fermata>'));
      expect(_editor.describe(long, _ref(3)).fermataShape, 'square');
      expect(_editor.describe(long, _ref(3)).fermata, isTrue);
      final usual = _editor.setFermataShape(long, _ref(3), 'normal').xml;
      expect(usual, contains('<fermata/>'));
      expect(_editor.describe(usual, _ref(3)).fermataShape, 'normal');
      expect(_editor.describe(xml, _ref(3)).fermataShape, isNull);
    });

    test('a repeat is played as many times as its sign says', () {
      final xml = _editor
          .toggleRepeat(_score([quarters, quarters]), 0, 1, start: false)
          .xml;

      final three = _editor.setRepeatTimes(xml, 0, 1, 3).xml;
      expect(three, contains('times="3"'));
      expect(three, contains('<words>3x</words>'));
      expect(writtenRepeatOrder(_codec.decodeXml(three)), [0, 1, 0, 1, 0, 1]);
      // Four in place of three, then twice again: nothing is written.
      final four = _editor.setRepeatTimes(three, 0, 1, 4).xml;
      expect('<words>'.allMatches(four), hasLength(1));
      expect(four, contains('<words>4x</words>'));
      final twice = _editor.setRepeatTimes(four, 0, 1, 2).xml;
      expect(twice, isNot(contains('times=')));
      expect(twice, isNot(contains('<words>')));
      expect(
        () => _editor.setRepeatTimes(xml, 0, 0, 3),
        throwsA(isA<FormatException>()),
      );
    });

    test('a double whole note is a value like the others', () {
      final wide = _score([
        '<attributes><time><beats>4</beats><beat-type>2</beat-type></time></attributes>'
            '${_note('C', 4, duration: 8, type: 'whole')}'
            '${_note('D', 4, duration: 8, type: 'whole')}',
      ]);

      final result = _editor.setDuration(wide, _ref(0), 'breve', 0).xml;

      expect(_notes(result).first.getElement('type')?.innerText, 'breve');
      final bar = _codec.decodeXml(result).parts.first.measures.first;
      expect(bar.notes.first.duration, 16);
    });

    test('the two voices of a staff change places', () {
      String voiced(String step, int octave, String voice) =>
          '<note><pitch><step>$step</step><octave>$octave</octave></pitch>'
          '<duration>4</duration><voice>$voice</voice><type>half</type>'
          '<stem>${voice == '1' ? 'up' : 'down'}</stem></note>';
      final xml = _score([
        '${voiced('E', 5, '1')}${voiced('D', 5, '1')}'
            '<backup><duration>8</duration></backup>'
            '${voiced('C', 4, '2')}${voiced('B', 3, '2')}',
      ]);

      final swapped = _editor.swapVoices(xml, _ref(0)).xml;

      expect(
        [
          for (final note in _notes(swapped))
            note.getElement('voice')!.innerText,
        ],
        ['2', '2', '1', '1'],
      );
      expect(swapped, isNot(contains('<stem>')));
      expect(_read(swapped), _read(xml));
      // A staff with one voice has nothing to change places with.
      expect(
        () => _editor.swapVoices(_score([quarters]), _ref(0)),
        throwsA(isA<FormatException>()),
      );
    });

    test('a note goes to the other staff and stays in its voice', () {
      const piano =
          '<?xml version="1.0" encoding="UTF-8"?>'
          '<score-partwise version="4.0"><part-list>'
          '<score-part id="P1"><part-name>Piano</part-name></score-part>'
          '</part-list><part id="P1"><measure number="1">'
          '<attributes><divisions>1</divisions><key><fifths>0</fifths></key>'
          '<time><beats>4</beats><beat-type>4</beat-type></time><staves>2</staves>'
          '<clef number="1"><sign>G</sign><line>2</line></clef>'
          '<clef number="2"><sign>F</sign><line>4</line></clef></attributes>'
          '<note><pitch><step>C</step><octave>4</octave></pitch><duration>2</duration>'
          '<voice>1</voice><type>half</type><staff>1</staff></note>'
          '<note><pitch><step>E</step><octave>4</octave></pitch><duration>2</duration>'
          '<voice>1</voice><type>half</type><staff>1</staff></note>'
          '<backup><duration>4</duration></backup>'
          '<note><pitch><step>C</step><octave>3</octave></pitch><duration>4</duration>'
          '<voice>5</voice><type>whole</type><staff>2</staff></note>'
          '</measure></part></score-partwise>';

      final moved = _editor.switchStaff(piano, _ref(0)).xml;

      expect(_editor.describe(moved, _ref(0)).staff, 2);
      expect(_editor.describe(moved, _ref(1)).staff, 1);
      expect(_notes(moved).first.getElement('voice')?.innerText, '1');
      expect(
        _editor
            .describe(_editor.switchStaff(moved, _ref(0)).xml, _ref(0))
            .staff,
        1,
      );
      // A part of one staff has no other staff.
      expect(
        () => _editor.switchStaff(_score([quarters]), _ref(0)),
        throwsA(isA<FormatException>()),
      );
    });
  });

  test('none of it breaks the file', () {
    var xml = _score([eighths, quarters]);
    xml = _editor.setFingering(xml, _ref(0), 2).xml;
    xml = _editor.respell(xml, _ref(3)).xml;
    xml = _editor.setBeam(xml, 0, 0, [0, 3], join: true).xml;
    xml = _editor.setPickup(xml, 0, 0, pickup: true).xml;
    xml = _editor.setBarsPerLine(xml, 0, 1).xml;
    final score = _codec.decodeXml(xml);
    expect(score.measureCount, 2);
    expect(score.parts.first.measures.first.notes, hasLength(8));
    expect(
      score.parts.first.measures.first.notes
          .map((n) => n.pitch)
          .whereType<MusicPitch>(),
      hasLength(8),
    );
  });
}
