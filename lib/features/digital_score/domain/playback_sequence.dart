import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';

const standardPlaybackSections = <String>[
  'INTRO',
  'VERSE',
  'PRE',
  'CHORUS',
  'BRIDGE',
  'OUTRO',
];

const int minPlaybackRepeats = 1;
const int maxPlaybackRepeats = 16;
const int maxExpandedMeasures = 4096;

class PlaybackSequenceItem {
  PlaybackSequenceItem({required String section, this.repeats = 1})
    : section = normalizePlaybackSection(section) {
    if (this.section.isEmpty) {
      throw const FormatException('A playback section is required.');
    }
    if (repeats < minPlaybackRepeats || repeats > maxPlaybackRepeats) {
      throw const FormatException('Repeat count must be between 1 and 16.');
    }
  }

  final String section;
  final int repeats;

  PlaybackSequenceItem copyWith({String? section, int? repeats}) {
    return PlaybackSequenceItem(
      section: section ?? this.section,
      repeats: repeats ?? this.repeats,
    );
  }

  Map<String, Object> toJson() => {'section': section, 'repeats': repeats};

  @override
  bool operator ==(Object other) {
    return other is PlaybackSequenceItem &&
        other.section == section &&
        other.repeats == repeats;
  }

  @override
  int get hashCode => Object.hash(section, repeats);
}

class PlaybackSequence {
  PlaybackSequence([List<PlaybackSequenceItem>? items])
    : items = List.unmodifiable(items ?? const <PlaybackSequenceItem>[]);

  factory PlaybackSequence.fromJson(Object? json) {
    if (json == null) return PlaybackSequence.empty;
    if (json is! Map) {
      throw const FormatException('Playback Sequence JSON is invalid.');
    }
    final rawItems = json['items'];
    if (rawItems == null) return PlaybackSequence.empty;
    if (rawItems is! List) {
      throw const FormatException('Playback Sequence items are invalid.');
    }
    return PlaybackSequence([for (final item in rawItems) _itemFromJson(item)]);
  }

  const PlaybackSequence._(this.items);

  static const empty = PlaybackSequence._([]);

  final List<PlaybackSequenceItem> items;

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  bool get isIdentity => isEmpty || items.every((item) => item.repeats == 1);

  PlaybackSequence copyWith({List<PlaybackSequenceItem>? items}) {
    return PlaybackSequence(items ?? this.items);
  }

  Map<String, Object> toJson() => {
    'items': [for (final item in items) item.toJson()],
  };

  @override
  bool operator ==(Object other) {
    return other is PlaybackSequence &&
        other.items.length == items.length &&
        _sameItems(other.items);
  }

  bool _sameItems(List<PlaybackSequenceItem> other) {
    for (var index = 0; index < items.length; index++) {
      if (items[index] != other[index]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(items);
}

class ScoreSectionRange {
  const ScoreSectionRange({
    required this.section,
    required this.startMeasureIndex,
    required this.endMeasureIndex,
  });

  final String section;
  final int startMeasureIndex;
  final int endMeasureIndex;

  int get measureCount => endMeasureIndex - startMeasureIndex + 1;
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
    'OUTRO' || 'OUT' => 'OUTRO',
    _ => trimmed,
  };
}

List<String?> measureSectionCodes(MusicScore score) {
  if (score.parts.isEmpty) return const [];
  final count = score.parts.first.measures.length;
  final labels = List<String?>.filled(count, null);
  for (final range in discoverScoreSections(score)) {
    for (
      var index = range.startMeasureIndex;
      index <= range.endMeasureIndex;
      index++
    ) {
      labels[index] = range.section;
    }
  }
  return labels;
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

List<ScoreSectionRange> discoverScoreSections(MusicScore score) {
  final measures = score.parts.first.measures;
  final starts = <int, String>{};
  for (var index = 0; index < measures.length; index++) {
    final section = measurePlaybackSection(measures[index]);
    if (section != null) starts[index] = section;
  }
  if (starts.isEmpty) return const [];
  final indexes = starts.keys.toList()..sort();
  return [
    for (var index = 0; index < indexes.length; index++)
      ScoreSectionRange(
        section: starts[indexes[index]]!,
        startMeasureIndex: indexes[index],
        endMeasureIndex: index + 1 < indexes.length
            ? indexes[index + 1] - 1
            : measures.length - 1,
      ),
  ];
}

MusicScore expandPlaybackSequence(
  MusicScore score, [
  PlaybackSequence sequence = PlaybackSequence.empty,
]) {
  if (sequence.isEmpty) return score;

  final ranges = discoverScoreSections(score);
  if (ranges.isEmpty) {
    throw const FormatException('Playback Sequence needs section marks.');
  }

  final selected = <ScoreSectionRange>[];
  for (final item in sequence.items) {
    final matches = ranges.where((range) => range.section == item.section);
    if (matches.isEmpty) {
      throw FormatException('Unknown playback section: ${item.section}');
    }
    for (var repeat = 0; repeat < item.repeats; repeat++) {
      selected.addAll(matches);
    }
  }

  final expandedCount = selected.fold<int>(
    0,
    (sum, range) => sum + range.measureCount,
  );
  if (expandedCount > maxExpandedMeasures) {
    throw const FormatException('Playback Sequence is too long.');
  }

  return score.copyWith(
    parts: [for (final part in score.parts) _expandPart(part, selected)],
  );
}

PlaybackSequenceItem _itemFromJson(Object? json) {
  if (json is! Map) {
    throw const FormatException('Playback Sequence item is invalid.');
  }
  final section = json['section'];
  final repeats = json['repeats'];
  return PlaybackSequenceItem(
    section: section is String ? section : '',
    repeats: switch (repeats) {
      final int value => value,
      final num value => value.round(),
      final String value => int.tryParse(value) ?? 0,
      _ => 0,
    },
  );
}

MusicPart _expandPart(MusicPart part, List<ScoreSectionRange> ranges) {
  final measures = <MusicMeasure>[];
  for (final range in ranges) {
    if (range.endMeasureIndex >= part.measures.length) {
      throw const FormatException('A section is outside the score.');
    }
    for (
      var index = range.startMeasureIndex;
      index <= range.endMeasureIndex;
      index++
    ) {
      measures.add(part.measures[index]);
    }
  }
  if (measures.isEmpty) {
    throw const FormatException('Playback Sequence produced no measures.');
  }
  return part.copyWith(
    measures: [
      for (var index = 0; index < measures.length; index++)
        measures[index].copyWith(number: '${index + 1}'),
    ],
  );
}
