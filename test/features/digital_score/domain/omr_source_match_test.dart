import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_source_match.dart';

void main() {
  test('extracts RoadPiano glyph chords and hangul lyrics from PDF text', () {
    const pdf = '''
DMÞ
C©‹Þ
F©‹Þ
Stay
in
the
middle
말
해
줘
RoadPiano
Tempo
''';
    final chords = extractReferenceChords(pdf);
    expect(chords, containsAll(['D', 'C#m', 'F#m']));
    final lyrics = extractReferenceLyrics(pdf);
    expect(lyrics, containsAll(['middle', '말', '해', '줘']));
    expect(lyrics, isNot(contains('roadpiano')));
  });

  test('scores chord and lyric recall against MusicXML', () {
    const xml = '''
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Music</part-name></score-part></part-list>
  <part id="P1"><measure number="1">
    <attributes><divisions>1</divisions>
      <key><fifths>0</fifths></key>
      <time><beats>4</beats><beat-type>4</beat-type></time>
      <clef><sign>G</sign><line>2</line></clef>
    </attributes>
    <harmony><root><root-step>D</root-step></root><kind>major</kind></harmony>
    <harmony><root><root-step>C</root-step><root-alter>1</root-alter></root><kind>minor</kind></harmony>
    <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration><type>whole</type>
      <lyric><syllabic>single</syllabic><text>middle</text></lyric>
      <lyric number="2"><syllabic>single</syllabic><text>말</text></lyric>
    </note>
  </measure></part>
</score-partwise>
''';
    const pdf = 'DMÞ C©‹Þ F©‹Þ middle 말 해 줘';
    final score = const MusicXmlCodec().decodeXml(xml);
    final match = OmrSourceMatch.compare(
      referenceText: pdf,
      score: score,
      musicXml: xml,
    );
    expect(match.chordRefCount, greaterThan(0));
    expect(match.chordHitCount, greaterThan(0));
    expect(match.lyricHitCount, greaterThan(0));
    expect(match.combined, isNotNull);
  });
}
