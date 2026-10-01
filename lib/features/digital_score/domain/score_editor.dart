import 'dart:math' as math;

import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_layout.dart';

const int alphaTabQuarterTicks = 960;

class ScoreEventAddress {
  const ScoreEventAddress({
    required this.partIndex,
    required this.measureIndex,
    required this.eventIndex,
  });

  final int partIndex;
  final int measureIndex;
  final int eventIndex;

  @override
  bool operator ==(Object other) {
    return other is ScoreEventAddress &&
        other.partIndex == partIndex &&
        other.measureIndex == measureIndex &&
        other.eventIndex == eventIndex;
  }

  @override
  int get hashCode => Object.hash(partIndex, measureIndex, eventIndex);
}

abstract interface class ScoreEditCommand {
  MusicScore apply(MusicScore score);
}

class MusicScoreEditor {
  MusicScoreEditor(MusicScore score)
    : _states = [score],
      _ids = [List.generate(score.measureCount, (index) => index)],
      _nextId = score.measureCount;

  static const int _historyLimit = 100;

  final List<MusicScore> _states;

  /// Identity of each bar in every state: a bar keeps its id when bars are
  /// inserted, deleted or moved around it, and a new bar gets a new id. Lets
  /// section boundaries follow their bars (see `remapSectionMarks`).
  final List<List<int>> _ids;
  int _nextId;
  int _cursor = 0;
  int? _savedCursor = 0;

  MusicScore get score => _states[_cursor];
  List<int> get measureIds => _ids[_cursor];
  bool get canUndo => _cursor > 0;
  bool get canRedo => _cursor < _states.length - 1;
  bool get isDirty => _savedCursor != _cursor;

  void apply(ScoreEditCommand command) {
    final next = command.apply(score);
    final ids = _idsAfter(command, measureIds, next.measureCount);
    if (_cursor < _states.length - 1) {
      if (_savedCursor != null && _savedCursor! > _cursor) {
        _savedCursor = null;
      }
      _states.removeRange(_cursor + 1, _states.length);
      _ids.removeRange(_cursor + 1, _ids.length);
    }
    _states.add(next);
    _ids.add(ids);
    _cursor++;
    if (_states.length > _historyLimit + 1) {
      _states.removeAt(0);
      _ids.removeAt(0);
      _cursor--;
      if (_savedCursor case final saved?) {
        _savedCursor = saved == 0 ? null : saved - 1;
      }
    }
  }

  List<int> _idsAfter(ScoreEditCommand command, List<int> ids, int count) {
    final next = ids.toList();
    switch (command) {
      case InsertMeasureCommand(:final afterMeasureIndex):
        next.insert(afterMeasureIndex + 1, _nextId++);
      case DuplicateMeasureCommand(:final measureIndex):
        next.insert(measureIndex + 1, _nextId++);
      case DeleteMeasureCommand(:final measureIndex):
        next.removeAt(measureIndex);
      case MoveMeasureCommand(:final fromIndex, :final toIndex):
        next.insert(toIndex, next.removeAt(fromIndex));
      default:
        break;
    }
    if (next.length == count) return List.unmodifiable(next);
    // An edit this does not model changed the bar count: bars start over.
    return List.unmodifiable([for (var i = 0; i < count; i++) _nextId++]);
  }

  void undo() {
    if (canUndo) _cursor--;
  }

  void redo() {
    if (canRedo) _cursor++;
  }

  void markSaved() {
    _savedCursor = _cursor;
  }

  /// Replaces the in-memory editing history with a clean saved snapshot.
  ///
  /// Save-as-version uses this to leave the previous version unchanged after
  /// its edited score has been copied into the newly created version.
  void resetTo(MusicScore score) {
    _states
      ..clear()
      ..add(score);
    _ids
      ..clear()
      ..add(List.generate(score.measureCount, (index) => _nextId + index));
    _nextId += score.measureCount;
    _cursor = 0;
    _savedCursor = 0;
  }
}

class InsertScoreEventCommand implements ScoreEditCommand {
  const InsertScoreEventCommand({
    required this.partIndex,
    required this.measureIndex,
    required this.event,
  });

  final int partIndex;
  final int measureIndex;
  final MusicEvent event;

  @override
  MusicScore apply(MusicScore score) {
    final measure = _measureAt(score, partIndex, measureIndex);
    _validateEvent(measure, event);
    final events = _normalizeNoteChords([...measure.events, event]);
    return _replaceMeasure(
      score,
      partIndex,
      measureIndex,
      measure.copyWith(events: events),
    );
  }
}

