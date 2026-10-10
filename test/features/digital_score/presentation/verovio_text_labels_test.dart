import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/presentation/verovio_score_view.dart';
import 'package:page_a_diddle/features/digital_score/presentation/verovio_text_labels.dart';

// Trimmed from Verovio 6.3 output with the viewer's page options.
const _svg = '''
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="2100px" height="2970px" viewBox="0 0 2100 2970">
  <svg class="definition-scale" color="black" font-family="Times, serif" viewBox="0 0 21000 29700">
    <g class="page-margin" transform="translate(800, 700)">
      <g class="measure">
        <g id="h1" class="harm">
          <text x="2568" y="362" font-size="0px">
            <tspan class="text">
              <tspan font-size="405px">C</tspan>
              <tspan font-family="Leipzig" font-size="720px">&#xEA66;</tspan>
              <tspan font-size="405px">m7</tspan>
            </tspan>
          </text>
        </g>
        <g id="h2" class="harm">
          <text x="3646" y="362" font-size="0px">
            <tspan class="text">
              <tspan font-size="405px">B</tspan>
              <tspan font-family="Leipzig" font-size="720px">&#xEA64;</tspan>
              <tspan font-size="405px">/D</tspan>
            </tspan>
          </text>
        </g>
        <g class="dir">
          <text x="10" y="20" font-size="0px"><tspan font-size="405px">rit.</tspan></text>
        </g>
        <g class="verse">
          <text x="10" y="900" font-size="0px"><tspan font-size="405px">la</tspan></text>
        </g>
      </g>
    </g>
  </svg>
</svg>
''';

