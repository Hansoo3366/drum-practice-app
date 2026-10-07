import 'dart:convert';
import 'dart:math' as math;

import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';

const standardPlaybackSections = <String>[
  'INTRO',
  'VERSE',
  'PRE',
  'CHORUS',
  'BRIDGE',
  'SOLO',
  'INTERLUDE',
  'OUTRO',
];

const int minPlaybackRepeats = 1;
const int maxPlaybackRepeats = 16;
const int maxExpandedMeasures = 4096;
const int maxSectionNameLength = 24;

/// A section boundary: the section named [name] starts at bar
/// [startMeasureIndex] and runs until the next boundary.
///
/// The id is derived from the start bar so a renamed boundary keeps the
/// playback steps that refer to it.
class SectionMark {
  SectionMark({
    required this.startMeasureIndex,
    required String name,
    this.continued = false,
  }) : name = normalizePlaybackSection(name) {
    if (startMeasureIndex < 0) {
      throw const FormatException('A section boundary is invalid.');
    }
    if (this.name.length > maxSectionNameLength) {
      throw const FormatException('A section name is too long.');
    }
  }

  factory SectionMark.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('A section boundary is invalid.');
    }
    final start = json['start'];
    final name = json['name'];
    if (start is! int || (name != null && name is! String)) {
      throw const FormatException('A section boundary is invalid.');
    }
    return SectionMark(
      startMeasureIndex: start,
      name: (name as String?) ?? '',
      continued: json['continued'] == true,
    );
  }

  final int startMeasureIndex;

  /// Normalized section name. Empty for an unnamed stretch of bars.
  final String name;

  /// True for a boundary that only splits the section before it where the
  /// written order jumps in or out (see [writtenOrderSequence]): it keeps
  /// that section's name, number and box.
  final bool continued;

  String get id => sectionIdAt(startMeasureIndex);

  Map<String, Object> toJson() => {
    'start': startMeasureIndex,
    'name': name,
    if (continued) 'continued': true,
  };

  @override
  bool operator ==(Object other) =>
      other is SectionMark &&
      other.startMeasureIndex == startMeasureIndex &&
      other.name == name &&
      other.continued == continued;

  @override
  int get hashCode => Object.hash(startMeasureIndex, name, continued);
}

String sectionIdAt(int startMeasureIndex) => 'm$startMeasureIndex';

/// Steps from files written before section ids referred to a section name
/// and meant every section with that name.
const _legacyNamePrefix = '@';

/// One entry of the playback order: play section [sectionId] [repeats] times.
class PlaybackStep {
  PlaybackStep({required this.sectionId, this.repeats = 1, this.pass}) {
    if (sectionId.isEmpty) {
      throw const FormatException('A playback section is required.');
    }
    if (repeats < minPlaybackRepeats || repeats > maxPlaybackRepeats) {
      throw const FormatException('Repeat count must be between 1 and 16.');
    }
  }

  factory PlaybackStep.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Playback Sequence item is invalid.');
    }
    final section = json['section'];
    final repeats = json['repeats'];
    final pass = json['pass'];
    return PlaybackStep(
      sectionId: section is String ? section : '',
      pass: pass is int && pass >= 0 ? pass : null,
      repeats: switch (repeats) {
        final int value => value,
        final num value => value.round(),
        final String value => int.tryParse(value) ?? 0,
        _ => 1,
      },
    );
  }

  final String sectionId;

  /// Total number of times the section plays at this point of the order.
  final int repeats;

  /// Which pass of a written repeat this is, so a section played once takes
  /// that pass's ending bracket (the 1st ending before going back). Null
  /// takes the last ending; 0 plays every bar, brackets outside a repeat
  /// included. Only used while [repeats] is 1.
  final int? pass;

  /// A changed repeat count drops [pass]: the passes then count themselves.
  PlaybackStep copyWith({String? sectionId, int? repeats}) => PlaybackStep(
    sectionId: sectionId ?? this.sectionId,
    repeats: repeats ?? this.repeats,
    pass: repeats == null || repeats == this.repeats ? pass : null,
  );

  Map<String, Object> toJson() => {
    'section': sectionId,
    'repeats': repeats,
    if (pass != null) 'pass': pass!,
  };

  @override
  bool operator ==(Object other) =>
      other is PlaybackStep &&
      other.sectionId == sectionId &&
      other.repeats == repeats &&
      other.pass == pass;

  @override
  int get hashCode => Object.hash(sectionId, repeats, pass);
}

/// Section boundaries and the playback order that refers to them.
///
/// Stored per score version in a sidecar file, never in the MusicXML. An
/// empty [steps] list means "play as written". Scores marked by older app
/// versions carry rehearsal marks instead of [marks]; [scoreSections] reads
/// those while [marks] is empty.
class PlaybackSequence {
  PlaybackSequence({
    List<SectionMark> marks = const [],
    List<PlaybackStep> steps = const [],
  }) : marks = List.unmodifiable(_sortedMarks(marks)),
       steps = List.unmodifiable(steps);

  const PlaybackSequence._(this.marks, this.steps);

  /// Reads the current format and converts the two earlier ones: name-based
  /// items with rehearsal marks in the score, and start–end `sections`.
  factory PlaybackSequence.fromJson(Object? json) {
    if (json == null) return PlaybackSequence.empty;
    if (json is! Map) {
      throw const FormatException('Playback Sequence JSON is invalid.');
    }
    if (json['version'] == 2) {
      final rawMarks = json['marks'] ?? const <Object?>[];
      final rawSteps = json['steps'] ?? const <Object?>[];
      if (rawMarks is! List || rawSteps is! List) {
        throw const FormatException('Playback Sequence JSON is invalid.');
      }
      return PlaybackSequence(
        marks: [for (final mark in rawMarks) SectionMark.fromJson(mark)],
        steps: [for (final step in rawSteps) PlaybackStep.fromJson(step)],
      );
    }
    return _fromLegacyJson(json);
  }