class ReplaceScoreEventCommand implements ScoreEditCommand {
  const ReplaceScoreEventCommand({required this.address, required this.event});

  final ScoreEventAddress address;
  final MusicEvent event;

  @override
  MusicScore apply(MusicScore score) {
    final measure = _measureAt(score, address.partIndex, address.measureIndex);
    _eventAt(measure, address.eventIndex);
    _validateEvent(measure, event);
    final events = measure.events.toList();
    events[address.eventIndex] = event;
    return _replaceMeasure(
      score,
      address.partIndex,
      address.measureIndex,
      measure.copyWith(events: _normalizeNoteChords(events)),
    );
  }
}

class DeleteScoreEventCommand implements ScoreEditCommand {
  const DeleteScoreEventCommand(this.address);

  final ScoreEventAddress address;

  @override
  MusicScore apply(MusicScore score) {
    final measure = _measureAt(score, address.partIndex, address.measureIndex);
    _eventAt(measure, address.eventIndex);
    final events = measure.events.toList()..removeAt(address.eventIndex);
    return _replaceMeasure(
      score,
      address.partIndex,
      address.measureIndex,
      measure.copyWith(events: _normalizeNoteChords(events)),
    );
  }
}

class UpdateMeasureAttributesCommand implements ScoreEditCommand {
  const UpdateMeasureAttributesCommand({
    required this.measureIndex,
    required this.keyFifths,
    required this.time,
  });

  final int measureIndex;
  final int keyFifths;
  final MusicTimeSignature time;

  @override
  MusicScore apply(MusicScore score) {
    if (keyFifths < -7 || keyFifths > 7) {
      throw const FormatException('Key signature must be between -7 and 7.');
    }
    if (time.beats <= 0 || !const {1, 2, 4, 8, 16}.contains(time.beatType)) {
      throw const FormatException('Invalid time signature.');
    }
    var changed = false;
    final parts = <MusicPart>[];
    for (final part in score.parts) {
      if (measureIndex < 0 || measureIndex >= part.measures.length) {
        parts.add(part);
        continue;
      }
      changed = true;
      final measures = part.measures.toList();
      final measure = measures[measureIndex];
      final attributes = measure.attributes.copyWith(
        keyFifths: keyFifths,
        time: time,
      );
      final capacity = measureCapacity(attributes);
      if (measure.notes.any((note) => !note.isGrace && note.end > capacity)) {
        throw const FormatException(
          'Existing notes do not fit the new time signature.',
        );
      }
      measures[measureIndex] = measure.copyWith(attributes: attributes);
      parts.add(part.copyWith(measures: measures));
    }
    if (!changed) throw RangeError.index(measureIndex, score.parts);
    return score.copyWith(parts: parts);
  }
}

class UpdateSystemSectionCommand implements ScoreEditCommand {
  const UpdateSystemSectionCommand({
    required this.measureIndex,
    required this.section,
    this.systems = const [],
  });

  final int measureIndex;
  final String? section;
  final List<ScoreSystemSpan> systems;

  @override
  MusicScore apply(MusicScore score) {
    final count = score.measureCount;
    final start = scoreSystemStart(measureIndex, systems);
    final end = scoreSystemEnd(measureIndex, count, systems);
    var next = score;
    for (var index = start; index <= end; index++) {
      next = UpdateMeasureSectionCommand(
        measureIndex: index,
        section: index == start ? section : null,
      ).apply(next);
    }
    return next;
  }
}

class UpdateMeasureSectionCommand implements ScoreEditCommand {
  const UpdateMeasureSectionCommand({
    required this.measureIndex,
    required this.section,
  });

  final int measureIndex;
  final String? section;

  @override
  MusicScore apply(MusicScore score) {
    final normalized = section == null || section!.trim().isEmpty
        ? null
        : normalizePlaybackSection(section!);
    var changed = false;
    final parts = <MusicPart>[];
    for (final part in score.parts) {
      if (measureIndex < 0 || measureIndex >= part.measures.length) {
        parts.add(part);
        continue;
      }
      changed = true;
      final measures = part.measures.toList();
      measures[measureIndex] = _withSection(measures[measureIndex], normalized);
      parts.add(part.copyWith(measures: measures));
    }
    if (!changed) throw RangeError.index(measureIndex, score.parts);
    return score.copyWith(parts: parts);
  }
}

class InsertMeasureCommand implements ScoreEditCommand {
  const InsertMeasureCommand({required this.afterMeasureIndex});

  final int afterMeasureIndex;

