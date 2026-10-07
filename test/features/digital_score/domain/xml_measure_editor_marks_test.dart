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
  int staff = 1,
  String voice = '1',
}) =>
    '<note><pitch><step>$step</step>${alter == 0 ? '' : '<alter>$alter</alter>'}'
    '<octave>$octave</octave></pitch><duration>$duration</duration>$extra'
    '<voice>$voice</voice><type>$type</type><staff>$staff</staff></note>';

String _rest({int duration = 1, String type = 'quarter'}) =>
    '<note><rest/><duration>$duration</duration><voice>1</voice>'
    '<type>$type</type><staff>1</staff></note>';

String _score(
  List<String> measures, {
  int divisions = 1,
  int fifths = 0,
  int staves = 2,
  String time = '<beats>4</beats><beat-type>4</beat-type>',
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
        '<time>$time</time>'
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

XmlElement _measure(String xml, {int measureIndex = 0}) =>
    XmlDocument.parse(xml).findAllElements('measure').elementAt(measureIndex);

String? _pitchOf(XmlElement note) {
  final pitch = note.getElement('pitch');
  if (pitch == null) return null;
  final alter = pitch.getElement('alter')?.innerText ?? '0';
  return '${pitch.getElement('step')!.innerText}:$alter:'
      '${pitch.getElement('octave')!.innerText}';
}

/// Onset and duration of each note of a voice after decoding.
List<(int, int)> _timeline(String xml, String voice, {int measureIndex = 0}) {
  final score = _codec.decodeXml(xml);
  return [
    for (final note in score.parts.first.measures[measureIndex].notes)
      if (note.voice == voice && !note.isChord) (note.onset, note.duration),
  ];
}

String _types(String xml) => [
  for (final note in _notes(xml))
    '${note.getElement('rest') != null ? 'r' : ''}'
        '${note.getElement('type')?.innerText}'
        '${'.' * note.findElements('dot').length}',
].join(' ');

void main() {
  final fourQuarters =
      '${_note('C', 5)}${_note('D', 5)}${_note('E', 5)}${_note('F', 5)}$_bass';

  group('splitting and removing', () {
    test('a quarter splits into two eighths of its pitch', () {
      final xml = _score([fourQuarters]);

      final result = _editor.splitNote(xml, _ref(1));

      expect(_types(result.xml), 'quarter eighth eighth quarter quarter whole');
      expect(_notes(result.xml).map(_pitchOf).take(3), [
        'C:0:5',
        'D:0:5',
        'D:0:5',
      ]);
      expect(_timeline(result.xml, '1'), [
        (0, 2),
        (2, 1),
        (3, 1),
        (4, 2),
        (6, 2),
      ]);
      expect(_timeline(result.xml, '5'), [(0, 8)]);
      expect(result.selection.noteIndex, 1);
    });

    test('a dotted note splits into the note and its dot', () {
      final xml = _score([
        '${_note('C', 5, duration: 3, type: 'quarter', extra: '<dot/>')}'
            '${_note('D', 5, type: 'eighth')}${_note('E', 5, duration: 4, type: 'half')}$_bass',
      ], divisions: 2);

      final result = _editor.splitNote(xml, _ref(0));

      expect(_types(result.xml), 'quarter eighth eighth half whole');
      expect(_timeline(result.xml, '1'), [(0, 2), (2, 1), (3, 1), (4, 4)]);
    });

    test('words stay on the first half and a tie leaves from the second', () {
      final xml =
          _score([
            '${_note('C', 5, extra: '<tie type="start"/>', duration: 2, type: 'half')}'
                '${_note('C', 5, extra: '<tie type="stop"/>', duration: 2, type: 'half')}$_bass',
          ]).replaceFirst(
            '<staff>1</staff></note>',
            '<staff>1</staff><lyric><text>la</text></lyric></note>',
          );

      final result = _editor.splitNote(xml, _ref(0));

      final notes = _notes(result.xml);
      expect(notes[0].findElements('lyric'), hasLength(1));
      expect(notes[1].findElements('lyric'), isEmpty);
      expect(notes[0].findElements('tie'), isEmpty);
      expect(notes[1].getElement('tie')?.getAttribute('type'), 'start');
      expect(notes[2].getElement('tie')?.getAttribute('type'), 'stop');
      expect(() => _codec.decodeXml(result.xml), returnsNormally);
    });

    test('removing a note closes the bar up and ends it in a rest', () {
      final xml = _score([fourQuarters]);

      final result = _editor.removeNote(xml, _ref(1));

      expect(_notes(result.xml).map(_pitchOf).take(4), [
        'C:0:5',
        'E:0:5',
        'F:0:5',
        null,
      ]);
      expect(_types(result.xml), 'quarter quarter quarter rquarter whole');
      expect(_timeline(result.xml, '1'), [(0, 1), (1, 1), (2, 1), (3, 1)]);
      expect(_timeline(result.xml, '5'), [(0, 4)]);
    });

    test('removing the only note leaves a bar of rest', () {
      final xml = _score([
        '${_note('C', 5, duration: 4, type: 'whole')}$_bass',
      ]);

      final result = _editor.removeNote(xml, _ref(0));

      expect(_types(result.xml), 'rwhole whole');
      expect(_timeline(result.xml, '5'), [(0, 4)]);
    });

    test('a short bar only gets shorter, and its backup follows', () {
      final xml = _score([
        '${_note('C', 5)}${_note('D', 5)}'
            '<backup><duration>2</duration></backup>'
            '${_note('G', 2, duration: 2, type: 'half', staff: 2, voice: '5')}',
      ]);

      final result = _editor.removeNote(xml, _ref(1));

      expect(_types(result.xml), 'quarter half');
      expect(
        _measure(
          result.xml,
        ).getElement('backup')?.getElement('duration')?.innerText,
        '1',
      );
    });

    test('a grace note is removed, by either tool', () {
      final xml = _score([
        '<note><grace slash="yes"/><pitch><step>D</step><octave>5</octave></pitch>'
            '<voice>1</voice><type>eighth</type><staff>1</staff></note>$fourQuarters',
      ]);

      expect(
        _types(_editor.removeNote(xml, _ref(0)).xml),
        'quarter quarter quarter quarter whole',
      );
      expect(
        _types(_editor.deleteNote(xml, _ref(0)).xml),
        'quarter quarter quarter quarter whole',
      );
    });
  });

  group('inserting', () {
    test('a rest after the note takes the room of the rest at the end', () {
      final xml = _score([
        '${_note('C', 5)}${_note('D', 5)}${_note('E', 5)}${_rest()}$_bass',
      ]);

      final result = _editor.insertEvent(
        xml,
        _ref(0),
        before: false,
        rest: true,
      );

      expect(_types(result.xml), 'quarter rquarter quarter quarter whole');
      expect(_timeline(result.xml, '1'), [(0, 1), (1, 1), (2, 1), (3, 1)]);
      expect(_timeline(result.xml, '5'), [(0, 4)]);
      expect(result.selection.noteIndex, 1);
    });

    test('a note before the note has its pitch; a long rest is shortened', () {
      final xml = _score([
        '${_note('C', 5)}${_note('D', 5)}${_rest(duration: 2, type: 'half')}$_bass',
      ]);

      final result = _editor.insertEvent(
        xml,
        _ref(1),
        before: true,
        rest: false,
      );

      expect(_types(result.xml), 'quarter quarter quarter rquarter whole');
      expect(_notes(result.xml).map(_pitchOf).take(3), [
        'C:0:5',
        'D:0:5',
        'D:0:5',
      ]);
      expect(result.selection.noteIndex, 1);
    });

    test('a full bar with no rest to give refuses', () {
      final xml = _score([fourQuarters]);

      expect(
        () => _editor.insertEvent(xml, _ref(0), before: false, rest: true),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('자리'),
          ),
        ),
      );
    });

    test('a pickup bar grows and its backup with it', () {
      final xml = _score([
        '${_note('C', 5)}<backup><duration>1</duration></backup>'
            '${_note('G', 2, staff: 2, voice: '5')}',
      ]);

      final result = _editor.insertEvent(
        xml,
        _ref(0),
        before: true,
        rest: true,
      );

      expect(_types(result.xml), 'rquarter quarter quarter');
      expect(
        _measure(
          result.xml,
        ).getElement('backup')?.getElement('duration')?.innerText,
        '2',
      );
      expect(_timeline(result.xml, '5'), [(0, 1)]);
    });
  });

  group('tuplets', () {
    test('a quarter becomes a triplet of eighths', () {
      final xml = _score([fourQuarters]);

      final result = _editor.makeTuplet(xml, _ref(1), 3, 2);

      expect(
        _types(result.xml),
        'quarter eighth eighth eighth quarter quarter whole',
      );
      final notes = _notes(result.xml);
      for (final note in notes.sublist(1, 4)) {
        expect(
          note
              .getElement('time-modification')
              ?.getElement('actual-notes')
              ?.innerText,
          '3',
        );
        expect(
          note
              .getElement('time-modification')
              ?.getElement('normal-notes')
              ?.innerText,
          '2',
        );
        expect(_pitchOf(note), 'D:0:5');
      }
      expect(
        notes[1]
            .getElement('notations')
            ?.getElement('tuplet')
            ?.getAttribute('type'),
        'start',
      );
      expect(
        notes[3]
            .getElement('notations')
            ?.getElement('tuplet')
            ?.getAttribute('type'),
        'stop',
      );
      expect(_timeline(result.xml, '1'), [
        (0, 3),
        (3, 1),
        (4, 1),
        (5, 1),
        (6, 3),
        (9, 3),
      ]);
      expect(_timeline(result.xml, '5'), [(0, 12)]);
      expect(() => _codec.decodeXml(result.xml), returnsNormally);
    });

    test('a quintuplet is written in sixteenths', () {
      final xml = _score([fourQuarters]);

      final result = _editor.makeTuplet(xml, _ref(0), 5, 4);

      expect(
        _types(result.xml),
        '16th 16th 16th 16th 16th quarter quarter quarter whole',
      );
      expect(_timeline(result.xml, '1').take(6), [
        (0, 1),
        (1, 1),
        (2, 1),
        (3, 1),
        (4, 1),
        (5, 5),
      ]);
    });

    test('a tuplet goes back to the one note it was', () {
      final xml = _score([fourQuarters]);
      final triplet = _editor.makeTuplet(xml, _ref(1), 3, 2).xml;

      final result = _editor.removeTuplet(triplet, _ref(2));

      expect(_types(result.xml), 'quarter quarter quarter quarter whole');
      expect(_notes(result.xml)[1].getElement('time-modification'), isNull);
      expect(_timeline(result.xml, '1'), [(0, 3), (3, 3), (6, 3), (9, 3)]);
      expect(result.selection.noteIndex, 1);
    });

    test('a tuplet member keeps its pitch tools but not its length tools', () {
      final xml = _score([fourQuarters]);
      final triplet = _editor.makeTuplet(xml, _ref(1), 3, 2).xml;

      expect(
        _pitchOf(_notes(_editor.moveDiatonic(triplet, _ref(2), 1).xml)[2]),
        'E:0:5',
      );
      expect(
        () => _editor.splitNote(triplet, _ref(2)),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => _editor.makeTuplet(triplet, _ref(2), 3, 2),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('ties', () {
    test('ties a note to the next of its pitch and unties it again', () {
      final xml = _score([
        '${_note('C', 5)}${_note('C', 5)}${_note('D', 5)}${_note('F', 5)}$_bass',
      ]);

      final tied = _editor.toggleTie(xml, _ref(0));

      final notes = _notes(tied.xml);
      expect(notes[0].getElement('tie')?.getAttribute('type'), 'start');
      expect(
        notes[0]
            .getElement('notations')
            ?.getElement('tied')
            ?.getAttribute('type'),
        'start',
      );
      expect(notes[1].getElement('tie')?.getAttribute('type'), 'stop');
      expect(_editor.describe(tied.xml, _ref(0)).tieStart, isTrue);

      final untied = _editor.toggleTie(tied.xml, _ref(0));
      expect(_notes(untied.xml)[0].findElements('tie'), isEmpty);
      expect(_notes(untied.xml)[1].findElements('tie'), isEmpty);
    });

    test('ties over the barline, and refuses a different pitch', () {
      final xml = _score([
        '${_note('C', 5)}${_note('D', 5)}${_note('E', 5)}${_note('F', 5)}$_bass',
        '${_note('F', 5)}${_note('G', 5)}${_note('A', 5)}${_note('B', 5)}$_bass',
      ]);

      final result = _editor.toggleTie(xml, _ref(3));
      expect(
        _notes(
          result.xml,
          measureIndex: 1,
        )[0].getElement('tie')?.getAttribute('type'),
        'stop',
      );

      expect(
        () => _editor.toggleTie(xml, _ref(0)),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('같은 높이'),
          ),
        ),
      );
    });
  });

  group('marks at a note', () {
    test('articulations and a fermata go on and off', () {
      final xml = _score([fourQuarters]);

      var result = _editor.toggleArticulation(xml, _ref(0), 'staccato');
      result = _editor.toggleArticulation(result.xml, _ref(0), 'accent');
      result = _editor.toggleArticulation(result.xml, _ref(0), 'fermata');

      final summary = _editor.describe(result.xml, _ref(0));
      expect(summary.articulations, {'staccato', 'accent'});
      expect(summary.fermata, isTrue);

      result = _editor.toggleArticulation(result.xml, _ref(0), 'staccato');
      result = _editor.toggleArticulation(result.xml, _ref(0), 'fermata');
      final after = _editor.describe(result.xml, _ref(0));
      expect(after.articulations, {'accent'});
      expect(after.fermata, isFalse);
      expect(() => _codec.decodeXml(result.xml), returnsNormally);
    });

    test('a rest takes a fermata but no staccato', () {
      final xml = _score(['${_rest(duration: 4, type: 'whole')}$_bass']);

      expect(
        _editor
            .describe(
              _editor.toggleArticulation(xml, _ref(0), 'fermata').xml,
              _ref(0),
            )
            .fermata,
        isTrue,
      );
      expect(
        () => _editor.toggleArticulation(xml, _ref(0), 'staccato'),
        throwsA(isA<FormatException>()),
      );
    });

    test('a dynamic is written, replaced and taken away', () {
      final xml = _score([fourQuarters]);

      final soft = _editor.setDynamic(xml, _ref(1), 'p');
      expect(_editor.describe(soft.xml, _ref(1)).dynamic, 'p');
      expect(_editor.describe(soft.xml, _ref(0)).dynamic, isNull);

      final loud = _editor.setDynamic(soft.xml, _ref(1), 'ff');
      expect(_editor.describe(loud.xml, _ref(1)).dynamic, 'ff');
      expect(_measure(loud.xml).findAllElements('dynamics'), hasLength(1));

      final none = _editor.setDynamic(loud.xml, _ref(1), null);
      expect(_measure(none.xml).findAllElements('dynamics'), isEmpty);
      expect(_timeline(none.xml, '1'), [(0, 1), (1, 1), (2, 1), (3, 1)]);
    });

    test('a grace note a step above is put before the note', () {
      final xml = _score([fourQuarters], fifths: 1);

      final result = _editor.addGraceNote(xml, _ref(2));

      final notes = _notes(result.xml);
      expect(notes[2].getElement('grace')?.getAttribute('slash'), 'yes');
      expect(_pitchOf(notes[2]), 'F:1:5');
      expect(_pitchOf(notes[3]), 'E:0:5');
      expect(result.selection.noteIndex, 2);
      expect(_timeline(result.xml, '1'), [
        (0, 1),
        (1, 1),
        (2, 0),
        (2, 1),
        (3, 1),
      ]);
    });
  });

  group('signs of a bar', () {
    test('a key signature is set and the accidentals follow it', () {
      final xml = _score([
        '${_note('F', 5, alter: 1, extra: '<accidental>sharp</accidental>')}${_note('G', 5)}'
            '${_note('A', 5)}${_note('B', 5)}$_bass',
        '${_note('F', 5, alter: 1, extra: '<accidental>sharp</accidental>')}${_note('G', 5)}'
            '${_note('A', 5)}${_note('B', 5)}$_bass',
      ]);

      final result = _editor.setKeySignature(xml, 0, 0, 1);

      final decoded = _codec.decodeXml(result.xml);
      expect(decoded.parts.first.measures[0].attributes.keyFifths, 1);
      expect(decoded.parts.first.measures[1].attributes.keyFifths, 1);
      // F♯ is in the key now: no accidental, in either bar.
      expect(_notes(result.xml)[0].getElement('accidental'), isNull);
      expect(
        _notes(result.xml, measureIndex: 1)[0].getElement('accidental'),
        isNull,
      );
      expect(_pitchOf(_notes(result.xml)[0]), 'F:1:5');
    });

    test('a time signature and a clef are set at the bar', () {
      final xml = _score([fourQuarters, fourQuarters]);

      var result = _editor.setTimeSignature(xml, 0, 1, 3, 4);
      result = _editor.setClef(result.xml, 0, 1, 1, 'F', 4);

      final decoded = _codec.decodeXml(result.xml);
      final second = decoded.parts.first.measures[1].attributes;
      expect((second.time?.beats, second.time?.beatType), (3, 4));
      expect((second.clefs[1]?.sign, second.clefs[1]?.line), ('F', 4));
      final first = decoded.parts.first.measures[0].attributes;
      expect((first.time?.beats, first.clefs[1]?.sign), (4, 'G'));
    });

    test('repeats, endings and barlines go on and off', () {
      final xml = _score([fourQuarters, fourQuarters, fourQuarters]);

      var result = _editor.toggleRepeat(xml, 0, 0, start: true);
      result = _editor.toggleEnding(result.xml, 0, 1, 1, start: true);
      result = _editor.toggleEnding(result.xml, 0, 1, 1, start: false);
      result = _editor.toggleRepeat(result.xml, 0, 1, start: false);
      result = _editor.toggleEnding(result.xml, 0, 2, 2, start: true);
      result = _editor.setBarStyle(result.xml, 0, 2, 'light-heavy');

      final decoded = _codec.decodeXml(result.xml);
      final bars = decoded.parts.first.measures;
      expect(bars[0].barlines.any((b) => b.repeat == 'forward'), isTrue);
      expect(bars[1].barlines.any((b) => b.repeat == 'backward'), isTrue);
      expect(bars[1].barlines.map((b) => b.endingNumbers).expand((n) => n), [
        1,
        1,
      ]);
      expect(bars[2].barlines.first.endingNumbers, [2]);
      final signs = _editor.barSigns(result.xml, 0, 1);
      expect(
        (signs.repeatEnd, signs.endingStart, signs.endingEnd),
        (true, 1, 1),
      );
      expect(_editor.barSigns(result.xml, 0, 2).barStyle, 'light-heavy');

      result = _editor.toggleRepeat(result.xml, 0, 0, start: true);
      result = _editor.toggleEnding(result.xml, 0, 1, 1, start: true);
      result = _editor.setBarStyle(result.xml, 0, 2, 'regular');
      expect(_measure(result.xml).findElements('barline'), isEmpty);
      expect(_editor.barSigns(result.xml, 0, 1).endingStart, isNull);
      expect(_editor.barSigns(result.xml, 0, 2).barStyle, 'regular');
    });

    test('navigation signs are written where the player reads them', () {
      final xml = _score([fourQuarters, fourQuarters]);

      var result = _editor.setNavigationSign(
        xml,
        0,
        0,
        NavigationSign.segno,
        on: true,
      );
      result = _editor.setNavigationSign(
        result.xml,
        0,
        1,
        NavigationSign.dcAlFine,
        on: true,
      );
      result = _editor.setNavigationSign(
        result.xml,
        0,
        1,
        NavigationSign.dsAlCoda,
        on: true,
      );

      final decoded = _codec.decodeXml(result.xml);
      final first = decoded.parts.first.measures[0].events
          .whereType<MusicDirection>();
      expect(first.map((d) => d.navigation), contains(MusicNavigation.segno));
      final second = decoded.parts.first.measures[1].events
          .whereType<MusicDirection>();
      expect(second.map((d) => d.navigation).toList(), [
        MusicNavigation.dalSegno,
      ]);
      expect(second.map((d) => d.words).toList(), ['D.S. al Coda']);
      // The jump stands after the notes of its bar.
      final children = _measure(
        result.xml,
        measureIndex: 1,
      ).childElements.map((e) => e.name.local).toList();
      expect(children.last, 'direction');
      expect(_editor.barSigns(result.xml, 0, 1).navigation, {
        NavigationSign.dsAlCoda,
      });

      result = _editor.setNavigationSign(
        result.xml,
        0,
        1,
        NavigationSign.dsAlCoda,
        on: false,
      );
      expect(_editor.barSigns(result.xml, 0, 1).navigation, isEmpty);
    });

    test('a rehearsal mark, a tempo and a text are written at the bar', () {
      final xml = _score([fourQuarters]);

      var result = _editor.setRehearsalMark(xml, 0, 0, 'Verse');
      result = _editor.setTempo(result.xml, 0, 0, 72, text: 'Andante');
      result = _editor.addWords(result.xml, 0, 0, 'rit.');

      final decoded = _codec.decodeXml(result.xml);
      final directions = decoded.parts.first.measures[0].events
          .whereType<MusicDirection>()
          .toList();
      expect(directions.map((d) => d.rehearsal).whereType<String>(), ['Verse']);
      expect(directions.map((d) => d.tempoBpm).whereType<double>(), [72]);
      expect(
        directions.map((d) => d.words).whereType<String>(),
        containsAll(['Andante', 'rit.']),
      );
      final signs = _editor.barSigns(result.xml, 0, 0);
      expect((signs.rehearsal, signs.tempoBpm), ('Verse', 72));

      result = _editor.setRehearsalMark(result.xml, 0, 0, '');
      result = _editor.setTempo(result.xml, 0, 0, null);
      final after = _editor.barSigns(result.xml, 0, 0);
      expect((after.rehearsal, after.tempoBpm), (null, null));
      expect(_editor.inspect(result.xml, 0, 0).texts, ['rit.']);
    });
  });
}
