import 'dart:convert';
import 'dart:math' as math;

import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_editor.dart';
import 'package:page_a_diddle/features/piano/domain/app_score_element.dart';

/// Resolves app-owned score identities without retaining Verovio or Lomse ids.
///
/// A registry is rebuilt from the current MusicXML snapshot after every native
/// export. This makes engine ids disposable while keeping a deterministic
/// semantic locator for the next command.
class AppScoreElementRegistry {
  AppScoreElementRegistry(this.score);

  final MusicScore score;

  /// Creates the app key for one event in the current score snapshot.
  AppScoreElementKey keyForEvent({
    required int partIndex,
    required int measureIndex,
    required int eventIndex,
  }) {
    final part = _partAt(partIndex);
    final measure = _measureAt(part, measureIndex);
    if (eventIndex < 0 || eventIndex >= measure.events.length) {
      throw RangeError.index(eventIndex, measure.events);
    }
    final event = measure.events[eventIndex];
    final locator = _locatorForEvent(
      part: part,
      measure: measure,
      event: event,
      chordIndex: _chordIndexForEvent(measure, eventIndex, event),
    );
    return _keyForLocator(locator);
  }

  /// Resolves a rendered staff position into an app target and the native
  /// cursor coordinates derived from the same MusicXML snapshot.
  ///
  /// `onsetTicks` is local to the measure and uses the app's 960-PPQ clock.
  /// The returned Lomse time is absolute and uses Lomse's 64-units-per-quarter
  /// convention.
  ResolvedAppScoreTarget? resolveStaffPosition({
    required int partIndex,
    required int measureIndex,
    required int staff,
    required int onsetTicks,
    int? midi,
  }) {
    if (onsetTicks < 0 || staff <= 0) return null;
    if (partIndex < 0 || partIndex >= score.parts.length) return null;
    final part = score.parts[partIndex];
    if (measureIndex < 0 || measureIndex >= part.measures.length) return null;
    final measure = part.measures[measureIndex];
    final matching = _matchingNote(
      measure,
      staff: staff,
      onsetTicks: onsetTicks,
      midi: midi,
    );
    final voice = matching?.voice ?? staff.toString();
    final elementKind = matching == null
        ? 'insertion'
        : matching.isChord
        ? 'chordMember'
        : matching.isRest
        ? 'rest'
        : 'note';
    final eventIndex = matching == null
        ? null
        : measure.events.indexOf(matching);
    final locator = ScoreEventLocator(
      partId: part.id,
      measureUid: measureUidFor(part: part, measureIndex: measureIndex),
      staff: staff,
      voice: voice,
      onsetTicks: onsetTicks,
      elementKind: elementKind,
      chordIndex: matching == null || eventIndex == null
          ? null
          : _chordIndexForEvent(measure, eventIndex, matching),
    );
    final absoluteTicks = _measureStartTicks(part, measureIndex) + onsetTicks;
    return ResolvedAppScoreTarget(
      key: _keyForLocator(locator),
      partIndex: partIndex,
      measureIndex: measureIndex,
      eventIndex: eventIndex,
      staff: staff,
      onsetTicks: onsetTicks,
      lomseTimeUnits: (absoluteTicks * 64 / alphaTabQuarterTicks).round(),
    );
  }

  /// The UID is based on MusicXML part/measure identity, not a runtime index.
  /// Duplicate measure numbers are disambiguated by their occurrence only.
  static String measureUidFor({
    required MusicPart part,
    required int measureIndex,
  }) {
    if (measureIndex < 0 || measureIndex >= part.measures.length) {
      throw RangeError.index(measureIndex, part.measures);
    }
    final measure = part.measures[measureIndex];
    final occurrence = part.measures
        .take(measureIndex + 1)
        .where((candidate) => candidate.number == measure.number)
        .length;
    final canonical =
        'part=${part.id}|number=${measure.number}|occurrence=$occurrence';
    return 'measure:${_encodeStable(canonical)}';
  }

