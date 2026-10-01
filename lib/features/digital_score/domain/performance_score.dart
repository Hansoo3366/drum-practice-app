import 'dart:math' as math;

import 'package:page_a_diddle/features/digital_score/domain/arrangement_profile.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/digital_score/domain/xml_measure_editor.dart';
import 'package:xml/xml.dart';

/// 쓰기 중이거나 재생이 꺼져 있으면 원본 악보만 보여 준다.
MusicScore displayedDigitalScore({
  required MusicScore written,
  required bool editing,
  required bool playbackEnabled,
  PlaybackSequence sequence = PlaybackSequence.empty,
  ArrangementProfile arrangement = ArrangementProfile.off,
}) {
  // Section/arrangement editing must always use the written score.  The
  // performance score is a derived view used only after the user explicitly
  // turns playback on; this keeps the source notation stable while setting up
  // Verse/Chorus order and prevents a failed expansion from replacing it.
  if (editing || !playbackEnabled) return written;
  return composePerformanceScore(
    written,
    sequence: sequence,
    arrangement: arrangement,
    ignoreErrors: true,
  );
}

MusicScore composePerformanceScore(
  MusicScore written, {
  PlaybackSequence sequence = PlaybackSequence.empty,
  ArrangementProfile arrangement = ArrangementProfile.off,
  bool ignoreErrors = false,
  bool flattenRepeats = false,
}) {
  var score = written;
  if (sequence.isNotEmpty || flattenRepeats) {
    try {
      score = expandPlaybackSequence(score, sequence, flattenRepeats);
    } on Object {
      if (!ignoreErrors) rethrow;
    }
  }
  if (arrangement.isNotOff) {
    try {
      score = applyArrangement(score, arrangement);
    } on Object {
      if (!ignoreErrors) rethrow;
    }
  }
  return score;
}

/// The written file laid out in playing order for the MIDI player, so
/// tuplets, ties and every voice play as written; null when the file already
/// plays in order (no repeats, jumps or custom order) and can be used as is.
/// Throws a [FormatException] for an order that cannot be laid out.
String? playbackMusicXml(
  String xml,
  MusicScore written,
  PlaybackSequence sequence,
) {
  final map = performanceMeasureMap(written, sequence);
  var straight = map.length == written.measureCount;
  for (var i = 0; straight && i < map.length; i++) {
    straight = map[i] == i;
  }
  return straight ? null : expandMusicXml(xml, map);
}

/// A note that continues a tie: where it starts, in quarter notes from the
/// start of the piece, on which staff of the score (counted across parts).
typedef TiedContinuation = ({double quarters, int midi, int staffIndex});

/// The notes of [score] that are tied from the note before them and so must
/// not sound again, whatever voice either note is written in. [score] is the
/// score as it plays, bar after bar (see [playbackMusicXml]); a bar is as
/// long as its time signature, or its notes when they run over, the lengths
/// [midiReadyMusicXml] writes.
List<TiedContinuation> tiedContinuations(MusicScore score) {
  final lengths = <double>[];
  for (var index = 0; index < score.measureCount; index++) {
    var quarters = 0.0;
    for (final part in score.parts) {
      if (index >= part.measures.length) continue;
      final bar = part.measures[index];
      final time =
          bar.attributes.time ??
          const MusicTimeSignature(beats: 4, beatType: 4);
      quarters = math.max(quarters, time.beats * 4 / time.beatType);
      quarters = math.max(
        quarters,
        bar.durationDivisions / bar.attributes.divisions,
      );
    }
    lengths.add(quarters);
  }
  final result = <TiedContinuation>[];
  var firstStaff = 0;
  for (final part in score.parts) {
    // Ends of the notes that start a tie, by staff and pitch.
    final held = <(int, int), List<double>>{};
    var start = 0.0;
    var staves = 1;
    for (var index = 0; index < part.measures.length; index++) {
      final bar = part.measures[index];
      staves = math.max(staves, bar.attributes.staves);
      final notes = bar.notes.where((n) => !n.isRest && !n.isGrace).toList()
        ..sort((a, b) => a.onset.compareTo(b.onset));
      for (final note in notes) {
        final key = (note.staff, note.pitch!.midi);
        final at = start + note.onset / bar.attributes.divisions;
        final ends = held[key];
        if (note.tieStop && ends != null) {
          final match = ends.indexWhere((end) => (end - at).abs() < 1e-6);
          if (match >= 0) {
            ends.removeAt(match);
            result.add((
              quarters: at,
              midi: note.pitch!.midi,
              staffIndex: firstStaff + note.staff - 1,
            ));
          }
        }
        if (note.tieStart) {
          held
              .putIfAbsent(key, () => [])
              .add(start + note.end / bar.attributes.divisions);
        }
      }
      start += lengths[index];
    }
    firstStaff += staves;
  }
  return result;
}

