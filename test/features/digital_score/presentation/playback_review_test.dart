import 'package:flutter_notemus/flutter_notemus.dart' as nm;
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/performance_score.dart';
import 'package:page_a_diddle/features/digital_score/presentation/midi_duration.dart';
import 'package:page_a_diddle/features/digital_score/presentation/verovio_text_labels.dart';

// What a reading of the player's code against its own promises found, each
// as the score that showed it.

String _note(
  String step, {
  String extra = '',
  int duration = 1,
  String type = 'quarter',
}) =>
    '<note><pitch><step>$step</step><octave>4</octave></pitch>'
    '<duration>$duration</duration><voice>1</voice><type>$type</type>'
    '$extra</note>';

String _words(String text) =>
    '<direction placement="above"><direction-type><words>$text</words>'
    '</direction-type></direction>';

String _wedge(String type) =>
    '<direction><direction-type><wedge type="$type"/></direction-type>'
    '</direction>';

const _four = ['C', 'D', 'E', 'F'];

/// A voice in 4/4, [divisions] to the quarter.
String _score(List<String> bars, {String firstBar = '', int divisions = 1}) {
  final buffer = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<score-partwise version="4.0"><part-list>'
    '<score-part id="P1"><part-name>Voice</part-name></score-part>'
    '</part-list><part id="P1">',
  );
  for (final (index, bar) in bars.indexed) {
    buffer.write(
      '<measure number="${index + 1}"${index == 0 ? firstBar : ''}>',
    );
    if (index == 0) {
      buffer.write(
        '<attributes><divisions>$divisions</divisions>'
        '<key><fifths>0</fifths></key>'
        '<time><beats>4</beats><beat-type>4</beat-type></time>'
        '<clef><sign>G</sign><line>2</line></clef></attributes>',
      );
    }
    buffer
      ..write(bar)
      ..write('</measure>');
  }
  buffer.write('</part></score-partwise>');
  return buffer.toString();
}

nm.MidiSequence _sequence(String xml) => playbackMidi(
  xml,
  options: const nm.MidiGenerationOptions(
    defaultBpm: 120,
    includeMetronome: false,
  ),
);

/// The notes played for [xml]: where each begins and ends, its pitch and
/// how loud, in ticks (960 to the quarter).
List<({int tick, int key, int velocity, int length})> _played(String xml) {
  final notes = <({int tick, int key, int velocity, int length})>[];
  for (final track in _sequence(xml).tracks) {
    final open = <int, List<nm.MidiEvent>>{};
    for (final event in track.events) {
      final key = event.note;
      if (key == null) continue;
      if (event.type == nm.MidiEventType.noteOn && (event.velocity ?? 0) > 0) {
        open.putIfAbsent(key, () => []).add(event);
      } else if (open[key] case final began? when began.isNotEmpty) {
        final start = began.removeAt(0);
        notes.add((
          tick: start.tick,
          key: key,
          velocity: start.velocity ?? 0,
          length: event.tick - start.tick,
        ));
      }
    }
    expect(
      open.values.every((began) => began.isEmpty),
      isTrue,
      reason: 'every note that begins ends',
    );
  }
  return notes..sort((a, b) => a.tick.compareTo(b.tick));
}

/// The tempo the player is told, tick by tick.
Map<int, int> _tempos(String xml) => {
  for (final track in _sequence(xml).tracks)
    for (final event in track.events)
      if (event.type == nm.MidiEventType.tempo) event.tick: event.bpm!,
};