  static const empty = PlaybackSequence._([], []);

  final List<SectionMark> marks;
  final List<PlaybackStep> steps;

  /// True when bars play as written.
  bool get isEmpty => steps.isEmpty;
  bool get isNotEmpty => steps.isNotEmpty;

  bool get isIdentity => isEmpty;

  PlaybackSequence copyWith({
    List<SectionMark>? marks,
    List<PlaybackStep>? steps,
  }) {
    return PlaybackSequence(
      marks: marks ?? this.marks,
      steps: steps ?? this.steps,
    );
  }

  Map<String, Object> toJson() => {
    'version': 2,
    'marks': [for (final mark in marks) mark.toJson()],
    'steps': [for (final step in steps) step.toJson()],
  };

  @override
  bool operator ==(Object other) {
    return other is PlaybackSequence &&
        _sameList(other.marks, marks) &&
        _sameList(other.steps, steps);
  }

  static bool _sameList<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(marks), Object.hashAll(steps));
}

List<SectionMark> _sortedMarks(List<SectionMark> marks) {
  final byStart = <int, SectionMark>{
    for (final mark in marks) mark.startMeasureIndex: mark,
  };
  return byStart.values.toList()
    ..sort((a, b) => a.startMeasureIndex.compareTo(b.startMeasureIndex));
}

PlaybackSequence _fromLegacyJson(Map<Object?, Object?> json) {
  final rawItems = json['items'] ?? const <Object?>[];
  final rawSections = json['sections'] ?? const <Object?>[];
  if (rawItems is! List || rawSections is! List) {
    throw const FormatException('Playback Sequence items are invalid.');
  }
  final marks = <SectionMark>[];
  var nextStart = 0;
  final ranges = <({String name, int start, int end})>[];
  for (final raw in rawSections) {
    if (raw is! Map ||
        raw['section'] is! String ||
        raw['start'] is! int ||
        raw['end'] is! int) {
      throw const FormatException('A playback section range is invalid.');
    }
    ranges.add((
      name: raw['section'] as String,
      start: raw['start'] as int,
      end: raw['end'] as int,
    ));
  }
  ranges.sort((a, b) => a.start.compareTo(b.start));
  for (final range in ranges) {
    // Bars between two old ranges were not played in any section; keep them
    // as an unnamed section so the order still skips them.
    if (range.start > nextStart && marks.isNotEmpty) {
      marks.add(SectionMark(startMeasureIndex: nextStart, name: ''));
    }
    marks.add(SectionMark(startMeasureIndex: range.start, name: range.name));
    nextStart = range.end + 1;
  }
  if (ranges.isNotEmpty) {
    marks.add(SectionMark(startMeasureIndex: nextStart, name: ''));
  }
  final steps = <PlaybackStep>[];
  for (final raw in rawItems) {
    if (raw is! Map) {
      throw const FormatException('Playback Sequence item is invalid.');
    }
    final name = normalizePlaybackSection(
      raw['section'] is String ? raw['section'] as String : '',
    );
    if (name.isEmpty) {
      throw const FormatException('A playback section is required.');
    }
    final repeats = PlaybackStep.fromJson(raw).repeats;
    steps.add(
      PlaybackStep(sectionId: '$_legacyNamePrefix$name', repeats: repeats),
    );
  }
  return PlaybackSequence(marks: marks, steps: steps);
}

/// A resolved section: bars [startMeasureIndex]..[endMeasureIndex].
class ScoreSection {
  const ScoreSection({
    required this.id,
    required this.name,
    required this.number,
    required this.startMeasureIndex,
    required this.endMeasureIndex,
    this.continued = false,
  });

  final String id;

  /// Normalized name, empty for unnamed bars.
  final String name;

  /// 1-based occurrence number when the same name appears more than once
  /// (Verse 1, Verse 2), else null.
  final int? number;
  final int startMeasureIndex;
  final int endMeasureIndex;

  /// A piece continuing the section before it (see [SectionMark.continued]).
  final bool continued;

  int get measureCount => endMeasureIndex - startMeasureIndex + 1;

  bool contains(int measureIndex) =>
      measureIndex >= startMeasureIndex && measureIndex <= endMeasureIndex;

  @override
  bool operator ==(Object other) =>
      other is ScoreSection &&
      other.id == id &&
      other.name == name &&
      other.number == number &&
      other.startMeasureIndex == startMeasureIndex &&
      other.endMeasureIndex == endMeasureIndex &&
      other.continued == continued;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    number,
    startMeasureIndex,
    endMeasureIndex,
    continued,
  );
}

