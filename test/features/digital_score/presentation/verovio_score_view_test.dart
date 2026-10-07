import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/presentation/verovio_score_view.dart';

void main() {
  group('marking a run of bars', () {
    test('the bars of a line are one box, however tall each is', () {
      // Three bars side by side; the middle one has a high note.
      final boxes = lineBoxes(const [
        Rect.fromLTRB(10, 100, 110, 180),
        Rect.fromLTRB(108, 80, 210, 180),
        Rect.fromLTRB(208, 100, 300, 190),
      ]);

      expect(boxes, [const Rect.fromLTRB(10, 80, 300, 190)]);
    });

    test('lines that follow one another join into a block', () {
      final boxes = lineBoxes(const [
        Rect.fromLTRB(10, 100, 150, 180),
        Rect.fromLTRB(150, 100, 300, 180),
        // Next line, 40 below.
        Rect.fromLTRB(10, 220, 160, 300),
        Rect.fromLTRB(160, 215, 300, 300),
      ]);

      expect(boxes, [
        // The first line reaches down to the second: no stripe between.
        const Rect.fromLTRB(10, 100, 300, 215),
        const Rect.fromLTRB(10, 215, 300, 300),
      ]);
    });

    test('a run that starts in the middle of a line keeps its shape', () {
      // The last bar of one line and the whole next line.
      final boxes = lineBoxes(const [
        Rect.fromLTRB(200, 100, 300, 180),
        Rect.fromLTRB(10, 220, 150, 300),
        Rect.fromLTRB(150, 220, 300, 300),
      ]);

      expect(boxes, [
        const Rect.fromLTRB(200, 100, 300, 220),
        const Rect.fromLTRB(10, 220, 300, 300),
      ]);
    });

    test('the gap to the next page stays open', () {
      final boxes = lineBoxes(const [
        Rect.fromLTRB(10, 100, 300, 180),
        Rect.fromLTRB(10, 600, 300, 680),
      ]);

      expect(boxes, [
        const Rect.fromLTRB(10, 100, 300, 180),
        const Rect.fromLTRB(10, 600, 300, 680),
      ]);
    });

    test('one bar is its own box, none is none', () {
      expect(lineBoxes(const [Rect.fromLTRB(1, 2, 3, 4)]), [
        const Rect.fromLTRB(1, 2, 3, 4),
      ]);
      expect(lineBoxes(const []), isEmpty);
    });
  });

  test('removes positioned Verovio text including numeric measure labels', () {
    const source = '''
<svg viewBox="0 0 2100 2970">
  <svg class="definition-scale" viewBox="0 0 21000 29700">
    <text x="10" y="20">Verse</text>
    <text x="10" y="40"><tspan>18</tspan></text>
    <path d="M 0 0 L 10 10" stroke-width="2" />
  </svg>
</svg>
''';

    final normalized = normalizeVerovioSvgForFlutter(source);

    expect(normalized, isNot(contains('<text')));
    expect(normalized, isNot(contains('Verse')));
    expect(normalized, isNot(contains('>18<')));
    expect(normalized, contains('<path'));
    expect(normalized, contains('stroke="black"'));
  });

  test('orders measures by line even when a bar box is taller', () {
    // Bar 4 has high notes, so its box starts above bars 1-3 on the line.
    final boxes = {
      'bar2': const Rect.fromLTRB(200, 100, 300, 300),
      'bar4': const Rect.fromLTRB(400, 60, 500, 300),
      'bar1': const Rect.fromLTRB(100, 100, 200, 300),
      'bar3': const Rect.fromLTRB(300, 95, 400, 300),
      'bar5': const Rect.fromLTRB(100, 360, 250, 560),
      'bar6': const Rect.fromLTRB(250, 330, 500, 560),
    };

    final ordered = orderMeasureBoxes(boxes.keys.toList(), (id) => boxes[id]!);

    expect(ordered, ['bar1', 'bar2', 'bar3', 'bar4', 'bar5', 'bar6']);
  });

  test('trims the blank area below the last system of a page', () {
    expect(visiblePageHeight(2970, [800, 1500]), closeTo(1589.1, 1e-9));
    expect(visiblePageHeight(2970, [2950]), 2970);
    expect(visiblePageHeight(2970, const []), 2970);
  });

  test('an empty text tag does not swallow the notation after it', () {
    const source = '''
<svg viewBox="0 0 2100 2970">
  <svg class="definition-scale" viewBox="0 0 21000 29700">
    <text x="1312" y="521" text-anchor="middle" font-size="0px" />
    <g class="staff"><path d="M 0 0 L 10 0" stroke-width="2" /></g>
    <g class="meterSig"><use xlink:href="#E084" /></g>
    <text x="10" y="20"><tspan>7</tspan></text>
    <text>bare</text>
    <path d="M 0 5 L 10 5" stroke-width="2" />
  </svg>
</svg>
''';

    final normalized = normalizeVerovioSvgForFlutter(source);

    expect(normalized, isNot(contains('<text')));
    expect(normalized, contains('class="staff"'));
    expect(normalized, contains('class="meterSig"'));
    expect('<path'.allMatches(normalized), hasLength(2));
  });
}
