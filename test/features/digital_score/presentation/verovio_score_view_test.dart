import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/presentation/verovio_score_view.dart';

void main() {
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
