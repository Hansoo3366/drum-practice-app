import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_review.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_review_approvals.dart';

const _codec = MusicXmlCodec();

const _types = {
  'whole': ('w', 16),
  'half': ('h', 8),
  'quarter': ('q', 4),
  'eighth': ('8', 2),
  '16th': ('16', 1),
};
const _steps = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];

/// A note of a generated bar: its length in sixteenths (0 for a type the
/// divisions cannot write is never made).
typedef _Note = ({String? step, String type, int dots, int sixteenths});

/// Random lead-sheet bars (one voice; full, short, too long, pickups), with
/// AI suggestions of every kind, sensible and not, approved at random, as
/// the conversion review screen writes them. Whatever is approved, the
/// result is either a refusal the user can read or a score that still reads,
/// with nothing changed that was not approved.
void main() {
  test('random approvals never damage the score', () {
    final random = Random(20261003);
    var written = 0;
    var refused = 0;
    for (var round = 0; round < 3000; round++) {
      final beats = random.nextBool() ? 4 : 3;
      final divisions = [1, 2, 4, 12][random.nextInt(4)];
      final count = 1 + random.nextInt(5);
      final bars = <List<_Note>>[
        for (var i = 0; i < count; i++) _bar(random, beats, divisions),
      ];
      final xml = _xml(
        bars,
        beats: beats,
        divisions: divisions,
        random: random,
      );
      final review = <OmrReviewBar>[
        for (var i = 0; i < count; i++)
          if (random.nextInt(3) > 0)
            OmrReviewBar(
              partIndex: 0,
              measureIndex: i,
              measure: '$i',
              issues: const [],
              suggestions: [
                for (var n = random.nextInt(5); n > 0; n--)
                  _suggestion(random, bars[i], beats),
              ],
              uncertain: const [],
            ),
      ];
      final approved = <String, Set<int>>{
        for (final bar in review)
          bar.key: {
            for (var i = 0; i < bar.suggestions.length; i++)
              if (random.nextBool()) i,
          },
      };
      final where = 'round $round';

      // Nothing approved: the very same file.
      expect(withReviewApprovals(xml, review, const {}), xml, reason: where);

      final String result;
      try {
        result = withReviewApprovals(xml, review, approved);
      } on FormatException catch (error) {
        expect(error.message, isNotEmpty, reason: where);
        refused++;
        continue;
      }
      written++;
      expect(withReviewApprovals(xml, review, approved), result, reason: where);

      final before = _codec.decodeXml(xml).parts.single.measures;
      final after = _codec.decodeXml(result).parts.single.measures;
      expect(after.length, before.length, reason: '$where: bars');
      for (var i = 0; i < count; i++) {
        final chosen = [
          for (final bar in review)
            if (bar.measureIndex == i)
              for (final index in approved[bar.key]!) bar.suggestions[index],
        ];
        final fields = {for (final suggestion in chosen) suggestion.field};
        final at = '$where, bar $i $fields';
        expect(
          after[i].events.whereType<MusicHarmony>().length,
          before[i].events.whereType<MusicHarmony>().length,
          reason: '$at: chord symbols',
        );
        if (fields.isEmpty) {
          expect(_sounding(after[i]), _sounding(before[i]), reason: at);
          continue;
        }
        // Never longer than the time signature, unless it was before.
        expect(
          _length(after[i]),
          lessThanOrEqualTo(max(_length(before[i]), beats.toDouble())),
          reason: '$at: length',
        );
        if (!fields.contains('melody')) {
          expect(
            _lyrics(after[i]),
            _lyrics(before[i]),
            reason: '$at: lyrics stay on their notes',
          );
        }
        if (fields.every((field) => field == 'pitch')) {
          expect(
            _sounding(after[i]).map((note) => note.$2),
            _sounding(before[i]).map((note) => note.$2),
            reason: '$at: lengths',
          );
        }
      }
    }
    // Both outcomes are really exercised.
    expect(written, greaterThan(500));
    expect(refused, greaterThan(500));
  });
}

/// What sounds in a bar: pitch (or null) and length in quarters.
List<(String?, double)> _sounding(MusicMeasure measure) => [
  for (final note in measure.notes)
    (
      note.pitch == null
          ? null
          : '${note.pitch!.step.name}${note.pitch!.alter}${note.pitch!.octave}',
      note.duration / measure.attributes.divisions,
    ),
];

double _length(MusicMeasure measure) =>
    _sounding(measure).fold(0, (sum, note) => sum + note.$2);

List<String> _lyrics(MusicMeasure measure) => [
  for (final note in measure.notes) ...note.lyrics,
];

