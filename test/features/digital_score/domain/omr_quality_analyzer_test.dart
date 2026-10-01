import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_quality_analyzer.dart';

void main() {
  const analyzer = OmrQualityAnalyzer();
  const codec = MusicXmlCodec();

  test('flags a short 4/4 measure as V001', () {
    const xml = '''
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Music</part-name></score-part></part-list>
  <part id="P1"><measure number="1">
    <attributes><divisions>1</divisions>
      <key><fifths>0</fifths></key>
      <time><beats>4</beats><beat-type>4</beat-type></time>
      <clef><sign>G</sign><line>2</line></clef>
    </attributes>
    <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><type>quarter</type></note>
    <note><pitch><step>D</step><octave>4</octave></pitch><duration>1</duration><type>quarter</type></note>
    <note><pitch><step>E</step><octave>4</octave></pitch><duration>1</duration><type>quarter</type></note>
  </measure></part>
</score-partwise>
''';
    final report = analyzer.analyze(codec.decodeXml(xml), sourceXml: xml);
    expect(report.issues.any((issue) => issue.rule == 'V001'), isTrue);
    expect(report.score, lessThan(100));
  });

  test('flags missing chord symbols and lyrics', () {
    const xml = '''
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Music</part-name></score-part></part-list>
  <part id="P1"><measure number="1">
    <attributes><divisions>1</divisions>
      <key><fifths>0</fifths></key>
      <time><beats>4</beats><beat-type>4</beat-type></time>
      <clef><sign>G</sign><line>2</line></clef>
    </attributes>
    <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><type>whole</type></note>
  </measure></part>
</score-partwise>
''';
    final report = analyzer.analyze(codec.decodeXml(xml), sourceXml: xml);
    expect(report.issues.any((issue) => issue.rule == 'V009'), isTrue);
    expect(report.issues.any((issue) => issue.rule == 'V010'), isTrue);
  });

  test('does not flag a filled 4/4 bar for duration', () {
    const xml = '''
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Music</part-name></score-part></part-list>
  <part id="P1"><measure number="1">
    <attributes><divisions>1</divisions>
      <key><fifths>-1</fifths></key>
      <time><beats>4</beats><beat-type>4</beat-type></time>
      <clef><sign>G</sign><line>2</line></clef>
    </attributes>
    <harmony><root><root-step>F</root-step></root><kind>major</kind></harmony>
    <note><pitch><step>F</step><octave>4</octave></pitch><duration>4</duration><type>whole</type>
      <lyric><syllabic>single</syllabic><text>la</text></lyric>
    </note>
  </measure></part>
</score-partwise>
''';
    final report = analyzer.analyze(codec.decodeXml(xml), sourceXml: xml);
    expect(report.issues.any((issue) => issue.rule == 'V001'), isFalse);
    expect(report.issues.any((issue) => issue.rule == 'V009'), isFalse);
    expect(report.issues.any((issue) => issue.rule == 'V010'), isFalse);
  });

  test('does not flag an octave leap as a pitch outlier', () {
    const xml = '''
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Music</part-name></score-part></part-list>
  <part id="P1"><measure number="1">
    <attributes><divisions>1</divisions>
      <key><fifths>0</fifths></key>
      <time><beats>4</beats><beat-type>4</beat-type></time>
      <clef><sign>G</sign><line>2</line></clef>
    </attributes>
    <harmony><root><root-step>C</root-step></root><kind>major</kind></harmony>
    <note><pitch><step>C</step><octave>4</octave></pitch><duration>2</duration><type>half</type>
      <lyric><syllabic>single</syllabic><text>la</text></lyric></note>
    <note><pitch><step>C</step><octave>5</octave></pitch><duration>2</duration><type>half</type></note>
  </measure></part>
</score-partwise>
''';
    final report = analyzer.analyze(codec.decodeXml(xml), sourceXml: xml);
    expect(report.issues.any((issue) => issue.rule == 'V006'), isFalse);
  });
}