void main() {
  test('extracts chord symbols, directions and lyrics', () {
    final labels = extractVerovioTextLabels(_svg);

    expect(labels.map((label) => label.text), ['C♯m7', 'B♭/D', 'rit.', 'la']);
    final first = labels.first;
    expect(first.x, closeTo(336.8, 1e-9));
    expect(first.baselineY, closeTo(106.2, 1e-9));
    expect(first.fontSize, closeTo(40.5, 1e-9));
  });

  test('maps the natural glyph and drops unknown engraving glyphs', () {
    const svg = '''
<svg viewBox="0 0 100 100"><g class="harm"><text x="5" y="10">
  <tspan font-size="8px">E</tspan><tspan font-family="Leipzig" font-size="12px">&#xEA65;&#xE050;</tspan>
</text></g></svg>
''';

    final labels = extractVerovioTextLabels(svg);

    expect(labels.single.text, 'E♮');
    expect(labels.single.fontSize, 8);
  });

  test('returns nothing for malformed SVG', () {
    expect(extractVerovioTextLabels('<svg'), isEmpty);
  });

  test('chord text is still stripped from the rendered SVG', () {
    final normalized = normalizeVerovioSvgForFlutter(_svg);

    expect(normalized, isNot(contains('<text')));
    expect(extractVerovioTextLabels(_svg), hasLength(4));
  });

  test('extracts lyric syllables, including Korean, below the staff', () {
    const svg = '''
<svg viewBox="0 0 2100 2970">
  <svg class="definition-scale" viewBox="0 0 21000 29700">
    <g class="page-margin" transform="translate(800, 700)">
      <g class="verse"><g class="syl">
        <text x="1779" y="1761" font-size="0px"><tspan class="text">
          <tspan font-size="405px">사</tspan></tspan></text>
        <rect x="2176" y="1658" height="22" width="98" />
      </g></g>
      <g class="verse"><g class="syl">
        <text x="1779" y="2161" font-size="0px"><tspan class="text">
          <tspan font-size="405px">Hel</tspan></tspan></text>
      </g></g>
    </g>
  </svg>
</svg>
''';

    final labels = extractVerovioTextLabels(svg);

    expect(labels.map((label) => label.text), ['사', 'Hel']);
    expect(labels.first.baselineY, closeTo(246.1, 1e-9));
    expect(labels.last.baselineY, greaterThan(labels.first.baselineY));
    // The hyphen is a shape and stays in the rendered SVG.
    expect(normalizeVerovioSvgForFlutter(svg), contains('<rect'));
  });

  test('shows bar and ending numbers and tempo, but not the part name', () {
    const svg = '''
<svg viewBox="0 0 100 100">
  <g class="label"><text x="1" y="50"><tspan font-size="8px">Voice</tspan></text></g>
  <g class="mNum"><text x="5" y="10"><tspan font-size="6px">7</tspan></text></g>
  <g class="voltaBracket"><text x="20" y="5"><tspan font-size="6px">1.</tspan></text></g>
  <g class="tempo"><text x="30" y="5">
    <tspan font-family="Leipzig" font-size="9px">&#xE1D5;</tspan>
    <tspan font-size="6px"> = 115</tspan></text></g>
</svg>
''';

    expect(extractVerovioTextLabels(svg).map((label) => label.text), [
      '7',
      '1.',
      '♩ = 115',
    ]);
  });

  test('reads the metronome note and dynamics letters of newer glyphs', () {
    const svg = '''
<svg viewBox="0 0 100 100">
  <g class="tempo"><text x="30" y="5"><tspan font-size="6px">Andante (</tspan>
    <tspan font-family="Leipzig" font-size="9px">&#xECA5;</tspan>
    <tspan font-size="6px"> </tspan>
    <tspan font-family="Leipzig" font-size="9px">&#xECB7;</tspan>
    <tspan font-size="6px"> = 50)</tspan></text></g>
  <g class="dir"><text x="30" y="15">
    <tspan font-family="Leipzig" font-size="9px">&#xE524;&#xE522;</tspan></text></g>
</svg>
''';

    expect(extractVerovioTextLabels(svg).map((label) => label.text), [
      'Andante (♩. = 50)',
      'sf',
    ]);
  });

  test('keeps the spaces written inside a text, not the indentation', () {
    const svg = '''
<svg viewBox="0 0 100 100">
  <g class="reh"><text x="5" y="10"><tspan class="text">
    <tspan font-size="6px">Verse 1</tspan></tspan></text></g>
  <g class="dir"><text x="5" y="20">
    <tspan font-size="6px">D.S.  al</tspan>
    <tspan font-size="6px"> Fine</tspan></text></g>
  <g class="harm"><text x="5" y="30"><tspan font-size="6px">
    G</tspan><tspan font-size="6px">/B
  </tspan></text></g>
  <g class="harm"><text x="5" y="40"><tspan font-size="6px">B </tspan>
    <tspan font-family="Leipzig" font-size="9px"> &#xEA64;</tspan></text></g>
  <g class="verse"><g class="syl"><text x="5" y="50">
    <tspan font-size="6px">예 수</tspan></text></g></g>
</svg>
''';

    expect(extractVerovioTextLabels(svg).map((label) => label.text), [
      'Verse 1',
      'D.S. al Fine',
      'G/B',
      // A chord symbol or a syllable is one word.
      'B♭',
      '예수',
    ]);
  });

  test('a chord name draws its accidental in the bundled engraving font', () {
    const style = TextStyle(fontSize: 20, fontFamily: 'serif');
    // No accidental: the text as it is.
    expect((verovioLabelSpan('Gm7', style) as TextSpan).text, 'Gm7');

    final span = verovioLabelSpan('B♭m7/A♯', style) as TextSpan;
    final parts = span.children!.cast<TextSpan>();
    expect(parts.map((part) => part.text), ['B', '\uED60', 'm7/A', '\uED62']);
    // The device's symbol font is not asked for the sign.
    expect(span.toPlainText(), isNot(contains('♭')));
    expect(parts[1].style!.fontFamily, 'Bravura');
    expect(parts[1].style!.fontSize, 20 * verovioAccidentalScale);
    expect(parts[0].style, isNull);
  });

  group('staff lines', () {
    // A bar of a grand staff as Verovio draws it: five lines to a staff,
    // then the clef and the notes, with ledger lines in a group of their own.
    const page = '''
<svg xmlns="http://www.w3.org/2000/svg" width="2100px" height="2970px" viewBox="0 0 2100 2970">
  <svg class="definition-scale" viewBox="0 0 21000 29700">
    <g class="page-margin" transform="translate(500, 500)">
      <g class="system"><g class="measure">
        <g class="staff">
          <path d="M0 1000 L4000 1000" stroke-width="13"/>
          <path d="M0 1180 L4000 1180" stroke-width="13"/>
          <path d="M0 1360 L4000 1360" stroke-width="13"/>
          <path d="M0 1540 L4000 1540" stroke-width="13"/>
          <path d="M0 1720 L4000 1720" stroke-width="13"/>
          <g class="clef"><use xlink:href="#E050" transform="translate(90, 1540) scale(0.72, 0.72)"/></g>
          <g class="ledgerLines above"><path d="M1000 820 L1300 820" stroke-width="22"/></g>
          <g class="layer"><g class="note"><g class="stem"><path d="M1200 900 L1200 300"/></g></g></g>
        </g>
        <g class="staff">
          <path d="M0 2700 L4000 2700" stroke-width="13"/>
          <path d="M0 2880 L4000 2880" stroke-width="13"/>
          <path d="M0 3060 L4000 3060" stroke-width="13"/>
          <path d="M0 3240 L4000 3240" stroke-width="13"/>
          <path d="M0 3420 L4000 3420" stroke-width="13"/>
        </g>
        <g class="staff"><path d="M0 5000 L4000 5000" stroke-width="13"/></g>
      </g></g>
    </g>
  </svg>
</svg>''';

    test('the five lines of each staff are read where they are drawn', () {
      final staves = readVerovioPage(page).staves;

      // Root units: the inner page is ten times as fine, and stands 500 in.
      expect(staves, hasLength(2));
      expect(staves[0].lines, [150, 168, 186, 204, 222]);
      expect((staves[0].left, staves[0].right), (50, 450));
      expect(staves[0].gap, 18);
      expect(staves[1].top, 320);
      expect(staves[1].bottom, 392);
      // A one-line staff has no pitches to place.
    });

    test('a page that cannot be read has no staff lines and no labels', () {
      final read = readVerovioPage('<svg');
      expect(read.staves, isEmpty);
      expect(read.labels, isEmpty);
    });

    test('the bottom line of a staff is the pitch its clef puts there', () {
      const treble = MusicClef(sign: 'G', line: 2);
      const bass = MusicClef(sign: 'F', line: 4);
      const alto = MusicClef(sign: 'C', line: 3);
      const tenorVoice = MusicClef(sign: 'G', line: 2, octaveChange: -1);

      // Steps from middle C: E4 is 2, G2 is -10, F3 is -4, E3 is -5.
      expect(bottomLineSteps(treble, staff: 1), 2);
      expect(bottomLineSteps(bass, staff: 2), -10);
      expect(bottomLineSteps(alto, staff: 1), -4);
      expect(bottomLineSteps(tenorVoice, staff: 1), -5);
      expect(bottomLineSteps(null, staff: 1), 2);
      expect(bottomLineSteps(null, staff: 2), -10);
    });

    test('a staff is measured from E4 or A3 wherever its clef puts them', () {
      // Lines 10 apart, the bottom one at 100.
      double anchor(MusicClef? clef, int staff) => staffAnchorFromLines(
        bottomLine: 100,
        lineGap: 10,
        clef: clef,
        staff: staff,
      );

      // Treble: E4 is the bottom line itself.
      expect(anchor(const MusicClef(sign: 'G', line: 2), 1), 100);
      // Bass on the second staff: A3 is the top line, four lines up.
      expect(anchor(const MusicClef(sign: 'F', line: 4), 2), 60);
      // Bass clef on a first staff: E4 is twelve steps above its bottom G2.
      expect(anchor(const MusicClef(sign: 'F', line: 4), 1), 40);
      // Treble clef on a second staff: A3 is four steps below its E4.
      expect(anchor(const MusicClef(sign: 'G', line: 2), 2), 120);
    });
  });

  group('chord symbols as numbers', () {
    test('the Nashville way: the degree of the key, and what follows it', () {
      // F major, one flat.
      expect(chordAsNumber('F', -1, roman: false), '1');
      expect(chordAsNumber('Dm', -1, roman: false), '6m');
      expect(chordAsNumber('Am/C', -1, roman: false), '3m/5');
      expect(chordAsNumber('B♭', -1, roman: false), '4');
      expect(chordAsNumber('C(sus4)', -1, roman: false), '5(sus4)');
      expect(chordAsNumber('Gm7', -1, roman: false), '2m7');
      // A chord from outside the key says by how much.
      expect(chordAsNumber('E♭', -1, roman: false), '♭7');
      expect(chordAsNumber('F♯dim', -1, roman: false), '♯1dim');
    });

    test('in another key the same chords are other numbers', () {
      // G major and D major.
      expect(chordAsNumber('D7/F#', 1, roman: false), '57/7');
      expect(chordAsNumber('Em', 1, roman: false), '6m');
      expect(chordAsNumber('G', 2, roman: false), '4');
      expect(chordAsNumber('Bm7', 2, roman: false), '6m7');
      expect(chordAsNumber('C', 0, roman: false), '1');
    });

    test('in Roman numerals a minor chord is written small', () {
      expect(chordAsNumber('Dm', -1, roman: true), 'vi');
      expect(chordAsNumber('Am7', -1, roman: true), 'iii7');
      expect(chordAsNumber('B♭maj7', -1, roman: true), 'IVmaj7');
      expect(chordAsNumber('F/A', -1, roman: true), 'I/III');
      expect(chordAsNumber('E♭', -1, roman: true), '♭VII');
    });

    test('what is not a chord symbol is left as it is', () {
      expect(chordAsNumber('N.C.', 0, roman: false), 'N.C.');
      expect(chordAsNumber('', 0, roman: false), '');
      expect(chordAsNumber('C/x', 0, roman: false), 'C/x');
    });
  });

  group('the words of a page as the reader asks for them', () {
    const labels = [
      VerovioTextLabel(
        text: '5',
        x: 10,
        baselineY: 90,
        fontSize: 20,
        kind: 'mNum',
      ),
      VerovioTextLabel(
        text: 'F',
        x: 40,
        baselineY: 100,
        fontSize: 40,
        kind: 'harm',
      ),
      VerovioTextLabel(
        text: 'Dm',
        x: 200,
        baselineY: 70,
        fontSize: 40,
        kind: 'harm',
      ),
      VerovioTextLabel(
        text: '주',
        x: 40,
        baselineY: 300,
        fontSize: 30,
        kind: 'verse',
      ),
      // The next line of the score.
      VerovioTextLabel(
        text: 'C',
        x: 40,
        baselineY: 620,
        fontSize: 40,
        kind: 'harm',
      ),
    ];

    test('nothing asked for, nothing changed', () {
      expect(shownLabels(labels).map((l) => l.text), [
        '5',
        'F',
        'Dm',
        '주',
        'C',
      ]);
    });

    test('chord symbols as numbers, each in its own key', () {
      final shown = shownLabels(
        labels,
        chords: ChordDisplay.nashville,
        // The second line is in C, the first in F.
        keyOf: (chord) => chord.baselineY > 400 ? 0 : -1,
      );
      expect(shown.map((l) => l.text), ['5', '1', '6m', '주', '1']);
    });

    test('larger words, chord symbols on one level, no bar numbers', () {
      final shown = shownLabels(
        labels,
        wordScale: 1.2,
        alignChords: true,
        hideBarNumbers: true,
      );
      expect(shown.map((l) => l.text), ['F', 'Dm', '주', 'C']);
      expect(shown.map((l) => l.fontSize), [48, 48, 36, 48]);
      // F comes up to Dm; the chord of the next line stays on its own.
      expect(shown.map((l) => l.baselineY), [70, 70, 300, 620]);
    });
  });
}
