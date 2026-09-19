import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/blank_piano_score.dart';

void main() {
  test('blank piano score is a one-measure Grand Staff that round-trips', () {
    final written = blankPianoScore(title: '초안', composer: '나', tempoBpm: 80);
    final codec = const MusicXmlCodec();
    final restored = codec.decode(
      codec.encode(written, MusicXmlFileFormat.musicXml),
    );

    expect(restored.title, '초안');
    expect(restored.composer, '나');
    expect(restored.tempoBpm, 80);
    expect(restored.parts.single.name, 'Piano');
    expect(restored.measureCount, 1);
    final measure = restored.parts.single.measures.single;
    expect(measure.attributes.staves, 2);
    expect(measure.attributes.clefs[1]?.sign, 'G');
    expect(measure.attributes.clefs[2]?.sign, 'F');
    expect(measure.notes.every((note) => note.isRest), isTrue);
  });
}
