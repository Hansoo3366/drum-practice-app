import 'dart:io';
import 'dart:math';

import 'package:flutter_notemus/flutter_notemus.dart' as nm;
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_profile.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/digital_score/domain/xml_measure_editor.dart';
import 'package:page_a_diddle/features/digital_score/presentation/midi_duration.dart';
import 'package:xml/xml.dart';

const _codec = MusicXmlCodec();

/// What one bar of one part is, read straight from the file with nothing of
/// the app's own: the key, time and clefs it is played in, and every note
/// with its staff, the clef it is read in, its pitch and its length in
/// quarter notes. Two bars with the same reading are the same music on the
/// page and to the ear.
typedef _Bar = ({String start, List<String> notes});

List<List<_Bar>> _read(String xml) {
  final root = XmlDocument.parse(xml).rootElement;
  final parts = <List<_Bar>>[];
  for (final part in root.findElements('part')) {
    var divisions = 1;
    var fifths = 0;
    var time = '4/4';
    final clefs = <int, String>{};
    final bars = <_Bar>[];
    for (final measure in part.findElements('measure')) {
      String? start;
      final notes = <String>[];
      void begin() {
        start ??=
            'key $fifths time $time clefs '
            '${(clefs.entries.toList()..sort((a, b) => a.key.compareTo(b.key))).map((e) => '${e.key}:${e.value}').join(',')}';
      }

      for (final child in measure.childElements) {
        switch (child.name.local) {
          case 'attributes':
            final d = child.getElement('divisions')?.innerText.trim();
            if (d != null) divisions = int.parse(d);
            final f = child
                .getElement('key')
                ?.getElement('fifths')
                ?.innerText
                .trim();
            if (f != null) fifths = int.parse(f);
            final t = child.getElement('time');
            if (t != null) {
              time =
                  '${t.getElement('beats')!.innerText.trim()}/'
                  '${t.getElement('beat-type')!.innerText.trim()}';
            }
            for (final clef in child.findElements('clef')) {
              final staff = int.parse(clef.getAttribute('number') ?? '1');
              clefs[staff] =
                  '${clef.getElement('sign')!.innerText.trim()}'
                  '${clef.getElement('line')?.innerText.trim() ?? ''}';
            }
          case 'note':
            begin();
            final staff = int.parse(
              child.getElement('staff')?.innerText.trim() ?? '1',
            );
            final pitch = child.getElement('pitch');
            final what = pitch == null
                ? 'rest'
                : '${pitch.getElement('step')!.innerText.trim()}'
                      '${pitch.getElement('alter')?.innerText.trim() ?? ''}'
                      '${pitch.getElement('octave')!.innerText.trim()}';
            final duration = int.parse(
              child.getElement('duration')!.innerText.trim(),
            );
            // In quarters, as a fraction of 96 so it compares exactly.
            final length = duration * 96 ~/ divisions;
            expect(duration * 96 % divisions, 0);
            notes.add(
              's$staff ${clefs[staff] ?? '?'} $what $length'
              '${child.getElement('chord') != null ? ' chord' : ''}',
            );
          case 'backup' || 'forward':
            begin();
            final duration = int.parse(
              child.getElement('duration')!.innerText.trim(),
            );
            notes.add('${child.name.local} ${duration * 96 ~/ divisions}');
        }
      }
      begin();
      bars.add((start: start!, notes: notes));
    }
    parts.add(bars);
  }
  return parts;
}

const _times = [(4, 4), (3, 4), (6, 8), (2, 4)];
const _steps = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];