  @override
  MusicScore apply(MusicScore score) {
    if (afterMeasureIndex < -1 || afterMeasureIndex >= score.measureCount) {
      throw RangeError.index(afterMeasureIndex, score.parts);
    }
    final insertionIndex = afterMeasureIndex + 1;
    final parts = score.parts.map((part) {
      final sourceIndex = math.min(
        math.max(afterMeasureIndex, 0),
        part.measures.length - 1,
      );
      final attributes = part.measures[sourceIndex].attributes;
      final duration = measureCapacity(attributes);
      final events = [
        for (var staff = 1; staff <= attributes.staves; staff++)
          MusicNote(
            onset: 0,
            duration: duration,
            voice: '$staff',
            staff: staff,
          ),
      ];
      final measures = part.measures.toList();
      final partInsertionIndex = math.min(insertionIndex, measures.length);
      measures.insert(
        partInsertionIndex,
        MusicMeasure(
          number: '${partInsertionIndex + 1}',
          attributes: attributes,
          events: events,
        ),
      );
      return part.copyWith(measures: _renumber(measures));
    }).toList();
    return score.copyWith(parts: parts);
  }
}

class MoveMeasureCommand implements ScoreEditCommand {
  const MoveMeasureCommand({required this.fromIndex, required this.toIndex});

  final int fromIndex;
  final int toIndex;

  @override
  MusicScore apply(MusicScore score) {
    if (fromIndex == toIndex) return score;
    if (fromIndex < 0 ||
        toIndex < 0 ||
        fromIndex >= score.measureCount ||
        toIndex >= score.measureCount) {
      throw RangeError.index(fromIndex, score.parts);
    }
    final parts = score.parts.map((part) {
      final measures = part.measures.toList();
      if (fromIndex >= measures.length || toIndex >= measures.length) {
        return part;
      }
      final moved = measures.removeAt(fromIndex);
      measures.insert(toIndex, moved);
      return part.copyWith(measures: _renumber(measures));
    }).toList();
    return score.copyWith(parts: parts);
  }
}

class DeleteMeasureCommand implements ScoreEditCommand {
  const DeleteMeasureCommand({required this.measureIndex});

  final int measureIndex;

  @override
  MusicScore apply(MusicScore score) {
    if (measureIndex < 0 || measureIndex >= score.measureCount) {
      throw RangeError.index(measureIndex, score.parts);
    }
    if (score.parts.any((part) => part.measures.length <= 1)) {
      throw const FormatException('A score must keep at least one measure.');
    }
    final parts = score.parts.map((part) {
      final measures = part.measures.toList();
      if (measureIndex < measures.length) measures.removeAt(measureIndex);
      return part.copyWith(measures: _renumber(measures));
    }).toList();
    return score.copyWith(parts: parts);
  }
}

class DuplicateMeasureCommand implements ScoreEditCommand {
  const DuplicateMeasureCommand({required this.measureIndex});

  final int measureIndex;

  @override
  MusicScore apply(MusicScore score) {
    if (measureIndex < 0 || measureIndex >= score.measureCount) {
      throw RangeError.index(measureIndex, score.parts);
    }
    final parts = score.parts.map((part) {
      final measures = part.measures.toList();
      if (measureIndex >= measures.length) return part;
      final source = measures[measureIndex];
      measures.insert(
        measureIndex + 1,
        source.copyWith(
          number: '${measureIndex + 2}',
          attributes: source.attributes.copyWith(
            clefs: Map<int, MusicClef>.from(source.attributes.clefs),
          ),
          events: [for (final event in source.events) _cloneEvent(event)],
        ),
      );
      return part.copyWith(measures: _renumber(measures));
    }).toList();
    return score.copyWith(parts: parts);
  }
}

MusicEvent _cloneEvent(MusicEvent event) {
  return switch (event) {
    final MusicNote note => note.copyWith(pitch: note.pitch, type: note.type),
    final MusicDirection direction => direction.copyWith(),
    final MusicHarmony harmony => harmony.copyWith(),
  };
}

ScoreEventAddress? findRenderedNoteAddress({
  required MusicScore score,
  required int partIndex,
  required int measureIndex,
  required int staff,
  required int onsetTicks,
  required int midi,
}) {
  if (partIndex < 0 || partIndex >= score.parts.length) return null;
  final part = score.parts[partIndex];
  if (measureIndex < 0 || measureIndex >= part.measures.length) return null;
  final measure = part.measures[measureIndex];
  final onset =
      (onsetTicks * measure.attributes.divisions / alphaTabQuarterTicks)
          .round();
  for (var index = 0; index < measure.events.length; index++) {
    final event = measure.events[index];
    if (event is MusicNote &&
        !event.isRest &&
        event.staff == staff &&
        event.onset == onset &&
        midiForPitch(event.pitch!) == midi) {
      return ScoreEventAddress(
        partIndex: partIndex,
        measureIndex: measureIndex,
        eventIndex: index,
      );
    }
  }
  return null;
}