/// A copy of [xml] the MIDI player reads every note of, in time. Nothing
/// that is shown or saved uses it.
///
/// * Voices are numbered from 1 per staff in each bar. The player's MusicXML
///   reader drops every note of a bar whose staff has a single voice not
///   numbered 1, which is how a piano left hand is written (voice 5 on
///   staff 2). The numbers carry no meaning of their own.
/// * A bar holding more than its time signature (a converted score that
///   missed a change of time) gets a time signature as long as its notes, in
///   every part, so it plays to its end instead of running into the next
///   bar. The written time comes back with the next bar that fits it.
/// * A voice that enters after the start of the bar (after a `<forward>`, or
///   a `<backup>` that lands mid-bar) gets rests up to its first note: the
///   player gives skipped time no length, so the voice would sound at the
///   barline.
/// * A tuplet note as long as a plain or dotted value (a duplet in 9/8 is a
///   dotted eighth) is written as that value: the player loses its place in
///   duplets that begin with a rest. Triplets stay tuplets.
///
/// Ties stay as written; see [withoutTies] and [tiedContinuations] for how
/// they are played.
String midiReadyMusicXml(String xml) => midiReadyCopies(xml).ready;

/// [midiReadyMusicXml] and the same copy [withoutTies], from one reading of
/// [xml].
({String ready, String untied}) midiReadyCopies(String xml) {
  final document = XmlDocument.parse(xml);
  final ready = _midiReady(document) ? document.toXmlString() : xml;
  return (
    ready: ready,
    untied: _removeTies(document) ? document.toXmlString() : ready,
  );
}

bool _midiReady(XmlDocument document) {
  var changed = false;
  final parts = document.rootElement.findElements('part').toList();
  final measures = [
    for (final part in parts) part.findElements('measure').toList(),
  ];
  for (final bars in measures) {
    var barDivisions = 1;
    for (final measure in bars) {
      for (final attributes in measure.findElements('attributes')) {
        barDivisions =
            int.tryParse(
              attributes.getElement('divisions')?.innerText.trim() ?? '',
            ) ??
            barDivisions;
      }
      if (_plainTuplets(measure, barDivisions)) changed = true;
      if (_padVoices(measure, barDivisions)) changed = true;
      final numbers = <String, Map<String, int>>{};
      for (final note in measure.findElements('note')) {
        final voice = note.getElement('voice');
        if (voice == null) continue;
        final staff = note.getElement('staff')?.innerText.trim() ?? '1';
        final seen = numbers.putIfAbsent(staff, () => {});
        final number = seen.putIfAbsent(
          voice.innerText.trim(),
          () => seen.length + 1,
        );
        if (voice.innerText.trim() != '$number') {
          voice.innerText = '$number';
          changed = true;
        }
      }
    }
  }
  if (measures.isEmpty) return changed;

  int? number(XmlElement? element) =>
      int.tryParse(element?.innerText.trim() ?? '');
  final count = measures.map((bars) => bars.length).reduce(math.max);
  final divisions = List.filled(parts.length, 1);
  // The time signature the score declares, and the one this copy last wrote.
  var declared = (4, 4);
  final written = List.filled(parts.length, (4, 4));
  for (var index = 0; index < count; index++) {
    var quarters = 0.0;
    for (var p = 0; p < parts.length; p++) {
      if (index >= measures[p].length) continue;
      var cursor = 0, furthest = 0;
      for (final child in measures[p][index].childElements) {
        switch (child.name.local) {
          case 'attributes':
            divisions[p] =
                number(child.getElement('divisions')) ?? divisions[p];
            final time = child.getElement('time');
            final beats = number(time?.getElement('beats'));
            final beatType = number(time?.getElement('beat-type'));
            if (beats != null &&
                beatType != null &&
                beats > 0 &&
                beatType > 0) {
              if (p == 0) declared = (beats, beatType);
              written[p] = (beats, beatType);
            }
          case 'note':
            if (child.getElement('chord') == null &&
                child.getElement('grace') == null) {
              cursor += number(child.getElement('duration')) ?? 0;
            }
          case 'backup':
            cursor -= number(child.getElement('duration')) ?? 0;
          case 'forward':
            cursor += number(child.getElement('duration')) ?? 0;
        }
        furthest = math.max(furthest, cursor);
      }
      quarters = math.max(quarters, furthest / math.max(1, divisions[p]));
    }
    final capacity = declared.$1 * 4 / declared.$2;
    var wanted = declared;
    if (quarters > capacity + 1e-6) {
      wanted = (0, 0);
      for (final beatType in const [4, 8, 16, 32, 64]) {
        final beats = quarters * beatType / 4;
        if ((beats - beats.round()).abs() < 1e-6) {
          wanted = (beats.round(), beatType);
          break;
        }
      }
      if (wanted.$1 == 0) wanted = ((quarters * 16).ceil(), 64);
    }
    for (var p = 0; p < parts.length; p++) {
      if (index >= measures[p].length || written[p] == wanted) continue;
      final measure = measures[p][index];
      XmlElement leaf(String name, int value) =>
          XmlElement(XmlName(name), [], [XmlText('$value')]);
      final time = XmlElement(XmlName('time'), [], [
        leaf('beats', wanted.$1),
        leaf('beat-type', wanted.$2),
      ]);
      final existing = measure
          .findElements('attributes')
          .expand((a) => a.findElements('time'))
          .toList();
      if (existing.isNotEmpty) {
        existing.first.replace(time);
        existing.skip(1).toList().forEach((e) => e.remove());
      } else {
        measure.children.insert(
          0,
          XmlElement(XmlName('attributes'), [], [time]),
        );
      }
      written[p] = wanted;
      changed = true;
    }
  }
  return changed;
}