/// A score that changes under the player's feet: key, time, clef and the
/// file's own time unit change from bar to bar, a clef sometimes at the end
/// of the bar before (as it is printed), notes are tied over barlines, some
/// bars are repeated with endings, and the two parts have one and two staves.
String _score(Random r, int count) {
  final keyAt = <int, int>{0: r.nextInt(7) - 3};
  final timeAt = <int, (int, int)>{0: _times[r.nextInt(_times.length)]};
  final divisionsAt = <int, int>{
    0: [1, 2, 4][r.nextInt(3)],
  };
  for (var i = 1; i < count; i++) {
    if (r.nextInt(5) == 0) keyAt[i] = r.nextInt(9) - 4;
    if (r.nextInt(6) == 0) timeAt[i] = _times[r.nextInt(_times.length)];
    if (r.nextInt(5) == 0) divisionsAt[i] = [1, 2, 4, 8][r.nextInt(4)];
  }
  // A repeat with two endings somewhere, sometimes.
  int? repeatFrom;
  int? repeatTo;
  if (count >= 6 && r.nextBool()) {
    repeatFrom = r.nextInt(count - 4);
    repeatTo = repeatFrom + 2 + r.nextInt(2);
    if (repeatTo >= count - 1) repeatTo = count - 2;
  }
  final out = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8"?><score-partwise version="4.0">'
    '<part-list><score-part id="P1"><part-name>Voice</part-name></score-part>'
    '<score-part id="P2"><part-name>Piano</part-name></score-part>'
    '</part-list>',
  );
  for (final part in ['P1', 'P2']) {
    final staves = part == 'P1' ? 1 : 2;
    out.write('<part id="$part">');
    var divisions = 1;
    var time = (4, 4);
    // The clef change printed at the end of a bar, for the bar after it.
    final clefAfter = <int>{
      for (var i = 0; i < count - 1; i++)
        if (r.nextInt(7) == 0) i,
    };
    final clefAt = <int>{
      for (var i = 1; i < count; i++)
        if (r.nextInt(8) == 0) i,
    };
    var tiedFrom = <int, String>{};
    for (var i = 0; i < count; i++) {
      out.write('<measure number="${i + 1}">');
      if (i > 0 && i % 4 == 0) out.write('<print new-system="yes"/>');
      final attributes = StringBuffer();
      if (divisionsAt[i] case final d?) {
        divisions = d;
        attributes.write('<divisions>$d</divisions>');
      }
      if (keyAt[i] case final k?) {
        attributes.write('<key><fifths>$k</fifths></key>');
      }
      if (timeAt[i] case final t?) {
        time = t;
        attributes.write(
          '<time><beats>${t.$1}</beats><beat-type>${t.$2}</beat-type></time>',
        );
      }
      if (i == 0 && staves == 2) attributes.write('<staves>2</staves>');
      if (i == 0) {
        attributes.write(
          staves == 1
              ? '<clef><sign>G</sign><line>2</line></clef>'
              : '<clef number="1"><sign>G</sign><line>2</line></clef>'
                    '<clef number="2"><sign>F</sign><line>4</line></clef>',
        );
      } else if (clefAt.contains(i)) {
        attributes.write(
          staves == 1
              ? '<clef><sign>${r.nextBool() ? 'F' : 'G'}</sign>'
                    '<line>${r.nextBool() ? 4 : 2}</line></clef>'
              : '<clef number="${1 + r.nextInt(2)}"><sign>C</sign>'
                    '<line>3</line></clef>',
        );
      }
      if (attributes.isNotEmpty) {
        out.write('<attributes>$attributes</attributes>');
      }
      if (i == repeatFrom) {
        out.write(
          '<barline location="left"><repeat direction="forward"/></barline>',
        );
      }
      if (repeatTo != null && i == repeatTo) {
        out.write(
          '<barline location="left"><ending number="1" type="start"/></barline>',
        );
      }
      if (repeatTo != null && i == repeatTo + 1) {
        out.write(
          '<barline location="left"><ending number="2" type="start"/></barline>',
        );
      }
      // Eighths in the file's unit; a divisions of 1 writes quarters only.
      final quarters = time.$1 * 4 / time.$2;
      final total = (quarters * divisions).round();
      final tied = <int, String>{};
      for (var staff = 1; staff <= staves; staff++) {
        if (staff == 2) {
          out.write('<backup><duration>$total</duration></backup>');
        }
        var left = total;
        var first = true;
        while (left > 0) {
          final unit = divisions >= 2 && r.nextBool()
              ? divisions ~/ 2
              : divisions;
          final length = min(left, max(1, unit));
          final step = _steps[r.nextInt(7)];
          final octave = staff == 2 ? 3 : 4;
          final pitch = first && tiedFrom[staff] != null
              ? tiedFrom[staff]!
              : '$step$octave';
          final last = left - length <= 0;
          final start = last && i < count - 1 && r.nextInt(4) == 0;
          final stop = first && tiedFrom[staff] != null;
          out.write(
            '<note><pitch><step>${pitch[0]}</step>'
            '<octave>${pitch.substring(1)}</octave></pitch>'
            '<duration>$length</duration>'
            '${stop ? '<tie type="stop"/>' : ''}'
            '${start ? '<tie type="start"/>' : ''}'
            '<voice>${staff == 2 ? 5 : 1}</voice>'
            '${staves == 2 ? '<staff>$staff</staff>' : ''}'
            '${stop || start ? '<notations>${stop ? '<tied type="stop"/>' : ''}${start ? '<tied type="start"/>' : ''}</notations>' : ''}'
            '</note>',
          );
          if (start) tied[staff] = pitch;
          left -= length;
          first = false;
        }
      }
      tiedFrom = tied;
      if (clefAfter.contains(i)) {
        out.write(
          '<attributes><clef${staves == 2 ? ' number="2"' : ''}>'
          '<sign>${r.nextBool() ? 'G' : 'F'}</sign>'
          '<line>${r.nextBool() ? 2 : 4}</line></clef></attributes>',
        );
      }
      if (repeatTo != null && i == repeatTo) {
        out.write(
          '<barline location="right"><ending number="1" type="stop"/>'
          '<repeat direction="backward"/></barline>',
        );
      }
      if (repeatTo != null && i == repeatTo + 1) {
        out.write(
          '<barline location="right"><ending number="2" type="stop"/></barline>',
        );
      }
      out.write('</measure>');
    }
    out.write('</part>');
  }
  out.write('</score-partwise>');
  return out.toString();
}