/// Sections of the score from the sidecar boundaries, or from rehearsal
/// marks written by older app versions. Returns an empty list when the score
/// has no boundaries at all.
List<ScoreSection> scoreSections(MusicScore score, PlaybackSequence sequence) {
  final count = score.measureCount;
  if (count == 0) return const [];
  var marks = sequence.marks.isNotEmpty
      ? sequence.marks
      : rehearsalSectionMarks(score);
  marks = [
    for (final mark in marks)
      if (mark.startMeasureIndex < count) mark,
  ];
  if (marks.isEmpty) return const [];
  if (marks.first.startMeasureIndex > 0) {
    marks = [SectionMark(startMeasureIndex: 0, name: ''), ...marks];
  }
  // A section split into pieces with the same name (see
  // [writtenOrderSequence]) counts as one occurrence.
  bool continues(int index) =>
      index > 0 &&
      marks[index].continued &&
      marks[index].name == marks[index - 1].name;
  final totals = <String, int>{};
  for (var index = 0; index < marks.length; index++) {
    final name = marks[index].name;
    if (name.isNotEmpty && !continues(index)) {
      totals[name] = (totals[name] ?? 0) + 1;
    }
  }
  final seen = <String, int>{};
  final numbers = <int?>[];
  for (var index = 0; index < marks.length; index++) {
    final name = marks[index].name;
    if ((totals[name] ?? 0) < 2) {
      numbers.add(null);
    } else if (continues(index)) {
      numbers.add(seen[name]);
    } else {
      numbers.add(seen[name] = (seen[name] ?? 0) + 1);
    }
  }
  return [
    for (var index = 0; index < marks.length; index++)
      ScoreSection(
        id: marks[index].id,
        name: marks[index].name,
        number: numbers[index],
        continued: continues(index),
        startMeasureIndex: marks[index].startMeasureIndex,
        endMeasureIndex: index + 1 < marks.length
            ? marks[index + 1].startMeasureIndex - 1
            : count - 1,
      ),
  ];
}

/// Boundaries from rehearsal marks in the score (older app versions).
///
/// A mark the conversion plainly misread keeps its place and loses its name:
/// the boxed letter was there on the page, but "프" for a boxed "B" is not a
/// name to show.
List<SectionMark> rehearsalSectionMarks(MusicScore score) {
  if (score.parts.isEmpty) return const [];
  final measures = score.parts.first.measures;
  return [
    for (var index = 0; index < measures.length; index++)
      if (measurePlaybackSection(measures[index]) case final name?)
        SectionMark(
          startMeasureIndex: index,
          name: isMisreadSectionName(name) ? '' : name,
        ),
  ];
}

/// Whether the printed section boxes of [score] must give way to the app's
/// own labels: the user set sections, or a printed mark was misread and must
/// not be shown as it stands.
bool usesOwnSectionLabels(MusicScore score, PlaybackSequence sequence) {
  if (sequence.marks.isNotEmpty) return true;
  if (score.parts.isEmpty) return false;
  return score.parts.first.measures.any((measure) {
    final name = measurePlaybackSection(measure);
    return name != null && isMisreadSectionName(name);
  });
}

/// Whether [name] is what character recognition makes of a boxed letter
/// rather than a section's name: one Korean syllable on its own. Korean
/// section words have two or more ("간주", "후렴"); letters and English words
/// are names.
bool isMisreadSectionName(String name) {
  final text = name.trim();
  if (text.runes.length != 1) return false;
  final rune = text.runes.single;
  return rune >= 0xAC00 && rune <= 0xD7A3;
}

/// Starts a section named [name] at bar [measureIndex], or renames the
/// section that already starts there. Old rehearsal-mark boundaries are
/// carried into the sidecar on the first edit.
PlaybackSequence setSectionBoundary(
  MusicScore score,
  PlaybackSequence sequence, {
  required int measureIndex,
  required String name,
}) {
  if (measureIndex < 0 || measureIndex >= score.measureCount) {
    throw RangeError.index(measureIndex, score.parts);
  }
  final marks = [
    for (final mark in _editableMarks(score, sequence))
      if (mark.startMeasureIndex != measureIndex) mark,
    SectionMark(startMeasureIndex: measureIndex, name: name),
  ];
  return _withoutLostSteps(score, sequence.copyWith(marks: marks));
}

/// [sequence] without steps that play a section it no longer has: an edit
/// can take a section away (the last boundary merged, a range drawn over
/// one), and a step left pointing at it would play nothing and show nowhere.
PlaybackSequence _withoutLostSteps(
  MusicScore score,
  PlaybackSequence sequence,
) {
  final ids = {
    for (final section in scoreSections(score, sequence)) section.id,
  };
  final steps = [
    for (final step in sequence.steps)
      if (step.sectionId.startsWith(_legacyNamePrefix) ||
          ids.contains(step.sectionId))
        step,
  ];
  return steps.length == sequence.steps.length
      ? sequence
      : sequence.copyWith(steps: steps);
}

/// What naming a pick does, as the structure panel decides it: a pick that
/// began on the bar a section starts at and was not drawn out ([extended])
/// renames that section; otherwise the picked bars [start]..[end] (or the
/// one bar [start]) become a section named [name]. An empty [name] leaves
/// the bars a section without a name.
PlaybackSequence nameSectionPick(
  MusicScore score,
  PlaybackSequence sequence, {
  required int start,
  int? end,
  required bool extended,
  required String name,
}) {
  // Only a section with a name is picked whole: the nameless stretch before
  // the first mark, or after a misread one, is just bars to divide.
  final startsSection =
      !extended &&
      scoreSections(
        score,
        sequence,
      ).any((s) => s.startMeasureIndex == start && s.name.isNotEmpty);
  final last = end?.clamp(start, score.measureCount - 1);
  if (startsSection || last == null) {
    return setSectionBoundary(score, sequence, measureIndex: start, name: name);
  }
  return setSectionRange(score, sequence, start: start, end: last, name: name);
}

