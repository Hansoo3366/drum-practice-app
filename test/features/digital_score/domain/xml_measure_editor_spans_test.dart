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
  bool chord = false,
}) =>
    '<note>${chord ? '<chord/>' : ''}<pitch><step>$step</step>'
    '${alter == 0 ? '' : '<alter>$alter</alter>'}'
    '<octave>$octave</octave></pitch><duration>$duration</duration>'
    '<voice>1</voice><type>$type</type>$extra<staff>1</staff></note>';

String _rest({int duration = 1, String type = 'quarter'}) =>
    '<note><rest/><duration>$duration</duration><voice>1</voice>'
    '<type>$type</type><staff>1</staff></note>';

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
        '<attributes><divisions>1</divisions>'
        '<key><fifths>$fifths</fifths></key>'
        '<time><beats>4</beats><beat-type>4</beat-type></time>'
        '<clef><sign>G</sign><line>2</line></clef></attributes>',
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

XmlElement _measure(String xml, {int measureIndex = 0}) =>
    XmlDocument.parse(xml).findAllElements('measure').elementAt(measureIndex);

List<XmlElement> _notes(String xml, {int measureIndex = 0}) =>
    _measure(xml, measureIndex: measureIndex).findElements('note').toList();

String? _pitchOf(XmlElement note) {
  final pitch = note.getElement('pitch');
  if (pitch == null) return null;
  final alter = pitch.getElement('alter')?.innerText ?? '0';
  return '${pitch.getElement('step')!.innerText}:$alter:'
      '${pitch.getElement('octave')!.innerText}';
}

/// The names of the bar's children, with the type of a span mark.
List<String> _layout(String xml, {int measureIndex = 0}) => [
  for (final child in _measure(xml, measureIndex: measureIndex).childElements)
    if (child.name.local == 'direction')
      'direction:${child.findAllElements('*').where((e) => e.getAttribute('type') != null).map((e) => '${e.name.local}=${e.getAttribute('type')}').join(',')}'
    else if (child.name.local != 'attributes')
      child.name.local,
];