/// Sections and an order as the structure panel makes them.
PlaybackSequence _form(Random r, MusicScore score) {
  var sequence = PlaybackSequence.empty;
  const names = ['INTRO', 'VERSE', 'CHORUS', 'BRIDGE', '', '간주'];
  for (var i = 0; i < 2 + r.nextInt(5); i++) {
    sequence = setSectionBoundary(
      score,
      sequence,
      measureIndex: r.nextInt(score.measureCount),
      name: names[r.nextInt(names.length)],
    );
  }
  final sections = scoreSections(score, sequence);
  if (sections.isEmpty || r.nextInt(6) == 0) return sequence;
  return sequence.copyWith(
    steps: [
      for (var i = 0; i < 1 + r.nextInt(6); i++)
        PlaybackStep(
          sectionId: sections[r.nextInt(sections.length)].id,
          repeats: 1 + r.nextInt(3),
        ),
    ],
  );
}

/// The song form is the heart of the app: sections are marked on a score
/// and played in a new order, and the score written out in that order is
/// what the band reads from. Whatever the order, every bar of the copy must
/// be the bar it was copied from: the same notes, read in the same clefs,
/// in the same key and time, however the key, time, clef and the file's
/// time unit changed between the places the bars came from. And the copy
/// must play: as many bars as the order says, as long as their time says.
void main() {
  test('bars are named by their printed numbers, as runs', () {
    expect(barRuns([0]), '1');
    expect(barRuns([0], firstBarNumber: 0), '0');
    expect(barRuns([4, 5, 6, 9]), '5–7, 10');
    expect(barRuns([4, 5, 6, 7, 8]), '5–9');
    // Played in another order, said in that order.
    expect(barRuns([8, 9, 0, 1, 2]), '9–10, 1–3');
    expect(barRuns([]), '');
  });

  final rounds =
      300 * (int.tryParse(Platform.environment['CHAOS_SCALE'] ?? '') ?? 1);

  test('a score written out in any order keeps every bar as it was', () {
    var jumps = 0;
    var custom = 0;
    for (var round = 0; round < rounds; round++) {
      final r = Random(4100 + round);
      final count = 3 + r.nextInt(12);
      final xml = _score(r, count);
      final score = _codec.decodeXml(xml);
      expect(score.measureCount, count, reason: 'round $round reads');
      final sequence = _form(r, score);
      if (sequence.steps.isNotEmpty) custom++;
      final List<int> map;
      try {
        map = performanceMeasureMap(score, sequence);
      } on FormatException {
        continue;
      }
      final where = 'round $round ($count bars) order $map';
      // What the panel says each step plays is what is played.
      if (sequence.steps.isNotEmpty) {
        expect(
          playbackStepBars(score, sequence).expand((bars) => bars),
          map,
          reason: '$where: the steps do not add up to the order',
        );
      }
      final String expanded;
      try {
        expanded = expandMusicXml(xml, map);
      } on Object catch (error, stack) {
        fail('$where: $error\n$stack');
      }
      final source = _read(xml);
      final copy = _read(expanded);
      expect(copy.length, source.length, reason: '$where: parts');
      for (var part = 0; part < source.length; part++) {
        expect(
          copy[part].length,
          map.length,
          reason: '$where: part $part bars',
        );
        for (var i = 0; i < map.length; i++) {
          if (i > 0 && map[i] != map[i - 1] + 1) jumps++;
          expect(
            copy[part][i].start,
            source[part][map[i]].start,
            reason:
                '$where: part $part, played bar $i (written ${map[i]}) '
                'begins in another key, time or clef',
          );
          expect(
            copy[part][i].notes,
            source[part][map[i]].notes,
            reason:
                '$where: part $part, played bar $i (written ${map[i]}) '
                'has other notes, lengths or clefs',
          );
        }
      }
      // The app reads its own copy, bar for bar.
      final read = _codec.decodeXml(expanded);
      expect(read.measureCount, map.length, reason: '$where: decoded bars');
      for (final part in read.parts) {
        expect(part.measures.length, map.length, reason: '$where: part length');
      }
    }
    // The orders really jumped about, and many were the user's own.
    expect(jumps, greaterThan(rounds));
    expect(custom, greaterThan(rounds ~/ 3));
  });

  test('a tie never reaches across a seam of the new order', () {
    for (var round = 0; round < rounds; round++) {
      final r = Random(9300 + round);
      final count = 3 + r.nextInt(12);
      final xml = _score(r, count);
      final score = _codec.decodeXml(xml);
      final sequence = _form(r, score);
      final List<int> map;
      try {
        map = performanceMeasureMap(score, sequence);
      } on FormatException {
        continue;
      }
      final expanded = _codec.decodeXml(expandMusicXml(xml, map));
      final where = 'round $round order $map';
      for (final part in expanded.parts) {
        for (var i = 0; i < part.measures.length; i++) {
          final seamBefore = i == 0 || map[i] != map[i - 1] + 1;
          final seamAfter =
              i == part.measures.length - 1 || map[i + 1] != map[i] + 1;
          final bar = part.measures[i];
          final notes = bar.notes.where((n) => !n.isRest).toList();
          for (final note in notes) {
            // A note held into the bar from a bar that is no longer before
            // it, or held out of it into a bar that no longer follows: the
            // tie has nothing on its other side and must be gone.
            if (seamBefore && note.onset == 0) {
              expect(
                note.tieStop,
                isFalse,
                reason:
                    '$where: played bar $i (written ${map[i]}) starts '
                    'with a note tied from a bar that is not before it',
              );
            }
            if (seamAfter && note.end == bar.durationDivisions) {
              expect(
                note.tieStart,
                isFalse,
                reason:
                    '$where: played bar $i (written ${map[i]}) ends with '
                    'a note tied into a bar that does not follow it',
              );
            }
          }
        }
      }
    }
  });

  test('the order plays: every bar, as long as its time', () {
    for (var round = 0; round < rounds ~/ 3; round++) {
      final r = Random(7700 + round);
      final count = 3 + r.nextInt(10);
      final xml = _score(r, count);
      final score = _codec.decodeXml(xml);
      final sequence = _form(r, score);
      final List<int> map;
      try {
        map = performanceMeasureMap(score, sequence);
      } on FormatException {
        continue;
      }
      final where = 'round $round order $map';
      final PlaybackMidi midi;
      try {
        midi = buildPlaybackMidi(
          engravingXml: xml,
          score: score,
          sequence: sequence,
          arrangement: ArrangementProfile.off,
          bpm: 120,
        );
      } on Object catch (error, stack) {
        fail('$where: $error\n$stack');
      }
      final lengths = measureQuarterLengths(score);
      final quarters = map.fold<double>(0, (sum, bar) => sum + lengths[bar]);
      // The last note ends where the last bar ends: at 120 a quarter is
      // half a second.
      expect(
        MidiTiming(midi.sequence).durationMs,
        closeTo(quarters * 500, 1),
        reason: '$where: the performance is not as long as its bars',
      );
      // Every note that is struck is let go.
      for (final track in midi.sequence.tracks) {
        final held = <int, int>{};
        for (final event
            in track.events.toList()
              ..sort((a, b) => a.tick.compareTo(b.tick))) {
          if (event.type == nm.MidiEventType.noteOn &&
              (event.velocity ?? 0) > 0) {
            held[event.note!] = (held[event.note!] ?? 0) + 1;
          } else if (event.type == nm.MidiEventType.noteOff ||
              event.type == nm.MidiEventType.noteOn) {
            held[event.note!] = (held[event.note!] ?? 0) - 1;
          }
        }
        expect(
          held.values.where((count) => count != 0),
          isEmpty,
          reason: '$where: a note is left sounding in ${track.name}',
        );
      }
    }
  });

  test('sections go with their bars when bars are added, removed or moved', () {
    var dropped = 0;
    var kept = 0;
    for (var round = 0; round < rounds * 4; round++) {
      final r = Random(1200 + round);
      final count = 2 + r.nextInt(14);
      final score = _codec.decodeXml(_plain(count));
      final sequence = _form(r, score);
      final sections = scoreSections(score, sequence);
      // What the proofreading editor does to the bars, by their ids.
      final before = [for (var i = 0; i < count; i++) i];
      final after = before.toList();
      var nextId = count;
      for (var edit = 0; edit < 1 + r.nextInt(6); edit++) {
        final at = r.nextInt(after.length);
        switch (r.nextInt(4)) {
          case 0:
            if (after.length > 1) after.removeAt(at);
          case 1:
            after.insert(at + 1, nextId++);
          case 2:
            after.insert(at + 1, nextId++); // a copy is a new bar
          default:
            final to = r.nextInt(after.length);
            after.insert(to, after.removeAt(at));
        }
      }
      final where =
          'round $round: $before -> $after, '
          'marks ${sequence.marks.map((m) => m.startMeasureIndex).toList()}, '
          'steps ${sequence.steps.map((s) => s.sectionId).toList()}';
      final PlaybackSequence next;
      try {
        next = remapSectionMarks(sequence, before, after);
      } on Object catch (error, stack) {
        fail('$where: $error $stack');
      }
      final edited = _codec.decodeXml(_plain(after.length));
      final starts = next.marks.map((m) => m.startMeasureIndex).toList();
      expect(starts, orderedEquals([...starts]..sort()), reason: where);
      expect(starts.toSet().length, starts.length, reason: where);
      for (final start in starts) {
        expect(start, inInclusiveRange(0, after.length - 1), reason: where);
      }
      final now = scoreSections(edited, next);
      // Every step still plays a section that is there, and the order that
      // comes out can be laid out.
      for (final step in next.steps) {
        expect(
          now.any((section) => section.id == step.sectionId),
          isTrue,
          reason: '$where: a step plays a section that is gone',
        );
      }
      final map = performanceMeasureMap(edited, next);
      expect(map, isNotEmpty, reason: where);
      for (final bar in map) {
        expect(bar, inInclusiveRange(0, after.length - 1), reason: where);
      }
      // A section starts at a bar that was its own; one whose bars are all
      // gone takes its steps with it.
      for (final section in sections) {
        final own = {
          for (
            var bar = section.startMeasureIndex;
            bar <= section.endMeasureIndex;
            bar++
          )
            before[bar],
        };
        final survives = after.any(own.contains);
        final steps = sequence.steps
            .where((step) => step.sectionId == section.id)
            .length;
        if (steps == 0) continue;
        if (!survives && section.startMeasureIndex > 0) {
          dropped++;
          continue;
        }
        if (!survives) continue;
        kept++;
        final first = after.indexWhere(own.contains);
        if (section.startMeasureIndex == 0 && section.name.isEmpty) continue;
        expect(
          next.steps.where((step) => step.sectionId == sectionIdAt(first)),
          isNotEmpty,
          reason:
              '$where: the steps of ${section.id} did not follow it '
              'to bar $first',
        );
      }
      expect(
        next.steps.length,
        lessThanOrEqualTo(sequence.steps.length),
        reason: where,
      );
    }
    expect(kept, greaterThan(rounds));
    expect(dropped, greaterThan(rounds ~/ 20));
  });
}

/// [count] plain bars of one part.
String _plain(int count) {
  final out = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8"?><score-partwise version="4.0">'
    '<part-list><score-part id="P1"><part-name>Voice</part-name></score-part>'
    '</part-list><part id="P1">',
  );
  for (var i = 0; i < count; i++) {
    out.write('<measure number="${i + 1}">');
    if (i == 0) {
      out.write(
        '<attributes><divisions>1</divisions><key><fifths>0</fifths></key>'
        '<time><beats>4</beats><beat-type>4</beat-type></time>'
        '<clef><sign>G</sign><line>2</line></clef></attributes>',
      );
    }
    out.write(
      '<note><pitch><step>C</step><octave>4</octave></pitch>'
      '<duration>4</duration><voice>1</voice><type>whole</type></note>'
      '</measure>',
    );
  }
  out.write('</part></score-partwise>');
  return out.toString();
}