/// Makes bars [start]..[end] one section named [name]. Boundaries inside
/// the range go (steps that played those sections are dropped), and the bars
/// after [end] keep the section they were in, so only the chosen bars change.
PlaybackSequence setSectionRange(
  MusicScore score,
  PlaybackSequence sequence, {
  required int start,
  required int end,
  required String name,
}) {
  if (end < start) (start, end) = (end, start);
  final count = score.measureCount;
  if (start < 0 || end >= count) {
    throw RangeError.range(end, 0, count - 1, 'end');
  }
  final marks = _editableMarks(score, sequence);
  String? rest;
  if (end + 1 < count && !marks.any((m) => m.startMeasureIndex == end + 1)) {
    rest = '';
    for (final section in scoreSections(score, sequence)) {
      if (section.contains(end + 1)) rest = section.name;
    }
  }
  final removed = {
    for (final mark in marks)
      if (mark.startMeasureIndex > start && mark.startMeasureIndex <= end)
        sectionIdAt(mark.startMeasureIndex),
  };
  return _withoutLostSteps(
    score,
    sequence.copyWith(
      marks: [
        for (final mark in marks)
          if (mark.startMeasureIndex < start || mark.startMeasureIndex > end)
            mark,
        SectionMark(startMeasureIndex: start, name: name),
        if (rest != null) SectionMark(startMeasureIndex: end + 1, name: rest),
      ],
      steps: [
        for (final step in sequence.steps)
          if (!removed.contains(step.sectionId)) step,
      ],
    ),
  );
}

/// Moves section boundaries with their bars after bars were inserted,
/// deleted or moved. [before] and [after] are the bar ids (see
/// `MusicScoreEditor.measureIds`) of the score [sequence] was made for and of
/// the edited score. A section now starts at its first bar still there; a
/// section whose bars are all gone is dropped with its steps. [writtenMarks]
/// are the score's rehearsal-mark boundaries (see [rehearsalSectionMarks]),
/// used when [sequence] has none of its own.
PlaybackSequence remapSectionMarks(
  PlaybackSequence sequence,
  List<int> before,
  List<int> after, {
  List<SectionMark> writtenMarks = const [],
}) {
  // Sections read from the score's own rehearsal marks move with it only
  // once they are boundaries of their own.
  if (sequence.marks.isEmpty && writtenMarks.isNotEmpty) {
    sequence = sequence.copyWith(marks: writtenMarks);
  }
  if (sequence.marks.isEmpty) return sequence;
  final position = {for (var i = 0; i < after.length; i++) after[i]: i};
  final moved = <String, int>{};
  final marks = <SectionMark>[];
  for (var index = 0; index < sequence.marks.length; index++) {
    final mark = sequence.marks[index];
    final end = index + 1 < sequence.marks.length
        ? sequence.marks[index + 1].startMeasureIndex
        : before.length;
    int? start;
    for (var bar = mark.startMeasureIndex; bar < end; bar++) {
      if (bar >= before.length) break;
      final at = position[before[bar]];
      if (at != null && (start == null || at < start)) start = at;
    }
    if (start == null) continue;
    moved[mark.id] = start;
    marks.add(
      SectionMark(
        startMeasureIndex: start,
        name: mark.name,
        continued: mark.continued,
      ),
    );
  }
  // Bars before the first boundary form an unnamed first section. It is
  // still there when bars come before the first boundary that is left; when
  // the first boundary now stands on the first bar, or no boundary is left
  // at all, there is no such section and its steps go with it: they would
  // play a section that is not there, or another one.
  final starts = [for (final mark in marks) mark.startMeasureIndex]..sort();
  if (sequence.marks.first.startMeasureIndex > 0 &&
      starts.isNotEmpty &&
      starts.first > 0) {
    moved[sectionIdAt(0)] = 0;
  }
  return PlaybackSequence(
    marks: marks,
    steps: [
      for (final step in sequence.steps)
        if (step.sectionId.startsWith(_legacyNamePrefix))
          step
        else if (moved[step.sectionId] case final start?)
          step.copyWith(sectionId: sectionIdAt(start)),
    ],
  );
}

/// Removes the boundary at bar [measureIndex]; its bars join the previous
/// section. Steps that played the removed section are dropped.
PlaybackSequence removeSectionBoundary(
  MusicScore score,
  PlaybackSequence sequence, {
  required int measureIndex,
}) {
  final marks = _editableMarks(score, sequence);
  if (!marks.any((mark) => mark.startMeasureIndex == measureIndex)) {
    return sequence;
  }
  final removedId = sectionIdAt(measureIndex);
  return _withoutLostSteps(
    score,
    sequence.copyWith(
      marks: [
        for (final mark in marks)
          if (mark.startMeasureIndex != measureIndex) mark,
      ],
      steps: [
        for (final step in sequence.steps)
          if (step.sectionId != removedId) step,
      ],
    ),
  );
}

List<SectionMark> _editableMarks(MusicScore score, PlaybackSequence sequence) {
  return sequence.marks.isNotEmpty
      ? sequence.marks
      : rehearsalSectionMarks(score);
}

/// Replaces steps saved by older app versions, which named a section and
/// meant every section with that name, by steps that point at one section
/// each. Old rehearsal-mark boundaries move into the sidecar at the same time.
PlaybackSequence materializePlaybackSequence(
  MusicScore score,
  PlaybackSequence sequence,
) {
  if (!sequence.steps.any((s) => s.sectionId.startsWith(_legacyNamePrefix))) {
    return sequence;
  }
  final marks = _editableMarks(score, sequence);
  final explicit = PlaybackSequence(marks: marks, steps: sequence.steps);
  return PlaybackSequence(
    marks: marks,
    steps: [
      for (final (:section, :repeats, pass: _) in resolvePlaybackSteps(
        score,
        explicit,
      ))
        PlaybackStep(sectionId: section.id, repeats: repeats),
    ],
  );
}

