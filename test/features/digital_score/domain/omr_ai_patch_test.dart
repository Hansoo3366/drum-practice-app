import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_ai_patch.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_ai_review.dart';
import 'package:xml/xml.dart';

const fixture = '''<?xml version="1.0"?><score-partwise version="4.0">
<part-list><score-part id="P1"><part-name>Piano</part-name></score-part><score-part id="P2"><part-name>Voice</part-name></score-part></part-list>
<part id="P1"><measure number="1"><attributes><divisions>8</divisions><key><fifths>0</fifths></key><time><beats>4</beats><beat-type>4</beat-type></time><clef><sign>G</sign><line>2</line></clef></attributes>
<direction><direction-type><words>Keep me</words></direction-type></direction>
<harmony><root><root-step>C</root-step></root><kind>major</kind></harmony>
<note id="existing"><pitch><step>C</step><octave>4</octave></pitch><duration>8</duration><type>quarter</type><staff>1</staff><lyric><text>la</text></lyric></note>
<note><rest/><duration>24</duration><type>half</type><dot/></note></measure></part>
<part id="P2"><measure number="1"><attributes><divisions>8</divisions></attributes><note><pitch><step>C</step><octave>4</octave></pitch><duration>8</duration><type>quarter</type></note></measure></part>
</score-partwise>''';

OmrAiCorrection correction({
  String id = 'p0_m0_n0',
  String property = 'pitch',
  String current = 'C:0:4',
  String suggested = 'D:1:4',
  double confidence = 0.9,
}) => OmrAiCorrection(
  elementId: id,
  property: property,
  currentValue: current,
  suggestedValue: suggested,
  confidence: confidence,
);

void main() {
  test(
    'preview isolates the exact part/measure and inherits previous attributes',
    () {
      final xml = fixture.replaceFirst(
        '</measure></part>',
        '</measure><measure number="2"><note><pitch><step>D</step><octave>4</octave></pitch><duration>8</duration><type>quarter</type></note></measure></part>',
      );
      final patch = OmrAiPatch(xml, 0, 1);
      final root = XmlDocument.parse(patch.previewXml(xml)).rootElement;
      expect(root.findElements('part'), hasLength(1));
      expect(
        root.findAllElements('measure').single.getAttribute('number'),
        '2',
      );
      expect(root.findAllElements('divisions').single.innerText, '8');
      expect(root.findAllElements('time'), hasLength(1));
      expect(root.findAllElements('score-part'), hasLength(1));
      expect(patch.sourceXml, xml);
    },
  );
  test('patches exact part and retains unknown XML and original IDs', () {
    final patch = OmrAiPatch(fixture, 1, 0);
    final result = patch.apply(fixture, [correction(id: 'p1_m0_n0')]);
    final root = XmlDocument.parse(result).rootElement;
    final parts = root.findElements('part').toList();
    expect(
      parts.first.toXmlString(),
      XmlDocument.parse(
        fixture,
      ).rootElement.findElements('part').first.toXmlString(),
    );
    expect(parts.last.findAllElements('step').single.innerText, 'D');
    expect(parts.last.findAllElements('alter').single.innerText, '1');
    expect(result, contains('Keep me'));
    expect(result, contains('<text>la</text>'));
    expect(result, contains('id="existing"'));
    expect(patch.prompt, contains('p1_m0_n0'));
    expect(patch.prompt, contains('Target part: P2'));
  });

  test('duration updates ticks, type, dots together', () {
    final result = OmrAiPatch(fixture, 0, 0).apply(fixture, [
      correction(
        property: 'duration',
        current: 'quarter',
        suggested: 'eighth.',
      ),
    ]);
    final note = XmlDocument.parse(result).findAllElements('note').first;
    expect(note.getElement('duration')!.innerText, '6');
    expect(note.getElement('type')!.innerText, 'eighth');
    expect(note.findElements('dot'), hasLength(1));
  });

  test(
    'stale snapshot, foreign ID, wrong current value and duplicates fail',
    () {
      final patch = OmrAiPatch(fixture, 0, 0);
      expect(
        () => patch.apply('$fixture ', [correction()]),
        throwsFormatException,
      );
      expect(
        () => patch.apply(fixture, [correction(id: 'p1_m0_n0')]),
        throwsFormatException,
      );
      expect(
        () => patch.apply(fixture, [correction(current: 'B:0:4')]),
        throwsFormatException,
      );
      expect(
        () => patch.apply(fixture, [correction(), correction()]),
        throwsFormatException,
      );
      expect(() => patch.apply(fixture, []), throwsFormatException);
    },
  );

  test('invalid, unchanged and unsupported suggestions fail closed', () {
    final patch = OmrAiPatch(fixture, 0, 0);
    for (final c in [
      correction(suggested: 'H:0:4'),
      correction(suggested: 'C:0:4'),
      correction(suggested: 'C:9:4'),
      correction(confidence: double.nan),
      correction(property: 'voice', current: '', suggested: '2'),
      correction(id: 'p0_m0_n1', current: 'rest'),
    ]) {
      expect(patch.rejection(c), isNotNull);
    }
  });

  for (final tag in [
    '<backup><duration>8</duration></backup>',
    '<forward><duration>8</duration></forward>',
    '<note><chord/><duration>8</duration></note>',
    '<note><grace/></note>',
    '<note><time-modification><actual-notes>3</actual-notes></time-modification></note>',
    '<note><tie type="start"/></note>',
  ]) {
    test('rejects complex duration $tag', () {
      final xml = fixture.replaceFirst('</measure>', '$tag</measure>');
      expect(
        OmrAiPatch(xml, 0, 0).rejection(
          correction(
            property: 'duration',
            current: 'quarter',
            suggested: 'half',
          ),
        ),
        isNotNull,
      );
    });
  }

  test('rejects pitch correction of tied notes', () {
    final xml = fixture.replaceFirst(
      '<duration>8</duration>',
      '<duration>8</duration><tie type="start"/>',
    );
    expect(OmrAiPatch(xml, 0, 0).rejection(correction()), isNotNull);
  });

  test('rejects unrepresentable duration ticks', () {
    final xml = fixture.replaceAll(
      '<divisions>8</divisions>',
      '<divisions>1</divisions>',
    );
    expect(
      OmrAiPatch(xml, 0, 0).rejection(
        correction(
          property: 'duration',
          current: 'quarter',
          suggested: 'eighth',
        ),
      ),
      isNotNull,
    );
  });

  test('uses divisions at the target note, not later in the measure', () {
    final xml = fixture.replaceFirst(
      '</note>',
      '</note><attributes><divisions>32</divisions></attributes>',
    );
    final result = OmrAiPatch(xml, 0, 0).apply(xml, [
      correction(property: 'duration', current: 'quarter', suggested: 'eighth'),
    ]);
    expect(
      XmlDocument.parse(
        result,
      ).findAllElements('note').first.getElement('duration')!.innerText,
      '4',
    );
  });
}
