import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';

void main() {
  const codec = MusicXmlCodec();

  group('MusicXmlCodec', () {
    test('decodes piano metadata, grand staff timing, chords, and harmony', () {
      final score = codec.decodeXml(_pianoMusicXml);

      expect(score.title, 'Autumn Test');
      expect(score.composer, 'Test Composer');
      expect(score.tempoBpm, 96);
      expect(score.parts, hasLength(1));
      expect(score.measureCount, 1);
      expect(score.noteCount, 4);

      final measure = score.parts.single.measures.single;
      expect(measure.attributes.divisions, 4);
      expect(measure.attributes.keyFifths, -1);
      expect(measure.attributes.time?.beats, 4);
      expect(measure.attributes.time?.beatType, 4);
      expect(measure.attributes.staves, 2);
      expect(measure.attributes.clefs[1]?.sign, 'G');
      expect(measure.attributes.clefs[2]?.sign, 'F');
      expect(measure.durationDivisions, 8);

      final notes = measure.notes.toList();
      expect(notes.map((note) => note.onset), [0, 0, 4, 0]);
      expect(notes.map((note) => note.voice), ['1', '1', '1', '2']);
      expect(notes[1].isChord, isTrue);
      expect(notes[2].isRest, isTrue);
      expect(notes[3].staff, 2);

      final direction = measure.events.whereType<MusicDirection>().single;
      expect(direction.rehearsal, 'INTRO');
      expect(direction.tempoBpm, 96);
      final harmony = measure.events.whereType<MusicHarmony>().single;
      expect(harmony.rootStep, PitchStep.b);
      expect(harmony.rootAlter, -1);
      expect(harmony.kind, 'major');
    });

    test('round-trips supported MusicXML data with multi-voice backup', () {
      final first = codec.decodeXml(_pianoMusicXml);
      final encoded = codec.encodeMusicXml(first);
      final xml = utf8.decode(encoded);
      final second = codec.decode(encoded, fileName: 'roundtrip.musicxml');

      expect(xml, contains('<backup>'));
      expect(xml, contains('<duration>8</duration>'));
      expect(xml, contains('id="p0-m0-e'));
      expect(second.title, first.title);
      expect(second.composer, first.composer);
      expect(second.tempoBpm, first.tempoBpm);
      expect(second.noteCount, first.noteCount);
      expect(second.parts.single.measures.single.attributes.staves, 2);
      expect(
        second.parts.single.measures.single.notes.map((note) => note.onset),
        [0, 0, 4, 0],
      );
    });

    test('omits repeated clef key and time on later measures', () {
      final score = codec.decodeXml('''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 4.0 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>1</divisions>
        <key><fifths>0</fifths></key>
        <time><beats>4</beats><beat-type>4</beat-type></time>
        <staves>2</staves>
        <clef number="1"><sign>G</sign><line>2</line></clef>
        <clef number="2"><sign>F</sign><line>4</line></clef>
      </attributes>
      <note><rest/><duration>4</duration><voice>1</voice><type>whole</type><staff>1</staff></note>
    </measure>
    <measure number="2">
      <note><rest/><duration>4</duration><voice>1</voice><type>whole</type><staff>1</staff></note>
    </measure>
    <measure number="3">
      <attributes>
        <key><fifths>1</fifths></key>
      </attributes>
      <note><rest/><duration>4</duration><voice>1</voice><type>whole</type><staff>1</staff></note>
    </measure>
  </part>
</score-partwise>
''');
      final xml = utf8.decode(codec.encodeMusicXml(score));
      final measures = RegExp(
        r'<measure number="(\d+)">([\s\S]*?)</measure>',
      ).allMatches(xml).toList();
      expect(measures, hasLength(3));
      expect(measures[0].group(2), contains('<clef'));
      expect(measures[0].group(2), contains('<key>'));
      expect(measures[0].group(2), contains('<time'));
      expect(measures[1].group(2), isNot(contains('<clef')));
      expect(measures[1].group(2), isNot(contains('<key>')));
      expect(measures[1].group(2), isNot(contains('<time')));
      expect(measures[1].group(2), isNot(contains('<attributes>')));
      expect(measures[2].group(2), contains('<key>'));
      expect(measures[2].group(2), contains('<fifths>1</fifths>'));
      expect(measures[2].group(2), isNot(contains('<clef')));
      expect(measures[2].group(2), isNot(contains('<time')));
    });

    test('preserves alla breve notation separately from numeric 2/2', () {
      final source = _pianoMusicXml
          .replaceFirst('<time>', '<time symbol="cut">')
          .replaceFirst('<beats>4</beats>', '<beats>2</beats>')
          .replaceFirst('<beat-type>4</beat-type>', '<beat-type>2</beat-type>');
      final score = codec.decodeXml(source);
      final time = score.parts.single.measures.single.attributes.time;

      expect(time?.beats, 2);
      expect(time?.beatType, 2);
      expect(time?.symbol, MusicTimeSymbol.cut);
      expect(
        utf8.decode(codec.encodeMusicXml(score)),
        contains('<time symbol="cut">'),
      );
    });

    test('encodes and decodes a standard compressed MXL container', () {
      final score = codec.decodeXml(_pianoMusicXml);
      final encoded = codec.encode(score, MusicXmlFileFormat.mxl);
      final archive = ZipDecoder().decodeBytes(encoded);

      expect(archive.first.name, 'mimetype');
      expect(archive.first.compression, CompressionType.none);
      expect(
        ascii.decode(archive.first.content),
        MusicXmlCodec.compressedMimeType,
      );
      expect(archive.find('META-INF/container.xml'), isNotNull);
      expect(archive.find('score.musicxml'), isNotNull);

      final decoded = codec.decode(encoded, fileName: 'score.mxl');
      expect(decoded.title, 'Autumn Test');
      expect(decoded.noteCount, 4);
    });

    test('rejects unsafe MXL root paths', () {
      final archive = Archive()
        ..add(
          ArchiveFile.string(
            'META-INF/container.xml',
            '<?xml version="1.0"?>'
                '<container><rootfiles><rootfile full-path="../score.musicxml"/>'
                '</rootfiles></container>',
          ),
        )
        ..add(ArchiveFile.string('score.musicxml', _pianoMusicXml));
      final bytes = ZipEncoder().encodeBytes(archive);

      expect(
        () => codec.decode(bytes, fileName: 'unsafe.mxl'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('Unsafe MXL path'),
          ),
        ),
      );
    });

    test('rejects score-timewise files with a clear compatibility error', () {
      expect(
        () => codec.decodeXml(
          '<?xml version="1.0"?><score-timewise version="4.0"/>',
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            '이 악보 형식은 열 수 없습니다',
          ),
        ),
      );
    });

    test('rejects OpenLyrics song XML as lyrics, not a score', () {
      expect(
        () => codec.decodeXml('''
<?xml version="1.0" encoding="UTF-8"?>
<song xmlns="http://openlyrics.info/namespace/2009/song" version="0.8">
  <properties><titles><title>Test Hymn</title></titles></properties>
  <lyrics><verse name="v1"><lines>가사</lines></verse></lyrics>
</song>
'''),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            '가사 파일입니다',
          ),
        ),
      );
    });

    test('keeps sequential grace notes separate from chords', () {
      const xml = '''
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
  <part id="P1"><measure number="1">
    <attributes><divisions>4</divisions></attributes>
    <note><grace/><pitch><step>D</step><octave>4</octave></pitch><voice>1</voice><type>eighth</type></note>
    <note><grace/><pitch><step>E</step><octave>4</octave></pitch><voice>1</voice><type>eighth</type></note>
    <note><pitch><step>F</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type></note>
  </measure></part>
</score-partwise>
''';
      final encoded = utf8.decode(codec.encodeMusicXml(codec.decodeXml(xml)));

      expect(RegExp('<chord').allMatches(encoded), isEmpty);
      expect(codec.decodeXml(encoded).noteCount, 3);
    });

    test('ignores tempo marks no player could use', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1"><part-list><score-part id="P1"><part-name>V</part-name></score-part></part-list>
<part id="P1"><measure number="1"><attributes><divisions>1</divisions></attributes>
<direction><direction-type><metronome><beat-unit>quarter</beat-unit><per-minute>1cz</per-minute></metronome></direction-type><sound tempo="1"/></direction>
<note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration><voice>1</voice><type>whole</type></note>
<sound tempo="9484"/></measure>
<measure number="2"><direction><direction-type><metronome><beat-unit>quarter</beat-unit><per-minute>96</per-minute></metronome></direction-type><sound tempo="96"/></direction>
<note><pitch><step>D</step><octave>5</octave></pitch><duration>4</duration><voice>1</voice><type>whole</type></note></measure>
</part></score-partwise>''';
      final score = codec.decodeXml(xml);
      final tempos = [
        for (final m in score.parts.single.measures)
          for (final d in m.events.whereType<MusicDirection>())
            if (d.tempoBpm != null) d.tempoBpm,
      ];
      expect(tempos, [96]);
      expect(score.tempoBpm, 96);
    });

    test('reads and writes segno, coda and jump sounds', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1"><part-list><score-part id="P1"><part-name>Voice</part-name></score-part></part-list>
<part id="P1">
<measure number="1"><attributes><divisions>1</divisions><time><beats>4</beats><beat-type>4</beat-type></time></attributes>
<direction placement="above"><direction-type><segno/></direction-type><sound segno="segno"/></direction>
<note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration><voice>1</voice><type>whole</type></note>
<direction placement="below"><direction-type><words>Fine</words></direction-type><sound fine="yes"/></direction></measure>
<measure number="2"><note><pitch><step>D</step><octave>5</octave></pitch><duration>4</duration><voice>1</voice><type>whole</type></note>
<direction placement="above"><direction-type><words>D.S. al Coda</words></direction-type><sound dalsegno="segno"/></direction>
<direction placement="above"><direction-type><words>To Coda</words></direction-type><sound tocoda="coda"/></direction></measure>
<measure number="3"><direction placement="above"><direction-type><coda/></direction-type></direction>
<note><pitch><step>E</step><octave>5</octave></pitch><duration>4</duration><voice>1</voice><type>whole</type></note></measure>
</part></score-partwise>''';

      Set<MusicNavigation> marks(MusicScore score, int index) =>
          score.parts.single.measures[index].navigation;

      final score = codec.decodeXml(xml);
      expect(marks(score, 0), {MusicNavigation.segno, MusicNavigation.fine});
      expect(marks(score, 1), {
        MusicNavigation.dalSegno,
        MusicNavigation.toCoda,
      });
      expect(marks(score, 2), {MusicNavigation.coda});

      final written = utf8.decode(codec.encodeMusicXml(score));
      expect(written, contains('<segno/>'));
      expect(written, contains('<coda/>'));
      expect(written, contains('dalsegno="segno"'));
      final again = codec.decodeXml(written);
      for (var index = 0; index < 3; index++) {
        expect(marks(again, index), marks(score, index));
      }
    });

    test('round-trips beams, ties, and slurs for Verovio engraving', () {
      const xml = '''
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Voice</part-name></score-part></part-list>
  <part id="P1"><measure number="1">
    <attributes><divisions>2</divisions>
      <time><beats>4</beats><beat-type>4</beat-type></time>
      <clef><sign>G</sign><line>2</line></clef>
    </attributes>
    <note>
      <pitch><step>F</step><octave>4</octave></pitch>
      <duration>1</duration><tie type="start"/><voice>1</voice><type>eighth</type>
      <beam number="1">begin</beam>
      <notations><tied type="start"/><slur type="start" number="1"/></notations>
    </note>
    <note>
      <pitch><step>F</step><octave>4</octave></pitch>
      <duration>1</duration><tie type="stop"/><voice>1</voice><type>eighth</type>
      <beam number="1">end</beam>
      <notations><tied type="stop"/><slur type="stop" number="1"/></notations>
    </note>
  </measure></part>
</score-partwise>
''';
      final score = codec.decodeXml(xml);
      final notes = score.parts.single.measures.single.events
          .whereType<MusicNote>()
          .toList();
      expect(notes, hasLength(2));
      expect(notes[0].beams.single.value, 'begin');
      expect(notes[0].tieStart, isTrue);
      expect(notes[0].slurStart, isTrue);
      expect(notes[1].beams.single.value, 'end');
      expect(notes[1].tieStop, isTrue);
      expect(notes[1].slurStop, isTrue);

      final encoded = utf8.decode(codec.encodeMusicXml(score));
      expect(encoded, contains('<beam number="1">begin</beam>'));
      expect(encoded, contains('<beam number="1">end</beam>'));
      expect(encoded, contains('<tied type="start"/>'));
      expect(encoded, contains('<tied type="stop"/>'));
      expect(encoded, contains('<slur type="start" number="1"/>'));
      expect(encoded, contains('<slur type="stop" number="1"/>'));
    });
  });
}