/// The order as sections with repeat counts. Steps whose section no longer
/// exists are skipped. Empty when bars play as written.
List<({ScoreSection section, int repeats, int? pass})> resolvePlaybackSteps(
  MusicScore score,
  PlaybackSequence sequence,
) {
  if (sequence.isEmpty) return const [];
  final sections = scoreSections(score, sequence);
  final result = <({ScoreSection section, int repeats, int? pass})>[];
  for (final step in sequence.steps) {
    if (step.sectionId.startsWith(_legacyNamePrefix)) {
      final name = step.sectionId.substring(_legacyNamePrefix.length);
      for (final section in sections) {
        if (section.name == name) {
          result.add((section: section, repeats: step.repeats, pass: null));
        }
      }
      continue;
    }
    for (final section in sections) {
      if (section.id == step.sectionId) {
        result.add((section: section, repeats: step.repeats, pass: step.pass));
        break;
      }
    }
  }
  return result;
}

/// Written bar index for each bar of the performance, in playing order.
///
/// With no custom order the written repeat signs apply, as they do for
/// playback. A custom order already says how often each section plays, so
/// repeat signs inside its sections are ignored; ending brackets still pick
/// the bars of each pass (see [_customOrder]).
List<int> performanceMeasureMap(MusicScore score, PlaybackSequence sequence) {
  final steps = resolvePlaybackSteps(score, sequence);
  if (steps.isEmpty) return writtenRepeatOrder(score);
  return _customOrder(score, steps).map;
}

/// Section boundaries of the performance laid out bar by bar: every pass of
/// every step starts a section with the step's name, so the expanded copy
/// of a custom order shows the same sections as the written score, and a
/// section played twice reads as two (Verse 1, Verse 2).
List<SectionMark> performanceSectionMarks(
  MusicScore score,
  PlaybackSequence sequence,
) {
  final steps = resolvePlaybackSteps(score, sequence);
  if (steps.isEmpty) return const [];
  final starts = _customOrder(score, steps).starts;
  return [
    for (final (:start, :name, :step, :pass) in starts)
      SectionMark(
        startMeasureIndex: start,
        name: name,
        // A split piece right after the piece before it goes on without a
        // new box, as in the written score.
        continued:
            pass == 1 &&
            step > 0 &&
            steps[step].section.continued &&
            steps[step - 1].section.endMeasureIndex + 1 ==
                steps[step].section.startMeasureIndex,
      ),
  ];
}

/// The written bars each step of [sequence] plays, in the order it plays
/// them: what a step is, said in bars. A step through a first ending and
/// the same step through the second differ in nothing else. A step whose
/// section is gone plays nothing.
List<List<int>> playbackStepBars(MusicScore score, PlaybackSequence sequence) {
  final sections = {
    for (final section in scoreSections(score, sequence)) section.id: section,
  };
  final endings = _endingNumbers(score.parts.first.measures);
  return [
    for (final step in sequence.steps)
      if (sections[step.sectionId] case final section?)
        _sectionPasses(section, step.repeats, step.pass, endings)
      else
        const <int>[],
  ];
}

/// Bars as the runs they form, by their printed numbers: "5–7, 10".
String barRuns(List<int> bars, {int firstBarNumber = 1}) {
  final runs = <String>[];
  var i = 0;
  while (i < bars.length) {
    var j = i;
    while (j + 1 < bars.length && bars[j + 1] == bars[j] + 1) {
      j++;
    }
    final from = bars[i] + firstBarNumber;
    final to = bars[j] + firstBarNumber;
    runs.add(from == to ? '$from' : '$from–$to');
    i = j + 1;
  }
  return runs.join(', ');
}

/// Plays each step's section [repeats] times. The last pass takes the last
/// ending bracket, which leads out of the section; every other pass takes the
/// bracket before it that names the pass, else the first one, which leads
/// back. So "Chorus ×2" plays 1st then 2nd ending, and a chorus played once
/// after a D.S. takes the 2nd ending. A step played once with a [pass] takes
/// the bracket naming that pass, as a written repeat spanning several
/// sections does.
({List<int> map, List<({int start, String name, int step, int pass})> starts})
_customOrder(
  MusicScore score,
  List<({ScoreSection section, int repeats, int? pass})> steps,
) {
  final endings = _endingNumbers(score.parts.first.measures);
  final map = <int>[];
  final starts = <({int start, String name, int step, int pass})>[];
  for (var index = 0; index < steps.length; index++) {
    final (:section, :repeats, :pass) = steps[index];
    final bars = _sectionPasses(section, repeats, pass, endings);
    // Every pass begins at the section's first bar.
    var passes = 0;
    for (var i = 0; i < bars.length; i++) {
      if (bars[i] == section.startMeasureIndex || i == 0) {
        starts.add((
          start: map.length + i,
          name: section.name,
          step: index,
          pass: ++passes,
        ));
      }
    }
    map.addAll(bars);
    if (map.length > maxExpandedMeasures) {
      throw const FormatException('Playback Sequence is too long.');
    }
  }
  return (map: map, starts: starts);
}