/// Writes tuplet notes whose length is a plain or dotted value as that
/// value, without the tuplet.
bool _plainTuplets(XmlElement measure, int divisions) {
  const types = ['whole', 'half', 'quarter', 'eighth', '16th', '32nd', '64th'];
  var changed = false;
  for (final note in measure.findElements('note')) {
    final modification = note.getElement('time-modification');
    if (modification == null || note.getElement('grace') != null) continue;
    final length = int.tryParse(
      note.getElement('duration')?.innerText.trim() ?? '',
    );
    if (length == null || length <= 0) continue;
    String? type;
    var dots = 0;
    search:
    for (var i = 0; i < types.length; i++) {
      for (var d = 0; d <= 2; d++) {
        // A whole note is four quarters; a dot adds half of what is there.
        final value = divisions * 4 / (1 << i) * (2 - 1 / (1 << d));
        if ((value - length).abs() < 1e-9) {
          type = types[i];
          dots = d;
          break search;
        }
      }
    }
    if (type == null) continue;
    XmlElement leaf(String name, [String? value]) =>
        XmlElement(XmlName(name), [], [if (value != null) XmlText(value)]);
    final at = note.children.indexOf(modification);
    note.findElements('type').toList().forEach((e) => e.remove());
    note.findElements('dot').toList().forEach((e) => e.remove());
    modification.replace(leaf('type', type));
    for (var d = 0; d < dots; d++) {
      note.children.insert(math.min(at + 1, note.children.length), leaf('dot'));
    }
    for (final notations in note.findElements('notations').toList()) {
      notations.findElements('tuplet').toList().forEach((e) => e.remove());
      if (notations.childElements.isEmpty) notations.remove();
    }
    changed = true;
  }
  return changed;
}