int measureCapacity(MusicAttributes attributes) {
  final time =
      attributes.time ?? const MusicTimeSignature(beats: 4, beatType: 4);
  return math.max(
    1,
    (attributes.divisions * time.beats * 4 / time.beatType).round(),
  );
}

int midiForPitch(MusicPitch pitch) => pitch.midi;

MusicMeasure _withSection(MusicMeasure measure, String? section) {
  final events = <MusicEvent>[];
  var replaced = false;
  for (final event in measure.events) {
    if (event is! MusicDirection) {
      events.add(event);
      continue;
    }
    if (replaced) {
      if (event.rehearsal == null ||
          event.words != null ||
          event.tempoBpm != null) {
        events.add(event.copyWith(rehearsal: null));
      }
      continue;
    }
    replaced = true;
    if (section == null && event.words == null && event.tempoBpm == null) {
      continue;
    }
    events.add(event.copyWith(rehearsal: section));
  }
  if (!replaced && section != null) {
    events.insert(0, MusicDirection(onset: 0, staff: 1, rehearsal: section));
  }
  return measure.copyWith(events: events);
}

List<MusicMeasure> _renumber(List<MusicMeasure> measures) {
  return [
    for (var index = 0; index < measures.length; index++)
      measures[index].copyWith(number: '${index + 1}'),
  ];
}

MusicScore _replaceMeasure(
  MusicScore score,
  int partIndex,
  int measureIndex,
  MusicMeasure replacement,
) {
  _measureAt(score, partIndex, measureIndex);
  final parts = score.parts.toList();
  final part = parts[partIndex];
  final measures = part.measures.toList();
  measures[measureIndex] = replacement;
  parts[partIndex] = part.copyWith(measures: measures);
  return score.copyWith(parts: parts);
}

MusicMeasure _measureAt(MusicScore score, int partIndex, int measureIndex) {
  if (partIndex < 0 || partIndex >= score.parts.length) {
    throw RangeError.index(partIndex, score.parts);
  }
  final measures = score.parts[partIndex].measures;
  if (measureIndex < 0 || measureIndex >= measures.length) {
    throw RangeError.index(measureIndex, measures);
  }
  return measures[measureIndex];
}

MusicEvent _eventAt(MusicMeasure measure, int eventIndex) {
  if (eventIndex < 0 || eventIndex >= measure.events.length) {
    throw RangeError.index(eventIndex, measure.events);
  }
  return measure.events[eventIndex];
}

void _validateEvent(MusicMeasure measure, MusicEvent event) {
  if (event.onset < 0 ||
      event.staff <= 0 ||
      event.staff > measure.attributes.staves) {
    throw const FormatException('The event is outside the measure staff.');
  }
  final capacity = measureCapacity(measure.attributes);
  if (event.onset >= capacity) {
    throw const FormatException('The event starts outside the measure.');
  }
  if (event is MusicNote && !event.isGrace && event.end > capacity) {
    throw const FormatException('The note ends outside the measure.');
  }
}

List<MusicEvent> _normalizeNoteChords(List<MusicEvent> events) {
  final groups = <(String, int, int), List<int>>{};
  for (var index = 0; index < events.length; index++) {
    final event = events[index];
    if (event is! MusicNote || event.isGrace) continue;
    groups
        .putIfAbsent((event.voice, event.onset, event.staff), () => [])
        .add(index);
  }
  final normalized = events.toList();
  for (final indexes in groups.values) {
    if (indexes.length > 1 &&
        indexes.any((index) => (events[index] as MusicNote).isRest)) {
      throw const FormatException(
        'A rest cannot overlap another event in the same voice.',
      );
    }
    indexes.sort((left, right) {
      final leftNote = events[left] as MusicNote;
      final rightNote = events[right] as MusicNote;
      final staffOrder = leftNote.staff.compareTo(rightNote.staff);
      return staffOrder == 0 ? left.compareTo(right) : staffOrder;
    });
    for (var chordIndex = 0; chordIndex < indexes.length; chordIndex++) {
      final eventIndex = indexes[chordIndex];
      final note = events[eventIndex] as MusicNote;
      normalized[eventIndex] = note.copyWith(isChord: chordIndex > 0);
    }
  }
  return normalized;
}