/// The bars of [section] played [repeats] times (see [_customOrder]). A pass
/// through a bracket other than the last goes back after that bracket, so
/// it skips the bars after it. A [writtenPass] no bracket names plays no
/// ending: its brackets lie in the next section.
List<int> _sectionPasses(
  ScoreSection section,
  int repeats,
  int? writtenPass,
  List<List<int>> endings,
) {
  final groups = <String, List<int>>{};
  for (var i = section.startMeasureIndex; i <= section.endMeasureIndex; i++) {
    if (endings[i].isNotEmpty) groups[endings[i].join(',')] = endings[i];
  }
  // Brackets that lead back into the section: all but the last.
  final back = groups.length > 1
      ? groups.entries.take(groups.length - 1).toList()
      : groups.entries.toList();
  if (repeats == 1 && writtenPass == 0) {
    return [
      for (var i = section.startMeasureIndex; i <= section.endMeasureIndex; i++)
        i,
    ];
  }
  final bars = <int>[];
  for (var pass = 1; pass <= repeats; pass++) {
    String? group;
    var leadsBack = false;
    if (groups.isNotEmpty) {
      if (repeats == 1 && writtenPass != null) {
        group = groups.entries
            .where((e) => e.value.contains(writtenPass))
            .firstOrNull
            ?.key;
        leadsBack = group != null && group != groups.keys.last;
      } else if (pass == repeats) {
        group = groups.keys.last;
      } else {
        group =
            back.where((e) => e.value.contains(pass)).firstOrNull?.key ??
            back.first.key;
        leadsBack = groups.length > 1;
      }
    }
    for (var i = section.startMeasureIndex; i <= section.endMeasureIndex; i++) {
      final here = endings[i].join(',');
      if (endings[i].isNotEmpty && here != group) continue;
      bars.add(i);
      final next = i + 1 < endings.length ? endings[i + 1].join(',') : '';
      if (leadsBack && here == group && next != group) break;
    }
  }
  if (bars.isEmpty) {
    // A pass no bracket serves (stale data): the section, once, as written.
    return [
      for (var i = section.startMeasureIndex; i <= section.endMeasureIndex; i++)
        i,
    ];
  }
  return bars;
}

/// Ending numbers in force on each bar: a bracket runs from its start to its
/// stop or discontinue, which may be bars later.
List<List<int>> _endingNumbers(List<MusicMeasure> measures) {
  final endings = List<List<int>>.filled(measures.length, const []);
  var active = const <int>[];
  for (var index = 0; index < measures.length; index++) {
    for (final barline in measures[index].barlines) {
      if (barline.endingType == 'start') active = barline.endingNumbers;
    }
    endings[index] = active;
    if (measures[index].barlines.any(
      (b) => b.endingType == 'stop' || b.endingType == 'discontinue',
    )) {
      active = const [];
    }
  }
  return endings;
}

/// A custom order that plays exactly what the written score plays, the
/// starting point for arranging it.
///
/// Where the written order jumps into or out of the middle of a section (a
/// segno, a repeat start, To Coda, the coda), the section is split there by a
/// boundary with the same name, so every run of bars is a whole section. Each
/// run becomes a step: a section repeated right after itself counts up the
/// step's repeats, and a run through an ending bracket remembers its pass.
/// Returns [sequence] unchanged when the score has no sections.
PlaybackSequence writtenOrderSequence(
  MusicScore score,
  PlaybackSequence sequence,
) {
  final order = writtenRepeatOrder(score);
  if (order.isEmpty || scoreSections(score, sequence).isEmpty) {
    return sequence;
  }
  // First keep endings inside sections, for fewer steps; where that does not
  // play the same bars (unusual bracket layouts), split at every jump, which
  // always does: each run of bars is then a whole section.
  final compact = _writtenOrder(score, sequence, order, splitEndings: false);
  if (_listEquals(performanceMeasureMap(score, compact), order)) return compact;
  return _writtenOrder(score, sequence, order, splitEndings: true);
}

PlaybackSequence _writtenOrder(
  MusicScore score,
  PlaybackSequence sequence,
  List<int> order, {
  required bool splitEndings,
}) {
  final count = score.measureCount;
  final existing = scoreSections(score, sequence);
  final endings = _endingNumbers(score.parts.first.measures);
  // The music may start later (a pickup section) or stop early (Fine).
  final splits = <int>{order.first, if (order.last + 1 < count) order.last + 1};
  for (var i = 1; i < order.length; i++) {
    final (a, b) = (order[i - 1], order[i]);
    if (b == a + 1) continue;
    if (!splitEndings) {
      // Skipping a 1st ending into the 2nd stays within the passage.
      var overEnding = b > a + 1;
      for (var bar = a + 1; overEnding && bar < b; bar++) {
        overEnding = endings[bar].isNotEmpty;
      }
      if (overEnding) continue;
    }
    splits.add(b);
    // Going back from a 1st ending, the passage later goes on through the
    // next ending: not a way out of the section.
    final fromEnding =
        !splitEndings &&
        a + 1 < count &&
        endings[a].isNotEmpty &&
        endings[a + 1].isNotEmpty;
    if (a + 1 < count && !fromEnding) splits.add(a + 1);
  }
  final starts = {for (final section in existing) section.startMeasureIndex};
  final marks = [
    ..._editableMarks(score, sequence),
    for (final bar in splits)
      if (!starts.contains(bar))
        SectionMark(
          startMeasureIndex: bar,
          name: existing.lastWhere((s) => s.startMeasureIndex <= bar).name,
          continued: true,
        ),
  ];
  final split = sequence.copyWith(marks: marks, steps: const []);
  final sections = scoreSections(score, split);

  // Runs of bars in one section.
  final runs = <({ScoreSection section, List<int> bars})>[];
  for (final index in order) {
    final section = sections.lastWhere((s) => s.startMeasureIndex <= index);
    final last = runs.lastOrNull;
    if (last == null ||
        last.section.id != section.id ||
        index <= last.bars.last) {
      runs.add((section: section, bars: [index]));
    } else {
      last.bars.add(index);
    }
  }
  final steps = <PlaybackStep>[];
  for (var i = 0; i < runs.length;) {
    // A section played again right after itself becomes one step ×N when
    // that plays the same bars.
    var j = i + 1;
    while (j < runs.length && runs[j].section.id == runs[i].section.id) {
      j++;
    }
    final together = [for (final run in runs.sublist(i, j)) ...run.bars];
    final times = j - i;
    if (times > 1 &&
        times <= maxPlaybackRepeats &&
        _listEquals(
          _sectionPasses(runs[i].section, times, null, endings),
          together,
        )) {
      steps.add(PlaybackStep(sectionId: runs[i].section.id, repeats: times));
      i = j;
      continue;
    }
    // Played once, a run is the section with no pass (its last ending) or
    // the pass whose ending, or lack of one, it went through.
    final run = runs[i];
    int? pass;
    if (!_listEquals(_sectionPasses(run.section, 1, null, endings), run.bars)) {
      for (final candidate in [
        for (var n = 1; n <= maxPlaybackRepeats; n++) n,
        0,
      ]) {
        if (_listEquals(
          _sectionPasses(run.section, 1, candidate, endings),
          run.bars,
        )) {
          pass = candidate;
          break;
        }
      }
    }
    steps.add(PlaybackStep(sectionId: run.section.id, pass: pass));
    i++;
  }
  return split.copyWith(steps: steps);
}

