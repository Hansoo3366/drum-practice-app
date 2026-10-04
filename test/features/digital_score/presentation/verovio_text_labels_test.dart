import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
