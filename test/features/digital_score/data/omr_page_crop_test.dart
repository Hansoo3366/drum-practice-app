import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_page_crop.dart';

void main() {
  test(
    'uses MusicXML page breaks instead of a fixed measures-per-page count',
    () {
      const xml = '''
<score-partwise version="4.0">
  <part id="P1">
    <measure number="1"/>
    <measure number="2"/>
    <measure number="3"><print new-page="yes"/></measure>
    <measure number="4"/>
    <measure number="5"><print new-page="yes"/></measure>
  </part>
</score-partwise>
''';
      expect(omrSourcePageForMeasure(xml, 0, 3), 0);
      expect(omrSourcePageForMeasure(xml, 2, 3), 1);
      expect(omrSourcePageForMeasure(xml, 4, 3), 2);
    },
  );

  test('rejects missing page mapping for a multipage source', () {
    const xml = '''
<score-partwise version="4.0">
  <part id="P1"><measure number="1"/><measure number="2"/></part>
</score-partwise>
''';
    expect(
      () => omrSourcePageForMeasure(xml, 1, 2),
      throwsA(isA<FormatException>()),
    );
  });
}