bool _listEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Identifies the expanded copy made from version [versionId] in the order
/// [sequence], so making it again opens the copy instead of a duplicate.
String performanceOrigin(String versionId, PlaybackSequence sequence) =>
    jsonEncode({'from': versionId, 'order': sequence.toJson()});

/// Bars in the order the written repeat signs and jumps play them.
///
/// Repeats mirror the MIDI mapper used for playback (flutter_notemus): a
/// repeat block runs from a start sign, or the bar after the previous block,
/// to an end sign and plays `times` passes (default 2). A bar that starts an
/// ending bracket plays only on the passes it names.
///
/// Jumps follow the usual convention: D.S. (to the segno, else the start) or
/// D.C. (to the start) is taken once, at the end of its bar on the last pass.
/// After the jump repeats play once, taking only the last ending, and the
/// music stops after a bar marked Fine, or goes from the To Coda bar to the
/// coda sign.
List<int> writtenRepeatOrder(MusicScore score) {
  if (score.parts.isEmpty) return const [];
  final measures = score.parts.first.measures;
  final count = measures.length;
  final endings = _endingNumbers(measures);
  final blocks = <int, ({int end, int times})>{};
  final blockOf = List<({int start, int end, int times})?>.filled(count, null);
  var start = 0;
  for (var index = 0; index < count; index++) {
    if (measures[index].repeatStart) start = index;
    if (measures[index].repeatEnd) {
      // Brackets "1-5." then "6." ask for six passes whatever `times` says.
      var times = measures[index].repeatTimes;
      for (var bar = start; bar <= index + 1 && bar < count; bar++) {
        for (final number in endings[bar]) {
          if (number > times) times = number;
        }
      }
      times = times.clamp(1, maxPlaybackRepeats);
      blocks[start] = (end: index, times: times);
      for (var bar = start; bar <= index; bar++) {
        blockOf[bar] = (start: start, end: index, times: times);
      }
      start = index + 1;
    }
  }
  bool playsOnPass(int index, int pass) =>
      endings[index].isEmpty || endings[index].contains(pass);

  final marks = [for (final measure in measures) measure.navigation];
  final segno = marks.indexWhere((m) => m.contains(MusicNavigation.segno));
  final coda = marks.indexWhere((m) => m.contains(MusicNavigation.coda));
  final order = <int>[];
  var jumped = false;
  // From the D.S./D.C. jump, repeats play once until To Coda, or until the
  // music goes on past every bar played before the jump: from there it is
  // new, and its repeats apply (a score whose "To Coda" was not read still
  // plays its later repeats).
  var singlePass = false;
  var playedBeforeJump = -1;

  /// Where to continue after playing [index] as written, or null to go on.
  /// Returns -1 to stop.
  int? after(int index) {
    final here = marks[index];
    if (!jumped) {
      if (here.contains(MusicNavigation.dalSegno)) {
        jumped = singlePass = true;
        playedBeforeJump = order.reduce(math.max);
        return segno >= 0 ? segno : 0;
      }
      if (here.contains(MusicNavigation.daCapo)) {
        jumped = singlePass = true;
        playedBeforeJump = order.reduce(math.max);
        return 0;
      }
      return null;
    }
    if (here.contains(MusicNavigation.fine)) return -1;
    if (here.contains(MusicNavigation.toCoda) && coda > index) {
      singlePass = false;
      return coda;
    }
    return null;
  }

  var cursor = 0;
  while (cursor >= 0 && cursor < count) {
    if (order.length > maxExpandedMeasures) {
      throw const FormatException('Playback Sequence is too long.');
    }
    if (singlePass && cursor > playedBeforeJump) singlePass = false;
    final block = singlePass ? null : blocks[cursor];
    if (block != null) {
      int? next;
      passes:
      for (var pass = 1; pass <= block.times; pass++) {
        for (var index = cursor; index <= block.end; index++) {
          if (!playsOnPass(index, pass)) continue;
          order.add(index);
          if (pass == block.times) {
            next = after(index);
            if (next != null) break passes;
          }
        }
      }
      cursor = next ?? block.end + 1;
      continue;
    }
    // Played once after a jump, a repeated passage takes its last ending.
    final enclosing = blockOf[cursor];
    if (singlePass &&
        enclosing != null &&
        !playsOnPass(cursor, enclosing.times)) {
      cursor++;
      continue;
    }
    order.add(cursor);
    cursor = after(cursor) ?? cursor + 1;
  }
  return order;
}

