import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/performance_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';

// Two bars, the first repeated, with a triplet the editing model does not
// write back.
const _xml = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>V</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>6</divisions><time><beats>4</beats><beat-type>4</beat-type></time><clef><sign>G</sign><line>2</line></clef></attributes>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>2</duration><voice>1</voice><type>eighth</type><time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes></time-modification></note>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>2</duration><voice>1</voice><type>eighth</type><time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes></time-modification></note>
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>2</duration><voice>1</voice><type>eighth</type><time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes></time-modification></note>
      <note><rest/><duration>18</duration><voice>1</voice><type>half</type><dot/></note>
      <barline location="right"><bar-style>light-heavy</bar-style><repeat direction="backward"/></barline>
    </measure>
    <measure number="2">
      <note><pitch><step>G</step><octave>4</octave></pitch><duration>24</duration><voice>1</voice><type>whole</type></note>
    </measure>
  </part>
</score-partwise>
''';

void main() {
  const codec = MusicXmlCodec();

  test('lays the file out in playing order with its tuplets', () {
    final score = codec.decodeXml(_xml);
    final laidOut = playbackMusicXml(_xml, score, PlaybackSequence.empty)!;

    final played = codec.decodeXml(laidOut);
    expect(played.measureCount, 3);
    expect(played.parts.single.measures.any((m) => m.repeatEnd), isFalse);
    expect(RegExp('<time-modification').allMatches(laidOut).length, 6);
  });

  test('a file that plays in order is used as it is', () {
    final plain = _xml.replaceAll(RegExp(r'<barline[\s\S]*?</barline>'), '');
    final score = codec.decodeXml(plain);
    expect(playbackMusicXml(plain, score, PlaybackSequence.empty), isNull);
  });

  test('a custom order lays out the chosen sections', () {
    final score = codec.decodeXml(_xml);
    final sequence = PlaybackSequence(
      marks: [
        SectionMark(startMeasureIndex: 0, name: 'A'),
        SectionMark(startMeasureIndex: 1, name: 'B'),
      ],
      steps: [
        PlaybackStep(sectionId: sectionIdAt(1)),
        PlaybackStep(sectionId: sectionIdAt(0), repeats: 2),
      ],
    );
    final played = codec.decodeXml(playbackMusicXml(_xml, score, sequence)!);
    expect(
      played.parts.single.measures.map((m) => m.notes.first.pitch?.step.name),
      ['g', 'c', 'c'],
    );
  });
}