const _pianoMusicXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
  <movement-title>Autumn Test</movement-title>
  <identification>
    <creator type="composer">Test Composer</creator>
  </identification>
  <part-list>
    <score-part id="P1"><part-name>Piano</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
        <key><fifths>-1</fifths><mode>major</mode></key>
        <time><beats>4</beats><beat-type>4</beat-type></time>
        <staves>2</staves>
        <clef number="1"><sign>G</sign><line>2</line></clef>
        <clef number="2"><sign>F</sign><line>4</line></clef>
      </attributes>
      <direction placement="above">
        <direction-type><rehearsal>INTRO</rehearsal></direction-type>
        <sound tempo="96"/>
      </direction>
      <harmony>
        <root><root-step>B</root-step><root-alter>-1</root-alter></root>
        <kind text="B♭">major</kind>
      </harmony>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff>
      </note>
      <note>
        <chord/><pitch><step>E</step><octave>4</octave></pitch>
        <duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff>
      </note>
      <note>
        <rest/><duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff>
      </note>
      <backup><duration>8</duration></backup>
      <note>
        <pitch><step>C</step><octave>3</octave></pitch>
        <duration>8</duration><voice>2</voice><type>half</type><staff>2</staff>
      </note>
    </measure>
  </part>
</score-partwise>
''';
