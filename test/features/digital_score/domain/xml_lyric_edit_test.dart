import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/xml_measure_editor.dart';

const _editor = XmlMeasureEditor();

// Bar 1: a sung note with two verses (the first joined to the next by a
// hyphen), a note with a tie and no word, a chord of two notes with its
// word on the first, and a rest.
const _xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Voice</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>1</divisions><key><fifths>0</fifths></key>
        <time><beats>4</beats><beat-type>4</beat-type></time>
        <clef><sign>G</sign><line>2</line></clef></attributes>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type>
        <lyric number="1"><syllabic>begin</syllabic><text>몬</text></lyric>
        <lyric number="2"><syllabic>single</syllabic><text>둘</text></lyric></note>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>1</duration><tie type="start"/><voice>1</voice><type>quarter</type>
        <notations><tied type="start"/></notations></note>
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type>
        <lyric><syllabic>single</syllabic><text>화</text></lyric></note>
      <note><chord/><pitch><step>G</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type></note>
      <note><rest/><duration>1</duration><voice>1</voice><type>quarter</type></note>
    </measure>
  </part>
</score-partwise>
''';

XmlNoteRef _note(int index) =>
    XmlNoteRef(partIndex: 0, measureIndex: 0, noteIndex: index);

void main() {
  test('a misread word is corrected and keeps how it joins the next', () {
    expect(_editor.describe(_xml, _note(0)).lyric, '몬');
    final edited = _editor.setLyric(_xml, _note(0), ' 주 ').xml;
    expect(_editor.describe(edited, _note(0)).lyric, '주');
    expect(
      edited,
      contains('<lyric number="1"><syllabic>begin</syllabic><text>주</text>'),
    );
    // The other verse and the other notes are as they were.
    expect(edited, contains('<text>둘</text>'));
    expect(edited, contains('<text>화</text>'));
    expect(const MusicXmlCodec().decodeXml(edited).measureCount, 1);
  });

  test('a note without a word gets one, after its notations', () {
    expect(_editor.describe(_xml, _note(1)).lyric, isNull);
    final edited = _editor.setLyric(_xml, _note(1), '님').xml;
    expect(_editor.describe(edited, _note(1)).lyric, '님');
    expect(
      edited,
      contains(
        '<notations><tied type="start"/></notations>'
        '<lyric number="1"><syllabic>single</syllabic><text>님</text></lyric>',
      ),
    );
  });

  test('a word is taken away; there must be one to take', () {
    final edited = _editor.setLyric(_xml, _note(0), '').xml;
    expect(_editor.describe(edited, _note(0)).lyric, isNull);
    // Only the first verse went.
    expect(edited, contains('<text>둘</text>'));
    expect(
      () => _editor.setLyric(_xml, _note(1), null),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          '지울 가사가 없습니다.',
        ),
      ),
    );
  });

  test('the word of a chord is the word of its first note', () {
    // Asked on the second note of the chord.
    expect(_editor.describe(_xml, _note(3)).lyric, '화');
    expect(_editor.describe(_xml, _note(3)).leadsChord, isFalse);
    expect(_editor.describe(_xml, _note(2)).leadsChord, isTrue);
    final edited = _editor.setLyric(_xml, _note(3), '하').xml;
    expect(_editor.describe(edited, _note(2)).lyric, '하');
    expect(
      '<lyric'.allMatches(edited).length,
      '<lyric'.allMatches(_xml).length,
    );
  });

  test('a rest is not sung, and a word has a length', () {
    expect(
      () => _editor.setLyric(_xml, _note(4), '아'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          '쉼표에는 가사를 넣을 수 없습니다.',
        ),
      ),
    );
    expect(
      () => _editor.setLyric(_xml, _note(0), '가' * (maxLyricLength + 1)),
      throwsFormatException,
    );
    // Marks that would break the file are written as text.
    final edited = _editor.setLyric(_xml, _note(0), '<b>&"').xml;
    expect(_editor.describe(edited, _note(0)).lyric, '<b>&"');
  });

  group('typed as in a notation program', () {
    test('the hyphen and the held line show at the end of the syllable', () {
      final first = _editor.describe(_xml, _note(0));
      expect(first.lyricTyped(1), '몬-');
      expect(first.lyricTyped(2), '둘');
      expect(_editor.describe(_xml, _note(1)).lyricTyped(1), '');
    });

    test('a hyphen joins the syllable to the next, which ends the word', () {
      // "님" on the second note, joined to "화" on the chord after it. The
      // syllable before it ("몬-") already runs into it.
      final edited = _editor.setLyric(_xml, _note(1), '님-', typed: true).xml;

      expect(_editor.describe(edited, _note(1)).lyric, '님');
      expect(_editor.describe(edited, _note(1)).lyricTyped(1), '님-');
      expect(edited, contains('<syllabic>middle</syllabic><text>님</text>'));
      expect(edited, contains('<syllabic>end</syllabic><text>화</text>'));
      // The other verse is not part of the word.
      expect(edited, contains('<syllabic>single</syllabic><text>둘</text>'));
    });

    test(
      'without its hyphen a syllable stands alone, and so does the next',
      () {
        // "몬-" runs into it and it runs on: the middle of a word.
        final joined = _editor.setLyric(_xml, _note(2), '화-', typed: true).xml;
        expect(joined, contains('<syllabic>middle</syllabic><text>화</text>'));

        // The first syllable loses its hyphen: "주" and "화-" are two words.
        final edited = _editor.setLyric(joined, _note(0), '주', typed: true).xml;

        expect(edited, contains('<syllabic>single</syllabic><text>주</text>'));
        expect(edited, contains('<syllabic>begin</syllabic><text>화</text>'));
      },
    );

    test('an underscore holds the syllable over the notes after it', () {
      final edited = _editor.setLyric(_xml, _note(2), '화_', typed: true).xml;

      expect(_editor.describe(edited, _note(2)).lyric, '화');
      expect(_editor.describe(edited, _note(2)).lyricTyped(1), '화_');
      expect(edited, contains('<text>화</text><extend type="start"/></lyric>'));
      // Typed again without it, the line goes.
      final plain = _editor.setLyric(edited, _note(2), '화', typed: true).xml;
      expect(plain, isNot(contains('<extend')));
      expect(const MusicXmlCodec().decodeXml(edited).measureCount, 1);
    });

    test('a hyphen or underscore alone is a word like any other', () {
      final edited = _editor.setLyric(_xml, _note(1), '-', typed: true).xml;
      expect(_editor.describe(edited, _note(1)).lyric, '-');
    });
  });
}