  AppScoreElementKey _keyForLocator(ScoreEventLocator locator) {
    final canonical = [
      locator.partId,
      locator.measureUid,
      locator.staff,
      locator.voice,
      locator.onsetTicks,
      locator.elementKind,
      locator.chordIndex ?? '',
    ].join('|');
    return AppScoreElementKey(
      id: 'score:${_encodeStable(canonical)}',
      locator: locator,
    );
  }

  ScoreEventLocator _locatorForEvent({
    required MusicPart part,
    required MusicMeasure measure,
    required MusicEvent event,
    required int? chordIndex,
  }) {
    final elementKind = switch (event) {
      final MusicNote note =>
        note.isChord
            ? 'chordMember'
            : note.isRest
            ? 'rest'
            : 'note',
      MusicDirection _ => 'direction',
      MusicHarmony _ => 'harmony',
    };
    final voice = event is MusicNote ? event.voice : '1';
    return ScoreEventLocator(
      partId: part.id,
      measureUid: measureUidFor(
        part: part,
        measureIndex: part.measures.indexOf(measure),
      ),
      staff: event.staff,
      voice: voice,
      onsetTicks: _toTicks(event.onset, measure.attributes.divisions),
      elementKind: elementKind,
      chordIndex: event is MusicNote && event.isChord ? chordIndex : null,
    );
  }

  MusicNote? _matchingNote(
    MusicMeasure measure, {
    required int staff,
    required int onsetTicks,
    required int? midi,
  }) {
    final onset =
        (onsetTicks * measure.attributes.divisions / alphaTabQuarterTicks)
            .round();
    for (final event in measure.events) {
      if (event is! MusicNote || event.staff != staff || event.onset != onset) {
        continue;
      }
      if (midi == null || event.pitch?.midi == midi) return event;
    }
    return null;
  }

  int? _chordIndexForEvent(
    MusicMeasure measure,
    int eventIndex,
    MusicEvent event,
  ) {
    if (event is! MusicNote || !event.isChord) return null;
    var index = 0;
    for (var i = 0; i < eventIndex; i++) {
      final previous = measure.events[i];
      if (previous is MusicNote &&
          previous.isChord &&
          previous.staff == event.staff &&
          previous.voice == event.voice &&
          previous.onset == event.onset) {
        index++;
      }
    }
    return index;
  }

  int _measureStartTicks(MusicPart part, int measureIndex) {
    var ticks = 0;
    for (var index = 0; index < measureIndex; index++) {
      final measure = part.measures[index];
      final duration = math.max(
        measure.durationDivisions,
        measureCapacity(measure.attributes),
      );
      ticks += (duration * alphaTabQuarterTicks / measure.attributes.divisions)
          .round();
    }
    return ticks;
  }

  MusicPart _partAt(int index) {
    if (index < 0 || index >= score.parts.length) {
      throw RangeError.index(index, score.parts);
    }
    return score.parts[index];
  }

  MusicMeasure _measureAt(MusicPart part, int index) {
    if (index < 0 || index >= part.measures.length) {
      throw RangeError.index(index, part.measures);
    }
    return part.measures[index];
  }

  static int _toTicks(int divisions, int measureDivisions) {
    return (divisions * alphaTabQuarterTicks / measureDivisions).round();
  }

  static String _encodeStable(String value) {
    return base64Url.encode(utf8.encode(value)).replaceAll('=', '');
  }
}

class ResolvedAppScoreTarget {
  const ResolvedAppScoreTarget({
    required this.key,
    required this.partIndex,
    required this.measureIndex,
    this.eventIndex,
    required this.staff,
    required this.onsetTicks,
    required this.lomseTimeUnits,
  });

  final AppScoreElementKey key;
  final int partIndex;
  final int measureIndex;
  final int? eventIndex;
  final int staff;
  final int onsetTicks;
  final int lomseTimeUnits;

  Map<String, Object?> get nativeCursor => {
    'instrument': partIndex,
    'staff': staff - 1,
    'time': lomseTimeUnits,
  };
}