void main() {
  test('a pickup is played as long as its notes, not as long as a bar', () {
    final played = _played(
      _score([
        _note('G'),
        _four.map(_note).join(),
      ], firstBar: ' implicit="yes"'),
    );
    expect([for (final note in played) note.tick], [0, 960, 1920, 2880, 3840]);
  });

  test('the bar the player counts is the bar the marks are placed by', () {
    // A crescendo in the bar after a pickup: on its notes, not three beats
    // late.
    final xml = _score([
      _note('G'),
      '${_wedge('crescendo')}${_four.map(_note).join()}${_wedge('stop')}',
    ], firstBar: ' implicit="yes"');
    final hairpins = playedHairpins(xml, const MusicXmlCodec().decodeXml(xml));
    expect(hairpins.hairpins.single.from, 1);
    final played = _played(xml);
    expect(played[4].velocity, greaterThan(played[1].velocity));
  });

  test('a note not played does not lengthen the same note before it', () {
    const mute = '<play><mute>on</mute></play>';
    final played = _played(
      _score([_note('C') + _note('C', extra: mute) + _note('E') + _note('F')]),
    );
    expect(
      [for (final note in played) (note.tick, note.key, note.length)],
      [(0, 60, 960), (1920, 64, 960), (2880, 65, 960)],
    );
  });

  test('slashes are not played', () {
    const slash = '<notehead>slash</notehead>';
    final played = _played(
      _score([
        [for (final step in _four) _note(step, extra: slash)].join(),
        _four.map(_note).join(),
      ]),
    );
    expect([for (final note in played) note.tick], [3840, 4800, 5760, 6720]);
  });

  test('a diminuendo after a crescendo comes back down from it', () {
    final played = _played(
      _score([
        '${_wedge('crescendo')}${_four.map(_note).join()}${_wedge('stop')}',
        '${_wedge('diminuendo')}${_four.map(_note).join()}${_wedge('stop')}',
        _four.map(_note).join(),
      ]),
    );
    final loud = [for (final note in played) note.velocity];
    // Up through the first bar.
    expect(loud[3], greaterThan(loud[0]));
    // The second begins where the first got to, and goes down from there.
    expect(loud[4], greaterThanOrEqualTo(loud[3]));
    expect(loud[7], lessThan(loud[4]));
    // And leaves the music about as loud as it was written.
    expect((loud[8] - loud[0]).abs(), lessThanOrEqualTo(4));
  });

  group('swing', () {
    test('every note still ends after it begins', () {
      // Thirty-seconds: one of them begins on the late eighth.
      final bar = [
        for (var i = 0; i < 32; i++)
          _note(_four[i % 4], duration: 1, type: '32nd'),
      ].join();
      final played = _played(_score(['${_words('Swing')}$bar'], divisions: 8));
      expect(played, hasLength(32));
      expect(played.every((note) => note.length > 0), isTrue);
    });

    test('is read from words that name it among others', () {
      final eighths = [
        for (var i = 0; i < 8; i++)
          _note(_four[i % 4], duration: 1, type: 'eighth'),
      ].join();
      final played = _played(
        _score(['${_words('Medium Swing')}$eighths'], divisions: 2),
      );
      expect(played[1].tick, 640);
    });
  });

  group('tempo words', () {
    test('are read wherever they stand in the words', () {
      for (final text in ['poco rit.', 'molto rall.', '(rit.)']) {
        final tempos = _tempos(
          _score([
            '${_words(text)}${_four.map(_note).join()}',
            _four.map(_note).join(),
            _four.map(_note).join(),
          ]),
        );
        expect(
          tempos.values.any((bpm) => bpm < 115),
          isTrue,
          reason: '$text slows down',
        );
      }
      // Not every word that begins like one is one.
      final none = _tempos(
        _score(['${_words('ritmico')}${_four.map(_note).join()}']),
      );
      expect(none.values.every((bpm) => bpm == 120), isTrue);
    });

    test('a second rit. goes on from where the first got to', () {
      final tempos = _tempos(
        _score([
          '${_words('rit.')}${_four.map(_note).join()}',
          '${_words('rit.')}${_four.map(_note).join()}',
          _four.map(_note).join(),
        ]),
      );
      final ticks = tempos.keys.toList()..sort();
      final through = [
        for (final tick in ticks)
          if (tick < 2 * 3840) tempos[tick]!,
      ];
      // Never faster again while the two last.
      for (var i = 1; i < through.length; i++) {
        expect(through[i], lessThanOrEqualTo(through[i - 1]));
      }
      // Slower than the first alone gets to (120 to 86).
      expect(through.last, lessThan(80));
    });
  });

  test('a fermata over a held note is one hold, not two multiplied', () {
    const fermata = '<notations><fermata/></notations>';
    // A whole note under a fermata, and a fermata on the last beat above.
    final xml = _score([
      '${_note('C')}${_note('D')}${_note('E')}'
          '${_note('F', extra: fermata)}'
          '<backup><duration>4</duration></backup>'
          '<note><pitch><step>C</step><octave>3</octave></pitch>'
          '<duration>4</duration><voice>2</voice><type>whole</type>'
          '$fermata</note>',
      _four.map(_note).join(),
    ]);
    final tempos = _tempos(xml);
    // The first three beats go as written; the last is held.
    expect(tempos[0] ?? 120, 120);
    expect(tempos[2880], 60);
    expect(tempos.values.every((bpm) => bpm >= 60), isTrue);
  });

  group('chords as numbers', () {
    test('minor is read however it is written', () {
      expect(chordAsNumber('Am7', 0, roman: true), 'vi7');
      expect(chordAsNumber('Ami7', 0, roman: true), 'vi7');
      expect(chordAsNumber('Amin7', 0, roman: true), 'vi7');
      expect(chordAsNumber('A-7', 0, roman: true), 'vi7');
      // "ma7" and "maj7" are major sevenths.
      expect(chordAsNumber('Cma7', 0, roman: true), 'Ima7');
      expect(chordAsNumber('Cmaj7', 0, roman: true), 'Imaj7');
    });

    test('a slash is a bass only before a note name', () {
      expect(chordAsNumber('C6/9', 0, roman: true), 'I6/9');
      expect(chordAsNumber('C6/9/E', 0, roman: true), 'I6/9/III');
      expect(chordAsNumber('C/E', 0, roman: false), '1/3');
    });
  });
}
