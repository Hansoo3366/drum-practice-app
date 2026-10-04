import 'package:flutter_notemus/flutter_notemus.dart' as nm;
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/metronome_tempo.dart';
import 'package:page_a_diddle/features/digital_score/presentation/midi_duration.dart';

String _score(String metronome, {String sound = ''}) =>
    '''
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>2</divisions><key><fifths>0</fifths></key>
        <time><beats>6</beats><beat-type>8</beat-type></time>
        <clef><sign>G</sign><line>2</line></clef></attributes>
      <direction placement="above"><direction-type>$metronome</direction-type>$sound</direction>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>6</duration><voice>1</voice><type>half</type><dot/></note>
    </measure>
  </part>
</score-partwise>
''';

const _dotted =
    '<metronome parentheses="yes"><beat-unit>quarter</beat-unit>'
    '<beat-unit-dot/><per-minute>50</per-minute></metronome>';

void main() {
  test('a metronome mark counts its own beat; a tempo counts quarters', () {
    expect(quarterTempo('quarter', 0, 120), 120);
    expect(quarterTempo('quarter', 1, 50), 75);
    expect(quarterTempo('half', 0, 84), 168);
    expect(quarterTempo('eighth', 0, 120), 60);
    expect(quarterTempo('eighth', 1, 80), 60);
    expect(quarterTempo('half', 2, 40), 140);
    // No unit is the quarter; a unit this does not know gives no tempo.
    expect(quarterTempo(null, 0, 100), 100);
    expect(quarterTempo('maxima', 0, 100), isNull);
    expect(quarterTempo('quarter', 0, null), isNull);
    expect(quarterTempo('quarter', 0, 0), isNull);
  });

  test('marks are rewritten in quarters, with their attributes', () {
    final xml = metronomesInQuarters(_score(_dotted));
    expect(
      xml,
      contains(
        '<metronome parentheses="yes"><beat-unit>quarter</beat-unit>'
        '<per-minute>75</per-minute></metronome>',
      ),
    );
    expect(xml, isNot(contains('beat-unit-dot')));
    // A score without marks is not touched.
    const plain = '<score-partwise><part id="P1"/></score-partwise>';
    expect(identical(metronomesInQuarters(plain), plain), isTrue);
  });

  test('a mark that is not a number of beats is left alone', () {
    // A metric modulation: two beat units and no number.
    const modulation =
        '<metronome><beat-unit>quarter</beat-unit>'
        '<beat-unit>eighth</beat-unit></metronome>';
    expect(metronomesInQuarters(_score(modulation)), _score(modulation));
    const words =
        '<metronome><beat-unit>quarter</beat-unit>'
        '<per-minute>c. 60</per-minute></metronome>';
    expect(metronomesInQuarters(_score(words)), _score(words));
  });

  test('a score marked in dotted quarters plays at that tempo', () {
    // 6/8 at "dotted quarter = 50": the bar of two beats lasts 2.4 s, not
    // the 3.6 s of fifty quarters a minute.
    final midi = playbackMidi(
      _score(_dotted),
      options: const nm.MidiGenerationOptions(
        defaultBpm: 120,
        includeMetronome: false,
      ),
    );
    final tempos = [
      for (final track in midi.tracks)
        for (final event in track.events)
          if (event.type == nm.MidiEventType.tempo) event.bpm,
    ];
    expect(tempos.last, 75);
    expect(MidiTiming(midi).durationMs, closeTo(2400, 1));
  });

  test('the tempo read from a mark alone is in quarters', () {
    const codec = MusicXmlCodec();
    expect(codec.decodeXml(_score(_dotted)).tempoBpm, 75);
    // The sound element, where there is one, is in quarters already.
    expect(
      codec.decodeXml(_score(_dotted, sound: '<sound tempo="72"/>')).tempoBpm,
      72,
    );
    const half =
        '<metronome><beat-unit>half</beat-unit>'
        '<per-minute>84</per-minute></metronome>';
    expect(codec.decodeXml(_score(half)).tempoBpm, 168);
  });
}
