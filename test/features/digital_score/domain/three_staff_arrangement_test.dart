import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/three_staff_arrangement.dart';
import 'package:xml/xml.dart';

const _codec = MusicXmlCodec();

/// A one-staff melody in 4/4 with a quarter note of 4 divisions.
String _score(
  List<String> measures, {
  int fifths = 0,
  String time = '4/4',
  int staves = 1,
  String extraPart = '',
}) {
  final beats = time.split('/');
  final first = measures.first.replaceFirstMapped(
    RegExp('<measure([^>]*)>'),
    (match) =>
        '<measure${match.group(1)}><attributes><divisions>4</divisions>'
        '<key><fifths>$fifths</fifths></key>'
        '<time><beats>${beats[0]}</beats><beat-type>${beats[1]}</beat-type></time>'
        '${staves > 1 ? '<staves>$staves</staves>' : ''}'
        '<clef><sign>G</sign><line>2</line></clef></attributes>',
  );
  return '<?xml version="1.0" encoding="UTF-8"?>'
      '<score-partwise version="4.0"><part-list>'
      '<score-part id="P1"><part-name>Voice</part-name></score-part>'
      '${extraPart.isEmpty ? '' : '<score-part id="P2"><part-name>Other</part-name></score-part>'}'
      '</part-list><part id="P1">$first${measures.skip(1).join()}</part>$extraPart</score-partwise>';
}

String _bar(int number, String content, {String attributes = ''}) =>
    '<measure number="$number"$attributes>$content</measure>';

String _note(String step, int octave, int duration, String type) =>
    '<note><pitch><step>$step</step><octave>$octave</octave></pitch>'
    '<duration>$duration</duration><voice>1</voice><type>$type</type>'
    '<lyric number="1"><text>la</text></lyric></note>';

String _rest(int duration, String type) =>
    '<note><rest/><duration>$duration</duration><voice>1</voice><type>$type</type></note>';

String _chord(
  String root, {
  String kind = 'major',
  int alter = 0,
  String? bass,
  String degrees = '',
  int? offset,
}) =>
    '<harmony><root><root-step>$root</root-step>'
    '${alter == 0 ? '' : '<root-alter>$alter</root-alter>'}</root>'
    '<kind>$kind</kind>'
    '${bass == null ? '' : '<bass><bass-step>$bass</bass-step></bass>'}'
    '$degrees${offset == null ? '' : '<offset>$offset</offset>'}</harmony>';

const _whole = 16;

/// The piano part's notes of bar [index] on [staff], one string per chord:
/// "onset:duration" and the pitches from the bottom up, or "-" for a rest.
List<String> _hand(String xml, int index, int staff, {int part = 1}) {
  final measure = _codec.decodeXml(xml).parts[part].measures[index];
  final out = <String>[];
  for (final note in measure.events.whereType<MusicNote>()) {
    if (note.staff != staff) continue;
    final pitch = note.pitch;
    final name = pitch == null
        ? '-'
        : '${pitch.step.name.toUpperCase()}'
              '${pitch.alter > 0 ? '#' * pitch.alter : 'b' * -pitch.alter}'
              '${pitch.octave}';
    if (note.isChord) {
      out.last = '${out.last} $name';
    } else {
      out.add('${note.onset}:${note.duration} $name');
    }
  }
  return out;
}

XmlElement _pianoBar(String xml, int index, {int part = 1}) =>
    XmlDocument.parse(xml).rootElement
        .findElements('part')
        .elementAt(part)
        .findElements('measure')
        .elementAt(index);

