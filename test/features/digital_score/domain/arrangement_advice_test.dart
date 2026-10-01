import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_advice.dart';
import 'package:page_a_diddle/features/digital_score/domain/three_staff_arrangement.dart';
import 'package:xml/xml.dart';

String _note(
  String step,
  int octave,
  int duration, {
  int alter = 0,
  String extra = '',
}) =>
    '<note><pitch><step>$step</step>${alter == 0 ? '' : '<alter>$alter</alter>'}'
    '<octave>$octave</octave></pitch>'
    '<duration>$duration</duration>$extra<voice>1</voice></note>';

String _chord(String root, {String kind = 'major', String text = ''}) =>
    '<harmony placement="above"><root><root-step>$root</root-step></root>'
    '<kind text="$text">$kind</kind></harmony>';

// G major, 4/4, a quarter note is 4 divisions.
final _xml =
    '<score-partwise version="4.0"><part-list><score-part id="P1">'
    '<part-name>Voice</part-name></score-part></part-list><part id="P1">'
    '<measure number="1"><attributes><divisions>4</divisions><key><fifths>1</fifths></key>'
    '<time><beats>4</beats><beat-type>4</beat-type></time></attributes>'
    '${_chord('F')}${_note('B', 4, 8)}${_chord('E', kind: 'minor-seventh', text: 'm7')}'
    '${_note('G', 4, 4)}${_note('F', 4, 2, alter: 1)}'
    '${_note('E', 4, 2)}</measure>'
    '<measure number="2">${_chord('C', kind: 'none')}'
    '<note><rest/><duration>16</duration><voice>1</voice></note></measure>'
    '<measure number="3"><harmony><root><root-step>D</root-step></root><kind>dominant</kind>'
    '<offset>8</offset></harmony>${_note('D', 5, 16, extra: '<tie type="start"/>')}</measure>'
    '<measure number="4">${_note('D', 5, 16, extra: '<tie type="stop"/>')}</measure>'
    '</part></score-partwise>';

void main() {
  test('the brief names key, time, sections and every bar', () {
    final brief = arrangementBrief(
      _xml,
      tempoBpm: 72.4,
      sections: [(name: 'verse1', start: 1, end: 2)],
    );

    expect(
      brief,
      'key signature: 1 sharps (G major or E minor)\n'
      'time: 4/4\n'
      'tempo: 72 bpm\n'
      'bars: 4\n'
      'sections: verse1 1-2\n'
      'bar: chords (in order) | melody notes\n'
      '1: F Em7 | B4 G4 F#4 E4 (8ths)\n'
      '2: N.C. | rest\n'
      '3: D7 | D5 (long notes)\n'
      // The tied note goes on: nothing new is sung.
      '4: - | rest\n',
    );
  });

  test('advice that does not fit the score is dropped', () {
    final advice = ArrangementAdvice.fromJson({
      'base': {'pattern': 'broken', 'register': 'low'},
      'sections': [
        {'bar': 3, 'pattern': 'beats', 'register': 'middle'},
        {'bar': 9, 'pattern': 'beats', 'register': 'middle'},
        {'bar': 2, 'pattern': 'stride', 'register': 'middle'},
      ],
      'chords': [
        {'bar': 1, 'index': 1, 'suggested': 'D/F#', 'reason': 'G장조'},
        // The same chord, no chord there, unreadable text, no such bar.
        {'bar': 1, 'index': 2, 'suggested': 'Em7', 'reason': ''},
        {'bar': 1, 'index': 3, 'suggested': 'C', 'reason': ''},
        {'bar': 3, 'index': 1, 'suggested': 'H7', 'reason': ''},
        {'bar': 7, 'index': 1, 'suggested': 'C', 'reason': ''},
      ],
      'note': '잔잔한 곡',
    }, _xml);

    expect(
      advice.plan.base,
      const AccompanimentStyle(
        pattern: AccompanimentPattern.broken,
        register: AccompanimentRegister.low,
      ),
    );
    expect(advice.plan.sections, {
      2: const AccompanimentStyle(pattern: AccompanimentPattern.beats),
    });
    expect(
      advice.corrections.map(
        (c) => (c.measureIndex, c.chordIndex, c.current, c.suggested, c.reason),
      ),
      [(0, 0, 'F', 'D/F#', 'G장조')],
    );
    expect(advice.note, '잔잔한 곡');
    // An empty or broken answer is the default style.
    final none = ArrangementAdvice.fromJson({'base': 'x'}, _xml);
    expect(none.plan.base, const AccompanimentStyle());
    expect(none.corrections, isEmpty);
  });

  test('accepted corrections rewrite the chord symbols in place', () {
    final out = applyChordCorrections(_xml, const [
      ChordCorrection(
        measureIndex: 0,
        chordIndex: 0,
        current: 'F',
        suggested: 'D/F#',
      ),
      ChordCorrection(
        measureIndex: 2,
        chordIndex: 0,
        current: 'D7',
        suggested: 'Dsus4',
      ),
      // Out of range: passed over.
      ChordCorrection(
        measureIndex: 3,
        chordIndex: 0,
        current: '',
        suggested: 'C',
      ),
    ]);

    final harmonies = XmlDocument.parse(
      out,
    ).findAllElements('harmony').toList();
    expect(harmonies.map(harmonyTextOf), ['D/F#', 'Em7', '', 'Dsus4']);
    // Placement and beat are kept.
    expect(harmonies[0].getAttribute('placement'), 'above');
    expect(harmonies[3].getElement('offset')?.innerText, '8');
    expect(harmonies[3].childElements.map((e) => e.name.local), [
      'root',
      'kind',
      'offset',
    ]);
    // The notes are untouched, and the piano part follows the new chords.
    expect(
      XmlDocument.parse(out).findAllElements('note').length,
      XmlDocument.parse(_xml).findAllElements('note').length,
    );
    final piano = XmlDocument.parse(
      threeStaffMusicXml(out),
    ).rootElement.findElements('part').last;
    final firstBass = piano
        .findElements('measure')
        .first
        .findElements('note')
        .firstWhere((n) => n.getElement('staff')?.innerText == '2');
    expect(firstBass.getElement('pitch')?.getElement('step')?.innerText, 'F');
    expect(firstBass.getElement('pitch')?.getElement('alter')?.innerText, '1');
    expect(applyChordCorrections(_xml, const []), same(_xml));
  });
}