bool _isStraight(List<int> map, int count) {
  if (map.length != count) return false;
  for (var index = 0; index < map.length; index++) {
    if (map[index] != index) return false;
  }
  return true;
}

/// True when the score has a jump (D.S., D.C.) the written order must follow.
bool hasNavigationJumps(MusicScore score) {
  if (score.parts.isEmpty) return false;
  return score.parts.first.measures.any(
    (measure) => measure.navigation.any(
      (mark) =>
          mark == MusicNavigation.dalSegno || mark == MusicNavigation.daCapo,
    ),
  );
}

/// Length of each written bar in quarter notes. A pickup or an incomplete
/// converted bar uses its notes; a full bar uses the time signature.
List<double> measureQuarterLengths(MusicScore score) {
  if (score.parts.isEmpty) return const [];
  final measures = score.parts.first.measures;
  return [
    for (final measure in measures)
      () {
        final attributes = measure.attributes;
        final time =
            attributes.time ?? const MusicTimeSignature(beats: 4, beatType: 4);
        final bar = time.beats * 4 / time.beatType;
        final written = measure.durationDivisions / attributes.divisions;
        if (measure.implicit && written > 0) return written;
        return math.max(bar, written);
      }(),
  ];
}

/// Bars and quarter notes the performance plays, and written bars it skips.
({int measures, double quarters, int skipped}) performanceSummary(
  MusicScore score,
  PlaybackSequence sequence,
) {
  final map = performanceMeasureMap(score, sequence);
  final lengths = measureQuarterLengths(score);
  final played = map.toSet();
  return (
    measures: map.length,
    quarters: map.fold<double>(0, (sum, index) => sum + lengths[index]),
    skipped: score.measureCount - played.length,
  );
}

/// The written bar playing at [fraction] (0..1) of the performance, assuming
/// a steady tempo.
int writtenMeasureAt(
  List<int> map,
  List<double> quarterLengths,
  double fraction,
) {
  if (map.isEmpty) return 0;
  final total = map.fold<double>(
    0,
    (sum, index) => sum + quarterLengths[index],
  );
  if (total <= 0) return map.first;
  final target = fraction.clamp(0.0, 1.0) * total;
  var elapsed = 0.0;
  for (final index in map) {
    elapsed += quarterLengths[index];
    if (target < elapsed) return index;
  }
  return map.last;
}

/// Where in the performance (0..1) the written bar [measureIndex] starts,
/// or null when the order never plays it. A bar that is played more than
/// once (a repeat, a section played twice) answers with the time nearest
/// to [near], so pressing a bar while the music plays stays in the pass
/// that is playing.
double? performanceStartOf(
  List<int> map,
  List<double> quarterLengths,
  int measureIndex, {
  double near = 0,
}) {
  final total = map.fold<double>(
    0,
    (sum, index) => sum + quarterLengths[index],
  );
  if (total <= 0) return map.contains(measureIndex) ? 0 : null;
  double? best;
  var elapsed = 0.0;
  for (final index in map) {
    if (index == measureIndex) {
      final start = elapsed / total;
      if (best == null || (start - near).abs() < (best - near).abs()) {
        best = start;
      }
    }
    elapsed += quarterLengths[index];
  }
  return best;
}

String normalizePlaybackSection(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  return switch (trimmed.toUpperCase()) {
    'INTRO' || 'IN' => 'INTRO',
    'VERSE' || 'V' => 'VERSE',
    'PRE' || 'PRE-CHORUS' || 'PRECHORUS' => 'PRE',
    'CHORUS' || 'CH' => 'CHORUS',
    'BRIDGE' || 'BR' => 'BRIDGE',
    'SOLO' => 'SOLO',
    'INTERLUDE' => 'INTERLUDE',
    'OUTRO' || 'OUT' => 'OUTRO',
    _ => trimmed,
  };
}

/// Rehearsal marks actually written on a measure, not the filled range.
List<String?> measureSectionMarks(MusicScore score) {
  if (score.parts.isEmpty) return const [];
  return [
    for (final measure in score.parts.first.measures)
      measurePlaybackSection(measure),
  ];
}

String? measurePlaybackSection(MusicMeasure measure) {
  for (final event in measure.events) {
    if (event is MusicDirection) {
      final mark = normalizePlaybackSection(event.rehearsal ?? '');
      if (mark.isNotEmpty) return mark;
    }
  }
  return null;
}

/// Plays the sections in order, or returns [score] when bars play as
/// written. The written score is never changed.
///
/// Repeats alone are kept as written (an export stays a readable score) and
/// jumps are laid out bar by bar. With [flattenRepeats] repeats are laid out
/// too, so playback follows [performanceMeasureMap] exactly, the same order
/// the play head and the expanded copy use.
MusicScore expandPlaybackSequence(
  MusicScore score, [
  PlaybackSequence sequence = PlaybackSequence.empty,
  bool flattenRepeats = false,
]) {
  final map = performanceMeasureMap(score, sequence);
  if (sequence.isEmpty &&
      (flattenRepeats
          ? _isStraight(map, score.measureCount)
          : !hasNavigationJumps(score))) {
    return score;
  }
  if (map.isEmpty) {
    throw const FormatException('Playback Sequence produced no measures.');
  }
  return score.copyWith(
    parts: [
      for (final part in score.parts)
        part.copyWith(
          measures: [
            for (var index = 0; index < map.length; index++)
              if (map[index] < part.measures.length)
                part.measures[map[index]].withoutRepeats().copyWith(
                  number: '${index + 1}',
                ),
          ],
        ),
    ],
  );
}