void main() {
  group('analysis', () {
    test('a melody with chord symbols can get a piano part', () {
      final analysis = analyzeLeadSheet(
        _score([
          _bar(1, _rest(_whole, 'whole')),
          _bar(2, '${_chord('G')}${_note('D', 5, _whole, 'whole')}'),
          _bar(3, _note('B', 4, _whole, 'whole')),
          _bar(4, '${_chord('C', kind: 'none')}${_rest(_whole, 'whole')}'),
        ], fifths: 1),
      );

      expect(analysis.convertible, isTrue);
      expect(analysis.measureCount, 4);
      expect(analysis.chordCount, 1);
      // Bars 2 and 3: bar 1 is before the chord, bar 4 is "N.C.".
      expect(analysis.measuresWithChord, 2);
      expect(analysis.keyFifths, 1);
      expect((analysis.beats, analysis.beatType), (4, 4));
      expect((analysis.lowestMidi, analysis.highestMidi), (71, 74));
    });

    test('names what stands in the way', () {
      final plain = _bar(1, _note('C', 5, _whole, 'whole'));
      final chorded = _bar(
        1,
        '${_chord('C')}${_note('C', 5, _whole, 'whole')}',
      );

      expect(
        analyzeLeadSheet(_score([plain])).obstacle,
        ThreeStaffObstacle.noChords,
      );
      expect(
        analyzeLeadSheet(_score([chorded], staves: 2)).obstacle,
        ThreeStaffObstacle.severalStaves,
      );
      expect(
        analyzeLeadSheet(
          _score([chorded], extraPart: '<part id="P2">$plain</part>'),
        ).obstacle,
        ThreeStaffObstacle.severalParts,
      );
      expect(() => threeStaffMusicXml(_score([plain])), throwsFormatException);
    });
  });

  group('made again', () {
    final lead = _score([
      _bar(1, '${_chord('C')}${_note('E', 5, _whole, 'whole')}'),
      _bar(2, '${_chord('G')}${_note('D', 5, _whole, 'whole')}'),
    ]);
    const plan = AccompanimentPlan(
      base: AccompanimentStyle(register: AccompanimentRegister.low),
      sections: {1: AccompanimentStyle(pattern: AccompanimentPattern.beats)},
    );

    test('the style is kept in the file with the part', () {
      final out = threeStaffMusicXml(lead, pianoName: '피아노', plan: plan);

      final generated = generatedPianoPart(out)!;
      expect(generated.name, '피아노');
      expect(generated.plan.base, plan.base);
      expect(generated.plan.sections, plan.sections);
      // Where MusicXML keeps a program's own data, before the part list.
      final root = XmlDocument.parse(out).rootElement;
      expect(root.childElements.map((e) => e.name.local).take(2), [
        'identification',
        'part-list',
      ]);
      expect(generatedPianoPart(lead), isNull);
    });

    test('taking the part away gives back the lead sheet', () {
      final out = threeStaffMusicXml(lead, plan: plan);

      expect(
        XmlDocument.parse(withoutGeneratedPianoPart(out)).toXmlString(),
        XmlDocument.parse(lead).toXmlString(),
      );
      expect(withoutGeneratedPianoPart(lead), same(lead));
    });

    test('follows an edited chord, in the same style', () {
      final out = threeStaffMusicXml(lead, plan: plan);
      // G becomes E minor in bar 2.
      final edited = out.replaceFirst(
        '<root-step>G</root-step></root><kind>major</kind>',
        '<root-step>E</root-step></root><kind>minor</kind>',
      );

      final again = regeneratePianoPart(edited);

      expect(_hand(again, 0, 2), ['0:16 C3']);
      expect(_hand(again, 1, 2), ['0:16 E2']);
      // Bar 2 still strikes on every beat.
      expect(_hand(again, 1, 1), hasLength(4));
      expect(_hand(again, 1, 1).first, '0:4 G3 B3 E4');
      expect(
        XmlDocument.parse(again).rootElement.findElements('part'),
        hasLength(2),
      );
      expect(generatedPianoPart(again)?.plan.sections, plan.sections);
      // Unchanged input gives the same part again.
      expect(regeneratePianoPart(out), out);
      expect(regeneratePianoPart(lead), same(lead));
    });

    test('another style can be asked for', () {
      final again = regeneratePianoPart(
        threeStaffMusicXml(lead, plan: plan),
        plan: const AccompanimentPlan(
          base: AccompanimentStyle(pattern: AccompanimentPattern.broken),
        ),
      );

      expect(_hand(again, 0, 1), hasLength(8));
      expect(generatedPianoPart(again)?.plan.sections, isEmpty);
    });

    test('with every chord symbol removed the piano rests', () {
      final out = threeStaffMusicXml(lead, plan: plan);
      final bare = out.replaceAll(RegExp('<harmony>.*?</harmony>'), '');

      final again = regeneratePianoPart(bare);

      expect(_hand(again, 0, 1), ['0:16 -']);
      expect(_hand(again, 1, 2), ['0:16 -']);
    });

    test('section styles are dropped when the bars are no longer the same', () {
      final out = threeStaffMusicXml(lead, plan: plan);
      // A copy with bar 2 played twice.
      final bar2 = RegExp('<measure number="2">.*?</measure>');
      final longer = out.replaceAllMapped(
        bar2,
        (match) => '${match.group(0)}${match.group(0)}',
      );

      final generated = generatedPianoPart(longer)!;

      expect(generated.plan.base, plan.base);
      expect(generated.plan.sections, isEmpty);
    });
  });

  group('by section', () {
    // Intro 1-2, verse 3-4, pre-chorus 5, chorus 6-7, bridge 8, outro 9.
    final lead = _score([
      for (var bar = 1; bar <= 9; bar++)
        _bar(
          bar,
          '${_chord(bar.isOdd ? 'C' : 'F')}${_note('E', 5, _whole, 'whole')}',
        ),
    ]);
    const roles = {
      0: SectionRole.intro,
      2: SectionRole.verse,
      4: SectionRole.preChorus,
      5: SectionRole.chorus,
      7: SectionRole.bridge,
      8: SectionRole.outro,
    };
    String make(AccompanimentInstrument instrument) => accompanimentMusicXml(
      lead,
      setup: AccompanimentSetup(instruments: [instrument], roles: roles),
    );
    int voices(String xml, int bar) =>
        _hand(xml, bar, 1).first.split(' ').length - 1;
    List<String> dynamics(String xml) => [
      for (final d in XmlDocument.parse(xml).findAllElements('dynamics'))
        d.childElements.single.name.local,
    ];

    test('roles come from the section names of the structure panel', () {
      expect(SectionRole.fromSectionName('INTRO'), SectionRole.intro);
      expect(SectionRole.fromSectionName('PRE'), SectionRole.preChorus);
      expect(SectionRole.fromSectionName('chorus'), SectionRole.chorus);
      expect(SectionRole.fromSectionName('프'), SectionRole.unknown);
      expect(SectionRole.fromSectionName('Verse 2'), SectionRole.verse);
      expect(SectionRole.fromSectionName('CHORUS1'), SectionRole.chorus);
      expect(SectionRole.fromSectionName('후렴'), SectionRole.chorus);
      expect(SectionRole.fromSectionName('간주'), SectionRole.interlude);
      const setup = AccompanimentSetup(roles: roles);
      expect(setup.roleAt(0), SectionRole.intro);
      expect(setup.roleAt(3), SectionRole.verse);
      expect(setup.roleAt(6), SectionRole.chorus);
      expect(setup.roleAt(20), SectionRole.outro);
      expect(const AccompanimentSetup().roleAt(0), SectionRole.unknown);
    });

    test('the piano picks its pattern by section unless told otherwise', () {
      final out = make(AccompanimentInstrument.piano);

      expect(_hand(out, 0, 1), hasLength(1)); // intro: held
      expect(_hand(out, 2, 1), hasLength(8)); // verse: broken
      expect(_hand(out, 4, 1), hasLength(4)); // pre-chorus: every beat
      expect(_hand(out, 5, 1), hasLength(4)); // chorus: every beat
      // ... with octaves in the left hand, and single bass notes elsewhere.
      expect(_hand(out, 5, 2), ['0:16 F2 F3']);
      expect(_hand(out, 4, 2), ['0:16 C3']);
      expect(_hand(out, 7, 1), hasLength(1)); // bridge: held, low
      expect(_hand(out, 7, 1).single, endsWith('F4'));
      expect(dynamics(out), ['mp', 'mp', 'mf', 'f', 'mp', 'mp']);

      final told = accompanimentMusicXml(
        lead,
        setup: const AccompanimentSetup(
          roles: roles,
          piano: AccompanimentPlan(
            base: AccompanimentStyle(pattern: AccompanimentPattern.held),
          ),
        ),
      );
      expect(_hand(told, 2, 1), hasLength(1));
      expect(_hand(told, 5, 2), ['0:16 F2']);
    });

    test('the organ thickens from three voices to four with an octave', () {
      final out = make(AccompanimentInstrument.organ);

      // Triads: three voices, four with the octave in the chorus.
      expect(voices(out, 0), 3);
      expect(voices(out, 2), 3);
      expect(voices(out, 4), 3);
      expect(voices(out, 5), 4);
      expect(voices(out, 8), 3);
      expect(dynamics(out), ['p', 'p', 'mp', 'mf', 'p', 'p']);
    });

    test('strings hold one line in the verse and open up in the chorus', () {
      final out = make(AccompanimentInstrument.strings);

      expect(voices(out, 0), 1);
      expect(voices(out, 2), 1);
      expect(voices(out, 4), 2);
      expect(voices(out, 5), 4);
      expect(voices(out, 7), 2);
      // The bridge lies low; the chorus reaches up.
      expect(_hand(out, 7, 1).single.split(' ').last, endsWith('4'));
      expect(_hand(out, 5, 1).single.split(' ').last, 'C6');
      expect(dynamics(out), ['p', 'p', 'mp', 'f', 'p', 'p']);
    });

    test('the pad widens from an open fifth to a full voicing', () {
      final out = make(AccompanimentInstrument.pad);

      expect(_hand(out, 0, 1), ['0:16 C3 G3 C4']);
      expect(_hand(out, 4, 1), ['0:16 C3 G3 C4 E4']);
      expect(_hand(out, 5, 1), ['0:16 F3 C4 F4 A4']);
      expect(_hand(out, 7, 1), ['0:16 F3 C4']);
      expect(dynamics(out), ['pp', 'pp', 'p', 'mp', 'pp', 'pp']);
      // Suspended chords put the suspended tone on top.
      final sus = accompanimentMusicXml(
        _score([
          _bar(
            1,
            '${_chord('G', kind: 'suspended-fourth')}${_note('D', 5, _whole, 'whole')}',
          ),
        ]),
        setup: const AccompanimentSetup(
          instruments: [AccompanimentInstrument.pad],
        ),
      );
      expect(_hand(sus, 0, 1), ['0:16 G3 D4 G4 C5']);
    });

    test('brass rests in the verse, leads in, and drives the chorus out', () {
      final out = make(AccompanimentInstrument.brass);
      List<String> onsets(int bar) =>
          _hand(out, bar, 1).map((s) => s.split(' ').first).toList();

      expect(_hand(out, 0, 1), ['0:16 -']); // intro: tacet
      expect(_hand(out, 1, 1).first, isNot(endsWith('-'))); // lead-in bar
      expect(_hand(out, 2, 1), ['0:16 -']); // verse: tacet
      expect(_hand(out, 3, 1).first, isNot(endsWith('-'))); // lead-in bar
      // Pre-chorus: one hit, then rest.
      expect(onsets(4), ['0:4', '4:12']);
      // Chorus: beats 1 and 3; its last bar on every beat.
      expect(onsets(5), ['0:4', '4:4', '8:4', '12:4']);
      expect(_hand(out, 5, 1)[1], endsWith('-'));
      expect(onsets(6), ['0:4', '4:4', '8:4', '12:4']);
      expect(_hand(out, 6, 1).every((s) => !s.endsWith('-')), isTrue);
      // A one-bar bridge is all lead-in.
      expect(onsets(7), ['0:4', '4:12']);
      expect(_hand(out, 8, 1), hasLength(1)); // outro: held to the end
      expect(_hand(out, 8, 1).single, isNot(endsWith('-')));
      expect(dynamics(out), ['mf', 'f', 'f']);
    });

    test('organ and strings hold the bass under slash chords', () {
      // G, G/B | C, G/B | Am7, D7: the bass stays on G under G/B, and on
      // C under nothing else; it moves for a new root.
      final xml = _score([
        _bar(
          1,
          '${_chord('G')}${_note('D', 5, 8, 'half')}'
          '${_chord('G', bass: 'B')}${_note('D', 5, 8, 'half')}',
        ),
        _bar(
          2,
          '${_chord('C')}${_note('E', 5, 8, 'half')}'
          '${_chord('G', bass: 'B')}${_note('D', 5, 8, 'half')}',
        ),
        _bar(
          3,
          '${_chord('A', kind: 'minor-seventh')}${_note('E', 5, 8, 'half')}'
          '${_chord('D', kind: 'dominant')}${_note('D', 5, 8, 'half')}',
        ),
        // C then A minor: C is the third of A minor and stays.
        _bar(
          4,
          '${_chord('C')}${_note('E', 5, 8, 'half')}'
          '${_chord('A', kind: 'minor')}${_note('E', 5, 8, 'half')}',
        ),
      ], fifths: 1);

      for (final instrument in [
        AccompanimentInstrument.organ,
        AccompanimentInstrument.strings,
      ]) {
        final out = accompanimentMusicXml(
          xml,
          setup: AccompanimentSetup(instruments: [instrument]),
        );

        expect(_hand(out, 0, 2), ['0:8 G2', '8:8 G2'], reason: instrument.name);
        expect(_hand(out, 1, 2), ['0:8 C3', '8:8 B2']);
        expect(_hand(out, 2, 2), ['0:8 A2', '8:8 D3']);
        expect(_hand(out, 3, 2), ['0:8 C3', '8:8 C3']);
        // Held, not struck again.
        final bass = _pianoBar(out, 0)
            .findElements('note')
            .where((n) => n.getElement('staff')?.innerText == '2');
        expect(
          bass.map(
            (n) =>
                n.findElements('tie').map((t) => t.getAttribute('type')).join(),
          ),
          ['start', 'stop'],
        );
      }
      // The piano walks the bass as written.
      final piano = threeStaffMusicXml(xml);
      expect(_hand(piano, 0, 2), ['0:8 G2', '8:8 B2']);
    });

    test('strings and pad pass over chords of under two beats', () {
      // G/B for a beat and a half, D7 for one beat, G for a beat and a half.
      final xml = _score([
        _bar(
          1,
          '${_chord('G', bass: 'B')}${_note('D', 5, 6, 'quarter')}'
          '${_chord('D', kind: 'dominant')}${_note('D', 5, 4, 'quarter')}'
          '${_chord('G')}${_note('D', 5, 6, 'quarter')}',
        ),
        _bar(2, '${_chord('C')}${_note('E', 5, _whole, 'whole')}'),
      ], fifths: 1);
      String make(AccompanimentInstrument instrument) => accompanimentMusicXml(
        xml,
        setup: AccompanimentSetup(instruments: [instrument]),
      );
      List<String> onsets(String out) =>
          _hand(out, 0, 1).map((s) => s.split(' ').first).toList();

      // One harmony for the bar: G, in the pad and in the strings.
      expect(_hand(make(AccompanimentInstrument.pad), 0, 1), [
        '0:16 G3 D4 G4 B4',
      ]);
      expect(onsets(make(AccompanimentInstrument.strings)), ['0:16']);
      expect(_hand(make(AccompanimentInstrument.strings), 0, 2), ['0:16 B2']);
      // The organ and the piano play every chord.
      expect(
        onsets(make(AccompanimentInstrument.organ)).length,
        greaterThan(2),
      );
      expect(
        _hand(
          make(AccompanimentInstrument.piano),
          0,
          2,
        ).map((s) => s.split(' ').last).toSet(),
        {'B2', 'D3', 'G2'},
      );
      // The next bar is its own chord again.
      expect(_hand(make(AccompanimentInstrument.pad), 1, 1), [
        '0:16 C3 G3 C4 E4',
      ]);
    });

    test('density thins the parts out or fills them in', () {
      String make(
        AccompanimentInstrument instrument,
        AccompanimentDensity density,
      ) => accompanimentMusicXml(
        lead,
        setup: AccompanimentSetup(
          instruments: [instrument],
          roles: roles,
          density: density,
        ),
      );
      const light = AccompanimentDensity.light;
      const full = AccompanimentDensity.full;

      // Organ: bar 6 is the chorus (four voices with the octave).
      expect(voices(make(AccompanimentInstrument.organ, light), 5), 3);
      expect(voices(make(AccompanimentInstrument.organ, full), 2), 4);
      // Strings: one line in the verse, two when full; never over three
      // when light.
      expect(voices(make(AccompanimentInstrument.strings, full), 2), 2);
      expect(voices(make(AccompanimentInstrument.strings, light), 5), 3);
      // Pad: the third comes in with a full part, and goes in a light one.
      expect(_hand(make(AccompanimentInstrument.pad, full), 0, 1), [
        '0:16 C3 G3 C4 E4',
      ]);
      expect(_hand(make(AccompanimentInstrument.pad, light), 5, 1), [
        '0:16 F3 C4 F4',
      ]);
      // Piano: octaves in the left hand throughout a full part, none in a
      // light one.
      expect(_hand(make(AccompanimentInstrument.piano, full), 0, 2), [
        '0:16 C3 C4',
      ]);
      expect(_hand(make(AccompanimentInstrument.piano, light), 5, 2), [
        '0:16 F2',
      ]);
      final again = make(AccompanimentInstrument.organ, full);
      expect(generatedAccompaniment(again)!.setup.density, full);
      expect(regenerateAccompaniment(again), again);
    });

    test('the split point keeps the right hand on or above it', () {
      List<int> lowest(int? split) {
        final out = accompanimentMusicXml(
          lead,
          setup: AccompanimentSetup(roles: roles, splitPoint: split),
        );
        final piano = _codec.decodeXml(out).parts[1];
        return [
          for (final measure in piano.measures)
            measure.events
                .whereType<MusicNote>()
                .where((n) => n.staff == 1 && n.pitch != null)
                .map((n) => n.pitch!.midi)
                .reduce((a, b) => a < b ? a : b),
        ];
      }

      expect(lowest(null).any((midi) => midi < 60), isTrue);
      expect(lowest(60).every((midi) => midi >= 60), isTrue);
      expect(lowest(55).every((midi) => midi >= 55), isTrue);
      final out = accompanimentMusicXml(
        lead,
        setup: const AccompanimentSetup(splitPoint: 60),
      );
      expect(generatedAccompaniment(out)!.setup.splitPoint, 60);
      expect(regenerateAccompaniment(out), out);
    });

    test('roles are kept with the parts and used when made again', () {
      final out = make(AccompanimentInstrument.strings);

      expect(generatedAccompaniment(out)!.setup.roles, roles);
      expect(regenerateAccompaniment(out), out);
      // Without roles the same score is one middle way throughout.
      final plain = accompanimentMusicXml(
        lead,
        setup: const AccompanimentSetup(
          instruments: [AccompanimentInstrument.strings],
        ),
      );
      expect(voices(plain, 2), 3);
      expect(dynamics(plain), isEmpty);
    });
  });

  group('other instruments', () {
    // C for two bars, then G restated, then G into a repeat.
    final lead = _score([
      _bar(1, '${_chord('C')}${_note('E', 5, _whole, 'whole')}'),
      _bar(2, _note('E', 5, _whole, 'whole')),
      _bar(
        3,
        '${_chord('G')}${_note('D', 5, _whole, 'whole')}'
        '<barline location="right"><repeat direction="backward"/></barline>',
      ),
      _bar(4, _note('D', 5, _whole, 'whole')),
      _bar(5, '${_chord('G')}${_note('D', 5, _whole, 'whole')}'),
    ]);
    List<String> ties(String xml, int bar, {int part = 1}) => [
      for (final note in _pianoBar(xml, bar, part: part).findElements('note'))
        note.findElements('tie').map((t) => t.getAttribute('type')).join('+'),
    ];

    test(
      'the organ holds a chord over the barline, the piano strikes again',
      () {
        final out = accompanimentMusicXml(
          lead,
          setup: const AccompanimentSetup(
            instruments: [
              AccompanimentInstrument.piano,
              AccompanimentInstrument.organ,
            ],
          ),
        );

        // Same notes in both.
        expect(_hand(out, 1, 1, part: 2), _hand(out, 1, 1));
        expect(_hand(out, 0, 2, part: 2), ['0:16 C3']);
        expect(ties(out, 0), everyElement(''));
        expect(ties(out, 1), everyElement(''));
        // Organ: bar 1 tied into bar 2, in both hands; into bar 3 only the G
        // that C and G have in common is held on.
        expect(ties(out, 0, part: 2), everyElement('start'));
        expect(ties(out, 1, part: 2), ['stop', 'stop', 'stop+start', 'stop']);
        expect(ties(out, 2, part: 2), ['', '', 'stop', '']);
        // Not over a repeat sign; held on into the restated G.
        expect(ties(out, 3, part: 2), everyElement('start'));
        expect(ties(out, 4, part: 2), everyElement('stop'));
      },
    );

    test('a tie over the barline carries the accidental', () {
      // D major chord in C: F sharp marked in bar 1, not again in bar 2.
      final xml = _score([
        _bar(1, '${_chord('D')}${_note('A', 5, _whole, 'whole')}'),
        _bar(2, _note('A', 5, _whole, 'whole')),
      ]);

      final out = accompanimentMusicXml(
        xml,
        setup: const AccompanimentSetup(
          instruments: [AccompanimentInstrument.pad],
        ),
      );

      int accidentals(int bar) =>
          _pianoBar(out, bar).findAllElements('accidental').length;
      expect(accidentals(0), 1);
      expect(accidentals(1), 0);
      // A pad is one staff of chords, without a bass.
      expect(_pianoBar(out, 0).findAllElements('staves'), isEmpty);
      expect(_pianoBar(out, 0).findAllElements('backup'), isEmpty);
      // Root, fifth, octave and third, wide.
      expect(_hand(out, 0, 1), ['0:16 D3 A3 D4 F#4']);
    });

    test('strings lie above middle C, brass plays one beat in three parts', () {
      final seventh = _score([
        _bar(
          1,
          '${_chord('G', kind: 'dominant')}${_note('B', 4, 8, 'half')}'
          '${_chord('C')}${_note('C', 5, 8, 'half')}',
        ),
      ]);

      final out = accompanimentMusicXml(
        seventh,
        setup: const AccompanimentSetup(
          instruments: [
            AccompanimentInstrument.strings,
            AccompanimentInstrument.brass,
          ],
        ),
      );

      // G4 on top at the lowest, under the melody where that fits.
      expect(_hand(out, 0, 1), ['0:8 B3 D4 F4 G4', '8:8 C4 E4 G4']);
      expect(_hand(out, 0, 2), ['0:8 G2', '8:8 C3']);
      // Three parts (the root is left out of the seventh chord), one beat,
      // then a rest to the next chord.
      expect(_hand(out, 0, 1, part: 2), [
        '0:4 B3 D4 F4',
        '4:4 -',
        '8:4 C4 E4 G4',
        '12:4 -',
      ]);
    });

    test('every part is recorded with its sound, and made again together', () {
      final out = accompanimentMusicXml(
        lead,
        setup: const AccompanimentSetup(
          instruments: [
            AccompanimentInstrument.strings,
            AccompanimentInstrument.piano,
          ],
          piano: AccompanimentPlan(
            base: AccompanimentStyle(pattern: AccompanimentPattern.beats),
          ),
        ),
        names: const {AccompanimentInstrument.strings: '스트링'},
      );

      final document = XmlDocument.parse(out);
      expect(document.findAllElements('part-name').map((e) => e.innerText), [
        'Voice',
        '스트링',
        'Piano',
      ]);
      expect(document.findAllElements('midi-program').map((e) => e.innerText), [
        '49',
        '1',
      ]);
      // Each part says what it is over its first bar; a piano alone does not.
      expect(document.findAllElements('words').map((e) => e.innerText), [
        '스트링',
        'Piano',
      ]);
      expect(
        XmlDocument.parse(threeStaffMusicXml(lead)).findAllElements('words'),
        isEmpty,
      );
      final generated = generatedAccompaniment(out)!;
      expect(generated.setup.instruments, [
        AccompanimentInstrument.strings,
        AccompanimentInstrument.piano,
      ]);
      expect(generated.names[AccompanimentInstrument.strings], '스트링');
      expect(generated.setup.piano.base.pattern, AccompanimentPattern.beats);
      expect(generatedPianoPart(out)?.partId, generated.partIds[1]);

      expect(regenerateAccompaniment(out), out);
      expect(
        XmlDocument.parse(withoutGeneratedAccompaniment(out)).toXmlString(),
        XmlDocument.parse(lead).toXmlString(),
      );
      // Other instruments, the same melody.
      final other = regenerateAccompaniment(
        out,
        setup: const AccompanimentSetup(
          instruments: [AccompanimentInstrument.organ],
        ),
      );
      expect(
        XmlDocument.parse(
          other,
        ).findAllElements('part-name').map((e) => e.innerText),
        ['Voice', 'Organ'],
      );
      expect(generatedPianoPart(other), isNull);
      expect(
        () => accompanimentMusicXml(
          lead,
          setup: const AccompanimentSetup(instruments: []),
        ),
        throwsFormatException,
      );
    });

    test('a score recorded before other instruments existed is still read', () {
      final now = threeStaffMusicXml(
        lead,
        plan: const AccompanimentPlan(
          base: AccompanimentStyle(pattern: AccompanimentPattern.broken),
          sections: {
            2: AccompanimentStyle(register: AccompanimentRegister.low),
          },
        ),
      );
      // The record as it was first written.
      final old = now.replaceFirstMapped(
        RegExp(
          '<miscellaneous-field name="page-a-diddle:accompaniment">.*?</miscellaneous-field>',
        ),
        (_) =>
            '<miscellaneous-field name="page-a-diddle:piano-part">'
            '{&quot;part&quot;:&quot;P2&quot;,&quot;bars&quot;:5,'
            '&quot;base&quot;:{&quot;pattern&quot;:&quot;broken&quot;,&quot;register&quot;:&quot;middle&quot;},'
            '&quot;sections&quot;:{&quot;2&quot;:{&quot;pattern&quot;:&quot;auto&quot;,&quot;register&quot;:&quot;low&quot;}}}'
            '</miscellaneous-field>',
      );
      expect(old, isNot(now));

      final generated = generatedPianoPart(old)!;

      expect(generated.plan.base.pattern, AccompanimentPattern.broken);
      expect(generated.plan.sections.keys, [2]);
      // Made again, it carries the record of today.
      expect(regenerateAccompaniment(old), now);
    });
  });

  group('piano part', () {
    test('holds each chord under the melody, bass in the left hand', () {
      final xml = _score([
        _bar(1, '${_chord('C')}${_note('E', 5, _whole, 'whole')}'),
        _bar(
          2,
          '${_chord('G', bass: 'B')}${_note('D', 5, 8, 'half')}'
          '${_chord('A', kind: 'minor-seventh')}${_note('C', 5, 8, 'half')}',
        ),
      ]);

      final out = threeStaffMusicXml(xml);

      // Close position with the top near G4, then the nearest voicings.
      expect(_hand(out, 0, 1), ['0:16 C4 E4 G4']);
      expect(_hand(out, 0, 2), ['0:16 C3']);
      expect(_hand(out, 1, 1), ['0:8 B3 D4 G4', '8:8 A3 C4 E4 G4']);
      expect(_hand(out, 1, 2), ['0:8 B2', '8:8 A2']);
    });

    test('leaves the melody part exactly as written', () {
      final xml = _score([
        _bar(
          1,
          '<print new-system="yes"/>${_chord('C')}${_note('E', 5, _whole, 'whole')}',
        ),
      ]);
      String melody(String source) => XmlDocument.parse(
        source,
      ).rootElement.findElements('part').first.toXmlString();

      final out = threeStaffMusicXml(xml, pianoName: '피아노');

      expect(melody(out), melody(xml));
      final document = XmlDocument.parse(out);
      expect(document.findAllElements('part-name').map((e) => e.innerText), [
        'Voice',
        '피아노',
      ]);
      final piano = document.rootElement.findElements('part').last;
      expect(piano.findAllElements('staves').single.innerText, '2');
      expect(
        piano
            .findAllElements('clef')
            .map((c) => c.getElement('sign')!.innerText),
        ['G', 'F'],
      );
      // Made once: the result has two parts.
      expect(() => threeStaffMusicXml(out), throwsFormatException);
    });

    test('rests before the first chord and on N.C.; strikes held chords '
        'again at the barline', () {
      final xml = _score([
        _bar(1, _note('E', 5, _whole, 'whole')),
        _bar(2, '${_chord('F')}${_note('F', 5, _whole, 'whole')}'),
        _bar(3, _note('F', 5, _whole, 'whole')),
        _bar(
          4,
          '${_note('F', 5, 8, 'half')}${_chord('C', kind: 'none')}${_note('E', 5, 8, 'half')}',
        ),
      ]);

      final out = threeStaffMusicXml(xml);

      expect(_hand(out, 0, 1), ['0:16 -']);
      expect(_hand(out, 0, 2), ['0:16 -']);
      expect(_hand(out, 1, 1), ['0:16 A3 C4 F4']);
      expect(_hand(out, 2, 1), _hand(out, 1, 1));
      expect(_hand(out, 2, 2), ['0:16 F2']);
      expect(_hand(out, 3, 1), ['0:8 A3 C4 F4', '8:8 -']);
      // No ties over the barline.
      expect(_pianoBar(out, 1).findAllElements('tie'), isEmpty);
    });

    test('a chord off the beat is tied to the beat', () {
      // G on the "and" of beat 2.
      final xml = _score([
        _bar(
          1,
          '${_chord('C')}${_note('E', 5, 6, 'quarter')}${_chord('G')}'
          '${_note('D', 5, 10, 'half')}',
        ),
      ]);

      final out = threeStaffMusicXml(xml);

      expect(_hand(out, 0, 2), ['0:6 C3', '6:2 G2', '8:8 G2']);
      final left = _pianoBar(out, 0)
          .findElements('note')
          .where((n) => n.getElement('staff')!.innerText == '2')
          .toList();
      expect(left.map((n) => n.getElement('type')!.innerText), [
        'quarter',
        'eighth',
        'half',
      ]);
      expect(left[0].getElement('dot'), isNotNull);
      expect(
        left.map(
          (n) =>
              n.findElements('tie').map((t) => t.getAttribute('type')).join(),
        ),
        ['', 'start', 'stop'],
      );
    });

    test('a chord placed by an offset changes on its beat', () {
      final xml = _score([
        _bar(
          1,
          '${_chord('C')}${_chord('F', offset: 8)}${_note('E', 5, _whole, 'whole')}',
        ),
      ]);

      expect(_hand(threeStaffMusicXml(xml), 0, 2), ['0:8 C3', '8:8 F2']);
    });

    test('a chord shorter than a beat is not struck', () {
      final xml = _score([
        // A over the last two sixteenths: it belongs to the next bar.
        _bar(
          1,
          '${_chord('F')}${_note('A', 5, 14, 'half')}${_chord('A')}'
          '${_note('E', 5, 2, 'eighth')}',
        ),
        _bar(2, _note('E', 5, _whole, 'whole')),
        // G written a sixteenth late, and a passing E minor for half a beat.
        _bar(
          3,
          '${_note('D', 5, 1, '16th')}${_chord('G')}${_note('D', 5, 7, 'quarter')}'
          '${_chord('E', kind: 'minor')}${_note('D', 5, 2, 'eighth')}'
          '${_chord('C')}${_note('E', 5, 6, 'quarter')}',
        ),
      ]);

      final out = threeStaffMusicXml(xml);

      expect(_hand(out, 0, 2), ['0:16 F2']);
      expect(_hand(out, 1, 2), ['0:16 A2']);
      // G from the start of the bar and held through the E minor.
      expect(_hand(out, 2, 2), ['0:8 G2', '8:2 G2', '10:2 C3', '12:4 C3']);
    });

    test('a pickup shorter than a beat has no chord, the next bar has it', () {
      final xml = _score([
        _bar(
          0,
          '${_chord('G')}${_note('D', 5, 2, 'eighth')}',
          attributes: ' implicit="yes"',
        ),
        _bar(1, _note('G', 5, _whole, 'whole')),
      ]);

      final out = threeStaffMusicXml(xml);

      expect(_hand(out, 0, 2), ['0:2 -']);
      expect(_hand(out, 1, 2), ['0:16 G2']);
    });

    test('leaves out a chord tone a semitone from a held melody note', () {
      // F held over C: the E of the chord would sit right under it.
      final xml = _score([
        _bar(1, '${_chord('C')}${_note('F', 4, _whole, 'whole')}'),
        // A passing F does not push the E out.
        _bar(
          2,
          '${_chord('C')}${_note('F', 4, 2, 'eighth')}${_note('G', 4, 14, 'half')}',
        ),
      ]);

      final out = threeStaffMusicXml(xml);

      expect(_hand(out, 0, 1), ['0:16 G3 C4']);
      expect(_hand(out, 1, 1), ['0:16 G3 C4 E4']);
    });

    group('patterns', () {
      final xml = _score([
        _bar(
          1,
          '${_chord('C')}${_note('E', 5, 8, 'half')}${_chord('G')}'
          '${_note('D', 5, 8, 'half')}',
        ),
        _bar(2, '${_chord('F')}${_note('C', 5, _whole, 'whole')}'),
      ]);

      test('beats strikes the chord on every beat over a held bass', () {
        final out = threeStaffMusicXml(
          xml,
          plan: const AccompanimentPlan(
            base: AccompanimentStyle(pattern: AccompanimentPattern.beats),
          ),
        );

        expect(_hand(out, 0, 1), [
          '0:4 C4 E4 G4',
          '4:4 C4 E4 G4',
          '8:4 B3 D4 G4',
          '12:4 B3 D4 G4',
        ]);
        expect(_hand(out, 0, 2), ['0:8 C3', '8:8 G2']);
        expect(_pianoBar(out, 0).findAllElements('tie'), isEmpty);
      });

      test('broken plays the chord tones up and back in eighths', () {
        final out = threeStaffMusicXml(
          xml,
          plan: const AccompanimentPlan(
            base: AccompanimentStyle(pattern: AccompanimentPattern.broken),
          ),
        );

        expect(_hand(out, 0, 1), [
          '0:2 C4',
          '2:2 E4',
          '4:2 G4',
          '6:2 E4',
          '8:2 B3',
          '10:2 D4',
          '12:2 G4',
          '14:2 D4',
        ]);
        expect(_hand(out, 1, 1).take(5), [
          '0:2 A3',
          '2:2 C4',
          '4:2 F4',
          '6:2 C4',
          '8:2 A3',
        ]);
        expect(_hand(out, 1, 2), ['0:16 F2']);
        // Two eighths to a beam.
        expect(
          _pianoBar(out, 0).findAllElements('beam').map((b) => b.innerText),
          ['begin', 'end', 'begin', 'end', 'begin', 'end', 'begin', 'end'],
        );
      });

      test('the low register lies under the middle one', () {
        final out = threeStaffMusicXml(
          xml,
          plan: const AccompanimentPlan(
            base: AccompanimentStyle(register: AccompanimentRegister.low),
          ),
        );

        expect(_hand(out, 0, 1), ['0:8 E3 G3 C4', '8:8 G3 B3 D4']);
        expect(_hand(out, 1, 1), ['0:16 F3 A3 C4']);
      });

      test('a section takes its own style from its first bar', () {
        const plan = AccompanimentPlan(
          sections: {
            1: AccompanimentStyle(pattern: AccompanimentPattern.beats),
          },
        );

        final out = threeStaffMusicXml(xml, plan: plan);

        expect(plan.styleAt(0).pattern, AccompanimentPattern.auto);
        expect(plan.styleAt(5).pattern, AccompanimentPattern.beats);
        expect(_hand(out, 0, 1), hasLength(2));
        expect(_hand(out, 1, 1), hasLength(4));
      });
    });

    test('accidentals follow the key and the bar', () {
      final content =
          '${_chord('D')}${_note('A', 5, 8, 'half')}${_chord('G')}'
          '${_note('B', 5, 4, 'quarter')}${_chord('D')}${_note('A', 5, 4, 'quarter')}';
      List<String?> accidentals(String xml) => [
        for (final note in _pianoBar(xml, 0).findElements('note'))
          if (note.getElement('pitch')?.getElement('step')?.innerText == 'F')
            note.getElement('accidental')?.innerText,
      ];

      // C major: the first F sharp is marked, the next one is not.
      expect(accidentals(threeStaffMusicXml(_score([_bar(1, content)]))), [
        'sharp',
        null,
      ]);
      // D major has it in the key.
      expect(
        accidentals(threeStaffMusicXml(_score([_bar(1, content)], fifths: 2))),
        [null, null],
      );
    });

    test('reads sevenths, suspensions, added tones and flat roots', () {
      const addSeventh =
          '<degree><degree-value>7</degree-value><degree-alter>0</degree-alter>'
          '<degree-type>add</degree-type></degree>';
      final xml = _score([
        _bar(
          1,
          '${_chord('G', kind: 'dominant')}${_note('G', 5, _whole, 'whole')}',
        ),
        _bar(
          2,
          '${_chord('D', kind: 'suspended-fourth', degrees: addSeventh)}'
          '${_note('G', 5, _whole, 'whole')}',
        ),
        _bar(
          3,
          '${_chord('B', alter: -1, kind: 'major-seventh')}${_note('F', 5, _whole, 'whole')}',
        ),
        _bar(
          4,
          '${_chord('C', kind: 'major-ninth')}${_note('G', 5, _whole, 'whole')}',
        ),
      ]);

      final out = threeStaffMusicXml(xml);
      Set<String> letters(int bar) => {
        for (final name in _hand(out, bar, 1).single.split(' ').skip(1))
          name.substring(0, name.length - 1),
      };

      expect(letters(0), {'G', 'B', 'D', 'F'});
      expect(letters(1), {'D', 'G', 'A', 'C'});
      expect(letters(2), {'Bb', 'D', 'F', 'A'});
      // Five tones: the root is left to the left hand.
      expect(letters(3), {'E', 'G', 'B', 'D'});
      expect(_hand(out, 2, 2), ['0:16 Bb2']);
    });

    test('follows the melody bar for bar: pickup, repeats, key and time', () {
      final xml = _score([
        _bar(0, _note('G', 4, 4, 'quarter'), attributes: ' implicit="yes"'),
        _bar(
          1,
          '<barline location="left"><repeat direction="forward"/></barline>'
          '${_chord('C')}${_note('E', 5, _whole, 'whole')}'
          '<barline location="right"><ending number="1" type="start"/>'
          '<repeat direction="backward"/></barline>',
        ),
        _bar(
          2,
          '<attributes><key><fifths>1</fifths></key><time><beats>3</beats>'
          '<beat-type>4</beat-type></time></attributes>'
          '${_chord('G')}${_note('D', 5, 12, 'half')}',
        ),
      ]);

      final out = threeStaffMusicXml(xml);
      final score = _codec.decodeXml(out);
      final melody = score.parts[0].measures;
      final piano = score.parts[1].measures;

      expect(piano.length, melody.length);
      expect(piano[0].implicit, isTrue);
      expect(piano[0].number, '0');
      // The pickup is one beat long in the piano as well.
      expect(_hand(out, 0, 1), ['0:4 -']);
      expect(
        _pianoBar(out, 1).findElements('barline').map((b) => b.toXmlString()),
        XmlDocument.parse(xml).rootElement
            .findElements('part')
            .first
            .findElements('measure')
            .elementAt(1)
            .findElements('barline')
            .map((b) => b.toXmlString()),
      );
      expect(piano[2].attributes.keyFifths, 1);
      expect(piano[2].attributes.time?.beats, 3);
      expect(_hand(out, 2, 2), ['0:12 G2']);
      expect(
        _pianoBar(
          out,
          2,
        ).findAllElements('type').map((t) => t.innerText).toSet(),
        {'half'},
      );
    });
  });
}