void main() {
  final four =
      '${_note('C', 5)}${_note('D', 5)}${_note('E', 5)}${_note('F', 5)}';

  group('slurs', () {
    test('a slur is drawn between two notes and taken away from either', () {
      final xml = _score([four]);

      final slurred = _editor.addSpan(xml, _ref(0), _ref(2), SpanKind.slur);

      final notes = _notes(slurred.xml);
      expect(
        notes[0]
            .getElement('notations')
            ?.getElement('slur')
            ?.getAttribute('type'),
        'start',
      );
      expect(
        notes[2]
            .getElement('notations')
            ?.getElement('slur')
            ?.getAttribute('type'),
        'stop',
      );
      expect(_editor.describe(slurred.xml, _ref(0)).spans, {SpanKind.slur});
      expect(_editor.describe(slurred.xml, _ref(1)).spans, isEmpty);
      expect(_editor.describe(slurred.xml, _ref(2)).spans, {SpanKind.slur});
      expect(slurred.selection.noteIndex, 2);

      final cleared = _editor.removeSpan(slurred.xml, _ref(2), SpanKind.slur);
      expect(_measure(cleared.xml).findAllElements('slur'), isEmpty);
      expect(_measure(cleared.xml).findAllElements('notations'), isEmpty);
    });

    test('the two notes may be picked in either order, and over a barline', () {
      final xml = _score([four, four]);

      final result = _editor.addSpan(
        xml,
        _ref(1, measureIndex: 1),
        _ref(3),
        SpanKind.slur,
      );

      expect(
        _notes(
          result.xml,
        )[3].getElement('notations')?.getElement('slur')?.getAttribute('type'),
        'start',
      );
      expect(
        _notes(
          result.xml,
          measureIndex: 1,
        )[1].getElement('notations')?.getElement('slur')?.getAttribute('type'),
        'stop',
      );
    });

    test('slurs that overlap get different numbers', () {
      final xml = _score([four]);

      var result = _editor.addSpan(xml, _ref(0), _ref(3), SpanKind.slur);
      result = _editor.addSpan(result.xml, _ref(1), _ref(2), SpanKind.slur);

      final numbers = [
        for (final slur in _measure(result.xml).findAllElements('slur'))
          '${slur.getAttribute('type')}${slur.getAttribute('number')}',
      ];
      expect(numbers, ['start1', 'start2', 'stop2', 'stop1']);

      // Taking the inner one away leaves the outer one whole.
      final inner = _editor.removeSpan(result.xml, _ref(1), SpanKind.slur);
      expect(_editor.describe(inner.xml, _ref(0)).spans, {SpanKind.slur});
      expect(_editor.describe(inner.xml, _ref(3)).spans, {SpanKind.slur});
      expect(_measure(inner.xml).findAllElements('slur'), hasLength(2));
    });

    test('a slur needs two notes, not a rest', () {
      final xml = _score([
        '${_note('C', 5)}${_rest()}${_note('E', 5)}${_note('F', 5)}',
      ]);

      expect(
        () => _editor.addSpan(xml, _ref(0), _ref(0), SpanKind.slur),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => _editor.addSpan(xml, _ref(0), _ref(1), SpanKind.slur),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => _editor.removeSpan(xml, _ref(0), SpanKind.slur),
        throwsA(isA<FormatException>()),
      );
    });

    test('a note that goes takes its slur along, both ends', () {
      final xml = _score([four]);
      final slurred = _editor.addSpan(xml, _ref(0), _ref(2), SpanKind.slur).xml;

      expect(
        _measure(
          _editor.removeNote(slurred, _ref(2)).xml,
        ).findAllElements('slur'),
        isEmpty,
      );
      expect(
        _measure(
          _editor.deleteNote(slurred, _ref(0)).xml,
        ).findAllElements('slur'),
        isEmpty,
      );
    });
  });

  group('lines between notes', () {
    test('a hairpin opens before its first note and closes after its last', () {
      final xml = _score([four]);

      final result = _editor.addSpan(xml, _ref(1), _ref(2), SpanKind.crescendo);

      expect(_layout(result.xml), [
        'note',
        'direction:wedge=crescendo',
        'note',
        'note',
        'direction:wedge=stop',
        'note',
      ]);
      expect(_editor.describe(result.xml, _ref(1)).spans, {SpanKind.crescendo});
      expect(_editor.describe(result.xml, _ref(2)).spans, {SpanKind.crescendo});
      expect(_editor.describe(result.xml, _ref(3)).spans, isEmpty);
      expect(() => _codec.decodeXml(result.xml), returnsNormally);

      final cleared = _editor.removeSpan(
        result.xml,
        _ref(2),
        SpanKind.crescendo,
      );
      expect(_layout(cleared.xml), ['note', 'note', 'note', 'note']);
    });

    test('a diminuendo is not taken for a crescendo', () {
      final xml = _score([four]);
      final result = _editor.addSpan(
        xml,
        _ref(0),
        _ref(3),
        SpanKind.diminuendo,
      );

      expect(_editor.describe(result.xml, _ref(3)).spans, {
        SpanKind.diminuendo,
      });
      expect(
        () => _editor.removeSpan(result.xml, _ref(0), SpanKind.crescendo),
        throwsA(isA<FormatException>()),
      );
    });

    test('the pedal goes down at one note and up after another', () {
      final xml = _score([four, four]);

      final result = _editor.addSpan(
        xml,
        _ref(0),
        _ref(3, measureIndex: 1),
        SpanKind.pedal,
      );

      expect(_layout(result.xml).first, 'direction:pedal=start');
      expect(_layout(result.xml, measureIndex: 1).last, 'direction:pedal=stop');
      expect(_editor.describe(result.xml, _ref(3, measureIndex: 1)).spans, {
        SpanKind.pedal,
      });
      final cleared = _editor.removeSpan(result.xml, _ref(0), SpanKind.pedal);
      expect(XmlDocument.parse(cleared.xml).findAllElements('pedal'), isEmpty);
    });

    test('under 8va the notes stay on their lines and sound an octave up', () {
      final xml = _score([four]);

      final result = _editor.addSpan(xml, _ref(1), _ref(2), SpanKind.octaveUp);

      expect(_notes(result.xml).map(_pitchOf), [
        'C:0:5',
        'D:0:6',
        'E:0:6',
        'F:0:5',
      ]);
      final shift = _measure(result.xml).findAllElements('octave-shift').first;
      // MusicXML: the written notes are moved down.
      expect(
        (shift.getAttribute('type'), shift.getAttribute('size')),
        ('down', '8'),
      );
      expect(_editor.describe(result.xml, _ref(1)).spans, {SpanKind.octaveUp});

      final cleared = _editor.removeSpan(
        result.xml,
        _ref(2),
        SpanKind.octaveUp,
      );
      expect(_notes(cleared.xml).map(_pitchOf), [
        'C:0:5',
        'D:0:5',
        'E:0:5',
        'F:0:5',
      ]);
      expect(_measure(cleared.xml).findAllElements('octave-shift'), isEmpty);
    });

    test('8vb lowers what sounds', () {
      final xml = _score([four]);

      final result = _editor.addSpan(
        xml,
        _ref(0),
        _ref(0),
        SpanKind.octaveDown,
      );

      expect(_pitchOf(_notes(result.xml)[0]), 'C:0:4');
      expect(_pitchOf(_notes(result.xml)[1]), 'D:0:5');
    });
  });

  group('ornaments', () {
    test('a trill, a mordent and a tremolo go on and off', () {
      final xml = _score([four]);

      var result = _editor.toggleOrnament(xml, _ref(0), 'trill-mark');
      result = _editor.toggleOrnament(result.xml, _ref(0), 'tremolo');
      expect(_editor.describe(result.xml, _ref(0)).ornaments, {
        'trill-mark',
        'tremolo',
      });
      expect(
        _notes(result.xml)[0].findAllElements('tremolo').single.innerText,
        '3',
      );

      result = _editor.toggleOrnament(result.xml, _ref(0), 'trill-mark');
      result = _editor.toggleOrnament(result.xml, _ref(0), 'tremolo');
      expect(_editor.describe(result.xml, _ref(0)).ornaments, isEmpty);
      expect(_notes(result.xml)[0].getElement('notations'), isNull);
    });

    test('an arpeggio is written on every note of the chord', () {
      final xml = _score([
        '${_note('C', 4)}${_note('E', 4, chord: true)}${_note('G', 4, chord: true)}'
            '${_note('D', 5)}${_note('E', 5)}${_note('F', 5)}',
      ]);

      final result = _editor.toggleOrnament(xml, _ref(1), 'arpeggiate');

      expect(_measure(result.xml).findAllElements('arpeggiate'), hasLength(3));
      expect(_editor.describe(result.xml, _ref(0)).ornaments, {'arpeggiate'});
      expect(
        _measure(
          _editor.toggleOrnament(result.xml, _ref(2), 'arpeggiate').xml,
        ).findAllElements('arpeggiate'),
        isEmpty,
      );
      expect(
        () => _editor.toggleOrnament(xml, _ref(3), 'arpeggiate'),
        throwsA(isA<FormatException>()),
      );
    });

    test('a breath mark is written with the articulations', () {
      final xml = _score([four]);

      final result = _editor.toggleArticulation(xml, _ref(1), 'breath-mark');

      expect(_editor.describe(result.xml, _ref(1)).articulations, {
        'breath-mark',
      });
    });
  });

  group('entering a pitch', () {
    test('a piano key is spelled as the key signature writes it', () {
      expect(spellMidi(61, 2), 'C#4');
      expect(spellMidi(61, -3), 'Db4');
      expect(spellMidi(70, 0), 'Bb4');
      expect(spellMidi(60, 0), 'C4');

      final sharp = _score([four], fifths: 1);
      final flat = _score([four], fifths: -1);
      expect(
        _pitchOf(_notes(_editor.enterPitch(sharp, _ref(0), 66).xml)[0]),
        'F:1:4',
      );
      expect(
        _pitchOf(_notes(_editor.enterPitch(flat, _ref(0), 70).xml)[0]),
        'B:-1:4',
      );
      // B♭ is in the key of F: no accidental is written for it.
      expect(
        _notes(
          _editor.enterPitch(flat, _ref(0), 70).xml,
        )[0].getElement('accidental'),
        isNull,
      );
    });

    test('a rest becomes a note of the key that was pressed', () {
      final xml = _score([
        '${_rest(duration: 2, type: 'half')}${_note('E', 5)}${_note('F', 5)}',
      ]);

      final result = _editor.enterPitch(xml, _ref(0), 67);

      final note = _notes(result.xml)[0];
      expect(_pitchOf(note), 'G:0:4');
      expect(note.getElement('type')?.innerText, 'half');
      expect(
        () => _editor.enterPitch(result.xml, _ref(0), 67),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'a note is put on a line of the staff, sharp or flat as the key says',
      () {
        final xml = _score([
          '${_rest()}${_note('D', 5)}${_note('E', 5)}${_note('F', 5)}',
        ], fifths: 1);

        final onRest = _editor.placeNote(xml, _ref(0), PitchStep.f, 5);
        expect(_pitchOf(_notes(onRest.xml)[0]), 'F:1:5');
        expect(_notes(onRest.xml)[0].getElement('accidental'), isNull);

        final moved = _editor.placeNote(xml, _ref(1), PitchStep.g, 4);
        expect(_pitchOf(_notes(moved.xml)[1]), 'G:0:4');
      },
    );
  });

  group('verses', () {
    test('each verse has its own syllable on a note', () {
      final xml = _score([four]);

      var result = _editor.setLyric(xml, _ref(0), '주');
      result = _editor.setLyric(result.xml, _ref(0), '나', verse: 2);

      expect(_editor.describe(result.xml, _ref(0)).lyrics, {1: '주', 2: '나'});
      expect(_editor.describe(result.xml, _ref(0)).lyric, '주');

      result = _editor.setLyric(result.xml, _ref(0), '', verse: 1);
      expect(_editor.describe(result.xml, _ref(0)).lyrics, {2: '나'});
    });
  });
}