List<_Note> _bar(Random random, int beats, int divisions) {
  // What these divisions can write, in sixteenths.
  final types = [
    for (final MapEntry(key: type, value: (_, sixteenths)) in _types.entries)
      if (sixteenths * divisions % 4 == 0) type,
  ];
  // Mostly full bars; some short (a pickup, a dropped beat) or too long.
  final target = beats * 4 + [0, 0, 0, -4, -8, 4][random.nextInt(6)];
  final notes = <_Note>[];
  var total = 0;
  while (total < target || notes.isEmpty) {
    final type = types[random.nextInt(types.length)];
    final sixteenths = _types[type]!.$2;
    if (total + sixteenths > target && notes.isNotEmpty) {
      if (random.nextInt(4) == 0) break;
      continue;
    }
    notes.add((
      step: random.nextInt(5) == 0 ? null : _steps[random.nextInt(7)],
      type: type,
      dots: 0,
      sixteenths: sixteenths,
    ));
    total += sixteenths;
  }
  return notes;
}

String _xml(
  List<List<_Note>> bars, {
  required int beats,
  required int divisions,
  required Random random,
}) {
  final out = StringBuffer(
    '<score-partwise version="4.0"><part-list><score-part id="P1">'
    '<part-name>V</part-name></score-part></part-list><part id="P1">',
  );
  for (final (index, bar) in bars.indexed) {
    final short =
        bar.fold<int>(0, (sum, note) => sum + note.sixteenths) < beats * 4;
    out.write(
      '<measure number="${index + 1}"'
      '${index == 0 && short ? ' implicit="yes"' : ''}>',
    );
    if (index == 0) {
      out.write(
        '<attributes><divisions>$divisions</divisions>'
        '<key><fifths>${random.nextInt(5) - 2}</fifths></key>'
        '<time><beats>$beats</beats><beat-type>4</beat-type></time>'
        '<clef><sign>G</sign><line>2</line></clef></attributes>',
      );
    }
    for (final note in bar) {
      if (random.nextInt(4) == 0) {
        out.write(
          '<harmony><root><root-step>${_steps[random.nextInt(7)]}'
          '</root-step></root><kind>major</kind></harmony>',
        );
      }
      out.write('<note>');
      out.write(
        note.step == null
            ? '<rest/>'
            : '<pitch><step>${note.step}</step>'
                  '<octave>${4 + random.nextInt(2)}</octave></pitch>',
      );
      out.write(
        '<duration>${note.sixteenths * divisions ~/ 4}</duration>'
        '<voice>1</voice><type>${note.type}</type>',
      );
      if (note.step != null && random.nextBool()) {
        out.write(
          '<lyric number="1"><syllabic>single</syllabic>'
          '<text>${'가나다라마'[random.nextInt(5)]}</text></lyric>',
        );
      }
      out.write('</note>');
    }
    out.write('</measure>');
  }
  out.write('</part></score-partwise>');
  return out.toString();
}

String _length16(Random random) {
  final code = _types.values.elementAt(random.nextInt(_types.length)).$1;
  return '$code${random.nextInt(4) == 0 ? '.' : ''}';
}

String _pitch(Random random) => switch (random.nextInt(8)) {
  0 => 'H9',
  1 => '',
  _ =>
    '${_steps[random.nextInt(7)]}${['', '#', 'b'][random.nextInt(3)]}'
        '${3 + random.nextInt(3)}',
};

OmrReviewSuggestion _suggestion(Random random, List<_Note> bar, int beats) {
  // The note a suggestion names: mostly one that is there, sometimes not.
  final note = random.nextInt(8) == 0
      ? bar.length + 1 + random.nextInt(2)
      : 1 + random.nextInt(bar.length);
  final named = note <= bar.length ? bar[note - 1] : null;
  OmrReviewSuggestion make(
    String field, {
    required String current,
    required String suggested,
    int? note,
  }) => OmrReviewSuggestion(
    field: field,
    current: current,
    suggested: suggested,
    confidence: random.nextDouble(),
    applied: false,
    status: 'notes',
    note: note,
  );
  switch (random.nextInt(8)) {
    case 0:
      // Chords and lyrics are not written from the review screen.
      return make('chords', current: 'G', suggested: 'G/B');
    case 1:
    case 2:
      // A whole melody: one that fills the bar, or whatever came out.
      final tokens = <String>[];
      var left = beats * 4;
      while (left > 0) {
        final fits = [
          for (final (code, sixteenths) in _types.values)
            if (sixteenths <= left) (code, sixteenths),
        ];
        final (code, sixteenths) = fits[random.nextInt(fits.length)];
        tokens.add('${random.nextInt(5) == 0 ? 'rest' : _pitch(random)} $code');
        left -= sixteenths;
      }
      if (random.nextInt(4) == 0) tokens.add('C4 ${_length16(random)}');
      if (random.nextInt(6) == 0) tokens.removeLast();
      return make('melody', current: '', suggested: tokens.join(', '));
    case 3:
    case 4:
      return make(
        'pitch',
        note: random.nextInt(10) == 0 ? null : note,
        current: 'C4',
        suggested: _pitch(random),
      );
    default:
      // What the suggestion saw: the note's real length, or something else
      // (the model misread it, or the bar has changed since).
      final current = named == null || random.nextInt(5) == 0
          ? _length16(random)
          : _types[named.type]!.$1;
      return make(
        'duration',
        note: random.nextInt(10) == 0 ? null : note,
        current: random.nextInt(8) == 0 ? '?' : current,
        suggested: random.nextInt(10) == 0 ? 'x' : _length16(random),
      );
  }
}
