import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/midi_codec.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';

String _note(String step, {int duration = 1}) =>
    '<note><pitch><step>$step</step><octave>4</octave></pitch>'
    '<duration>$duration</duration><voice>1</voice><type>quarter</type></note>';

String _score(List<String> bars, {String time = '4'}) =>
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<score-partwise version="4.0"><part-list>'
    '<score-part id="P1"><part-name>Voice</part-name></score-part>'
    '</part-list><part id="P1">'
    '${[for (final (index, bar) in bars.indexed) '<measure number="${index + 1}">${index == 0 ? '<attributes><divisions>1</divisions><key><fifths>0</fifths></key><time><beats>4</beats><beat-type>$time</beat-type></time><clef><sign>G</sign><line>2</line></clef></attributes>' : ''}$bar</measure>'].join()}'
    '</part></score-partwise>';

void main() {
  const codec = MusicXmlCodec();

  test('a bar that holds more than its time ends before the track does', () {
    // Six quarters in a bar of four, the last bar of the score: its last
    // notes sound after the bars add up to their end.
    final score = codec.decodeXml(
      _score([
        ['C', 'D', 'E', 'F'].map(_note).join(),
        ['C', 'D', 'E', 'F', 'G', 'A'].map(_note).join(),
      ]),
    );
    final bytes = const MidiCodec().encode(score);
    // The end of the track is the last thing in the file.
    expect(bytes.sublist(bytes.length - 3), [0xff, 0x2f, 0x00]);
    final ends = <int>[
      for (var i = 0; i + 2 < bytes.length; i++)
        if (bytes[i] == 0xff && bytes[i + 1] == 0x2f && bytes[i + 2] == 0x00) i,
    ];
    // One for the tempo track, one for the part, each at the end of its
    // chunk.
    expect(ends, hasLength(2));
    final last = bytes.lastIndexOf(0x80);
    expect(last, lessThan(ends.last), reason: 'no note ends after the end');
  });

  test('a time signature of beats of no length is not a time signature', () {
    final xml = _score([
      ['C', 'D', 'E', 'F'].map(_note).join(),
    ], time: '0');
    final score = codec.decodeXml(xml);
    expect(score.parts.first.measures.first.attributes.time, isNull);
    // And the file made of it is whole.
    final bytes = const MidiCodec().encode(score);
    expect(bytes.sublist(bytes.length - 3), [0xff, 0x2f, 0x00]);
  });
}