/// Fills every voice of [measure] with rests from the barline, or from its
/// last note, to each note that starts later. The rests are written where
/// the note is, behind a `<backup>` of their own length, so the bar keeps
/// its length.
bool _padVoices(XmlElement measure, int divisions) {
  int length(XmlElement element) =>
      int.tryParse(element.getElement('duration')?.innerText.trim() ?? '') ?? 0;
  XmlElement leaf(String name, String value) =>
      XmlElement(XmlName(name), [], [XmlText(value)]);
  var changed = false;
  // Without <voice>, each <backup> starts the next voice; say so, since the
  // backups added below must not count as one.
  if (measure
      .findElements('note')
      .every((n) => n.getElement('voice') == null)) {
    var voice = 1;
    for (final child in measure.childElements) {
      if (child.name.local == 'backup') voice++;
      if (child.name.local != 'note') continue;
      final after = child.getElement('duration') ?? child.childElements.last;
      child.children.insert(
        child.children.indexOf(after) + 1,
        leaf('voice', '$voice'),
      );
      changed = voice > 1 || changed;
    }
  }
  // A voice that moves between the staves is read once per staff, each time
  // without its notes on the other staff. For playing it only matters when
  // the notes sound, so each voice stays on the staff it starts on.
  final home = <String, String>{};
  for (final note in measure.findElements('note')) {
    final voice = note.getElement('voice')?.innerText.trim();
    final staff = note.getElement('staff');
    if (voice == null || staff == null) continue;
    final first = home.putIfAbsent(voice, () => staff.innerText.trim());
    if (staff.innerText.trim() != first) {
      staff.innerText = first;
      changed = true;
    }
  }
  final filled = <String, int>{};
  var cursor = 0;
  for (final child in measure.childElements.toList()) {
    switch (child.name.local) {
      case 'note':
        if (child.getElement('chord') != null ||
            child.getElement('grace') != null) {
          continue;
        }
        final voice = child.getElement('voice')?.innerText.trim() ?? '1';
        final staff = child.getElement('staff')?.innerText.trim() ?? '1';
        final key = '$staff|$voice';
        final gap = cursor - (filled[key] ?? 0);
        if (gap > 0) {
          final siblings = measure.children;
          siblings.insertAll(siblings.indexOf(child), [
            XmlElement(XmlName('backup'), [], [leaf('duration', '$gap')]),
            ..._rests(gap, divisions, like: child),
          ]);
          changed = true;
        }
        filled[key] = cursor + length(child);
        cursor += length(child);
      case 'backup':
        cursor = math.max(0, cursor - length(child));
      case 'forward':
        cursor += length(child);
    }
  }
  return changed;
}

/// [xml] with every tie taken off, so the MIDI player strikes each note.
///
/// The player joins ties only within one voice, ties a chord as a whole (the
/// notes of the chord without a tie then make no sound) and reads one `<tie>`
/// per note. Tied notes are joined afterwards from [tiedContinuations],
/// which knows none of these limits.
String withoutTies(String xml) {
  final document = XmlDocument.parse(xml);
  return _removeTies(document) ? document.toXmlString() : xml;
}

bool _removeTies(XmlDocument document) {
  final ties = [
    ...document.findAllElements('tie'),
    ...document.findAllElements('tied'),
  ];
  if (ties.isEmpty) return false;
  for (final tie in ties) {
    final parent = tie.parentElement;
    tie.remove();
    if (parent != null &&
        parent.name.local == 'notations' &&
        parent.childElements.isEmpty) {
      parent.remove();
    }
  }
  return true;
}

/// Typed rests [length] divisions long in the voice and staff of [like].
List<XmlElement> _rests(int length, int divisions, {required XmlElement like}) {
  XmlElement leaf(String name, String value) =>
      XmlElement(XmlName(name), [], [XmlText(value)]);
  XmlElement rest(int duration, String? type) =>
      XmlElement(XmlName('note'), [], [
        XmlElement(XmlName('rest')),
        leaf('duration', '$duration'),
        if (like.getElement('voice') case final voice?)
          leaf('voice', voice.innerText),
        if (type != null) leaf('type', type),
        if (like.getElement('staff') case final staff?)
          leaf('staff', staff.innerText),
      ]);
  const types = ['whole', 'half', 'quarter', 'eighth', '16th', '32nd', '64th'];
  final rests = <XmlElement>[];
  var left = length;
  for (var i = 0; i < types.length && left > 0; i++) {
    // A whole note is four quarters; each next type is half as long.
    final value = divisions * 4 / (1 << i);
    if (value != value.roundToDouble() || value < 1) break;
    while (left >= value) {
      rests.add(rest(value.round(), types[i]));
      left -= value.round();
    }
  }
  if (left > 0) {
    // What plain values cannot spell (a third of a beat) is a tuplet rest:
    // the next plain value up, shortened to the gap.
    var plain = divisions * 4.0;
    var type = types.first;
    for (var i = 1; i < types.length; i++) {
      final value = divisions * 4 / (1 << i);
      if (value < left) break;
      plain = value;
      type = types[i];
    }
    final scaled = (plain * 64).round();
    final gcd = scaled.gcd(left * 64);
    final tuplet = rest(left, type)
      ..children.add(
        XmlElement(XmlName('time-modification'), [], [
          leaf('actual-notes', '${scaled ~/ gcd}'),
          leaf('normal-notes', '${left * 64 ~/ gcd}'),
        ]),
      );
    rests.add(tuplet);
  }
  return rests;
}
