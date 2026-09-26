import 'dart:math' as math;
import 'dart:ui';

import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_editor.dart';
import 'package:page_a_diddle/features/digital_score/domain/staff_note_input.dart';

const double nativePageWidth = 794;
const double nativeStaffLineGap = 8;
const double nativeSystemGap = 36;
const double nativeLeftMargin = 52;
const double nativeRightMargin = 16;
const double nativeTopMargin = 28;
const int nativeMeasuresPerSystem = 4;

class NativeMeasureBox {
  const NativeMeasureBox({
    required this.measureIndex,
    required this.rect,
    required this.trebleStaffTop,
    required this.bassStaffTop,
    required this.lineGap,
    required this.contentLeft,
    required this.contentWidth,
    this.staffTops = const <int, double>{},
    this.staffLineGaps = const <int, double>{},
    this.onsetAnchors = const <NativeOnsetAnchor>[],
  });

  final int measureIndex;
  final Rect rect;
  final double trebleStaffTop;
  final double bassStaffTop;
  final double lineGap;
  final double contentLeft;
  final double contentWidth;

  /// Rendered staff baselines keyed by MusicXML staff number.
  ///
  /// The legacy layout only knows about treble/bass positions. Verovio's
  /// layout can provide measured positions for every staff, so input can use
  /// the same geometry as the rendered SVG instead of guessing from a box.
  final Map<int, double> staffTops;
  final Map<int, double> staffLineGaps;
  final List<NativeOnsetAnchor> onsetAnchors;

  double staffTopFor(int staff) {
    return staffTops[staff] ?? (staff >= 2 ? bassStaffTop : trebleStaffTop);
  }

  double lineGapFor(int staff) {
    return staffLineGaps[staff] ?? lineGap;
  }

  double xForOnset(int onset, int capacity) {
    if (onsetAnchors.isEmpty || capacity <= 0) {
      return contentLeft +
          10 +
          (onset / math.max(1, capacity)) * (contentWidth - 20);
    }
    final anchors = onsetAnchors;
    if (anchors.length == 1) {
      final anchor = anchors.single;
      return anchor.x +
          ((onset - anchor.onset) / math.max(1, capacity)) *
              math.max(12, contentWidth - 20);
    }
    if (onset <= anchors.first.onset) return anchors.first.x;
    for (var index = 1; index < anchors.length; index++) {
      final previous = anchors[index - 1];
      final next = anchors[index];
      if (onset <= next.onset) {
        final span = math.max(1, next.onset - previous.onset);
        final ratio = (onset - previous.onset) / span;
        return previous.x + (next.x - previous.x) * ratio;
      }
    }
    final previous = anchors[anchors.length - 2];
    final last = anchors.last;
    final span = math.max(1, last.onset - previous.onset);
    return last.x + (onset - last.onset) / span * (last.x - previous.x);
  }

  int onsetForX(double x, int capacity) {
    if (onsetAnchors.isEmpty || capacity <= 0) {
      final ratio = ((x - contentLeft) / math.max(1, contentWidth)).clamp(
        0.0,
        0.999,
      );
      return (ratio * capacity).floor();
    }
    final anchors = onsetAnchors;
    if (anchors.length == 1) {
      final anchor = anchors.single;
      final width = math.max(12, contentWidth - 20);
      return (anchor.onset + (x - anchor.x) / width * capacity).floor().clamp(
        0,
        capacity,
      );
    }
    if (x <= anchors.first.x) return anchors.first.onset;
    for (var index = 1; index < anchors.length; index++) {
      final previous = anchors[index - 1];
      final next = anchors[index];
      if (x <= next.x) {
        final span = math.max(1.0, next.x - previous.x);
        final ratio = (x - previous.x) / span;
        return (previous.onset + (next.onset - previous.onset) * ratio)
            .floor()
            .clamp(0, capacity);
      }
    }
    final previous = anchors[anchors.length - 2];
    final last = anchors.last;
    final span = math.max(1.0, last.x - previous.x);
    return (last.onset + (x - last.x) / span * (last.onset - previous.onset))
        .floor()
        .clamp(0, capacity);
  }
}

class NativeOnsetAnchor {
  const NativeOnsetAnchor({required this.onset, required this.x});

  final int onset;
  final double x;
}

class NativeNotePlacement {
  const NativeNotePlacement({
    required this.partIndex,
    required this.measureIndex,
    required this.eventIndex,
    required this.staff,
    required this.onset,
    required this.midi,
    required this.center,
    required this.isRest,
  });

  final int partIndex;
  final int measureIndex;
  final int eventIndex;
  final int staff;
  final int onset;
  final int? midi;
  final Offset center;
  final bool isRest;
}

class NativeStaffHit {
  const NativeStaffHit({
    required this.partIndex,
    required this.measureIndex,
    required this.staff,
    required this.onsetTicks,
    required this.midi,
    required this.ghostCenter,
    required this.lineGap,
  });

  final int partIndex;
  final int measureIndex;
  final int staff;
  final int onsetTicks;
  final int midi;
  final Offset ghostCenter;
  final double lineGap;
}

class NativeScoreLayout {
  const NativeScoreLayout({
    required this.contentSize,
    required this.measures,
    required this.notes,
    required this.systemStarts,
  });

  final Size contentSize;
  final List<NativeMeasureBox> measures;
  final List<NativeNotePlacement> notes;
  final List<int> systemStarts;

  NativeMeasureBox? measureAt(Offset point) {
    for (final measure in measures) {
      if (measure.rect.inflate(8).contains(point)) return measure;
    }
    return null;
  }

  NativeNotePlacement? noteAt(Offset point, {double radius = 14}) {
    NativeNotePlacement? best;
    var bestDist = radius * radius;
    for (final note in notes) {
      final dx = note.center.dx - point.dx;
      final dy = note.center.dy - point.dy;
      final dist = dx * dx + dy * dy;
      if (dist <= bestDist) {
        bestDist = dist;
        best = note;
      }
    }
    return best;
  }

  NativeStaffHit? hitStaff(
    Offset point, {
    required String durationType,
    required MusicScore score,
  }) {
    final measureBox = measureAt(point);
    if (measureBox == null) return null;
    final partIndex = 0;
    if (partIndex >= score.parts.length) return null;
    final part = score.parts[partIndex];
    if (measureBox.measureIndex >= part.measures.length) return null;
    final measure = part.measures[measureBox.measureIndex];
    final staff = measure.attributes.staves <= 1
        ? 1
        : _staffForY(point.dy, measureBox);
    final staffTop = measureBox.staffTopFor(staff);
    final lineGap = measureBox.lineGapFor(staff);
    final midi = midiAtStaffY(
      point.dy,
      staffTop: staffTop,
      lineGap: lineGap,
      bass: staff >= 2,
    );
    final capacity = measureCapacity(measure.attributes);
    final duration = durationForType(measure.attributes, durationType);
    final rawOnset = measureBox.onsetForX(point.dx, capacity);
    final onset = clampOnsetForDuration(
      attributes: measure.attributes,
      onset: (rawOnset / math.max(1, duration)).floor() * duration,
      duration: duration,
    );
    final ghost = Offset(
      measureBox.xForOnset(onset, capacity),
      staffYForMidi(
        midi,
        staffTop: staffTop,
        lineGap: lineGap,
        bass: staff >= 2,
      ),
    );
    return NativeStaffHit(
      partIndex: partIndex,
      measureIndex: measureBox.measureIndex,
      staff: staff,
      onsetTicks: (onset * alphaTabQuarterTicks / measure.attributes.divisions)
          .round(),
      midi: midi,
      ghostCenter: ghost,
      lineGap: lineGap,
    );
  }
}

NativeScoreLayout layoutNativeScore(
  MusicScore score, {
  double pageWidth = nativePageWidth,
  int measuresPerSystem = nativeMeasuresPerSystem,
}) {
  final part = score.parts.isEmpty ? null : score.parts.first;
  final measureCount = part?.measures.length ?? 0;
  final systemCount = math.max(1, (measureCount / measuresPerSystem).ceil());
  const lineGap = nativeStaffLineGap;
  const systemHeight = 18 + 4 * lineGap + 28 + 4 * lineGap + nativeSystemGap;
  final measures = <NativeMeasureBox>[];
  final notes = <NativeNotePlacement>[];
  final systemStarts = <int>[];

  for (var system = 0; system < systemCount; system++) {
    final start = system * measuresPerSystem;
    if (start >= measureCount && measureCount > 0) break;
    systemStarts.add(start);
    final count = measureCount == 0
        ? 0
        : math.min(measuresPerSystem, measureCount - start);
    final top = nativeTopMargin + system * systemHeight;
    final trebleTop = top + 18;
    final bassTop = trebleTop + 4 * lineGap + 28;
    final usable = pageWidth - nativeLeftMargin - nativeRightMargin;
    final measureWidth = count == 0 ? usable : usable / count;

    for (var i = 0; i < count; i++) {
      final measureIndex = start + i;
      final left = nativeLeftMargin + i * measureWidth;
      final box = NativeMeasureBox(
        measureIndex: measureIndex,
        rect: Rect.fromLTWH(
          left,
          trebleTop - 12,
          measureWidth,
          (bassTop + 4 * lineGap) - (trebleTop - 12),
        ),
        trebleStaffTop: trebleTop,
        bassStaffTop: bassTop,
        lineGap: lineGap,
        contentLeft: left + 8,
        contentWidth: measureWidth - 16,
      );
      measures.add(box);

      final musicMeasure = part!.measures[measureIndex];
      final capacity = math.max(1, measureCapacity(musicMeasure.attributes));
      for (
        var eventIndex = 0;
        eventIndex < musicMeasure.events.length;
        eventIndex++
      ) {
        final event = musicMeasure.events[eventIndex];
        if (event is! MusicNote) continue;
        final staff = event.staff.clamp(1, 2);
        final staffTop = staff >= 2 ? bassTop : trebleTop;
        final x =
            box.contentLeft +
            10 +
            (event.onset / capacity) * (box.contentWidth - 20);
        final y = event.isRest
            ? staffTop - 2 * lineGap
            : staffYForMidi(
                midiForPitch(event.pitch!),
                staffTop: staffTop,
                lineGap: lineGap,
                bass: staff >= 2,
              );
        notes.add(
          NativeNotePlacement(
            partIndex: 0,
            measureIndex: measureIndex,
            eventIndex: eventIndex,
            staff: staff,
            onset: event.onset,
            midi: event.isRest ? null : midiForPitch(event.pitch!),
            center: Offset(x, y),
            isRest: event.isRest,
          ),
        );
      }
    }
  }

  final height = math.max(systemCount * systemHeight + nativeTopMargin, 200.0);
  return NativeScoreLayout(
    contentSize: Size(pageWidth, height),
    measures: measures,
    notes: notes,
    systemStarts: systemStarts,
  );
}

int _staffForY(double y, NativeMeasureBox box) {
  final trebleTop = box.staffTopFor(1);
  final bassTop = box.staffTopFor(2);
  // Verovio's fitted anchors represent the lower line of the upper staff and
  // the upper line of the lower staff (the anchor differs by clef).  The
  // midpoint between those two anchors is the actual gap between staves.
  // Adding four treble spaces here classified part of the bass staff as
  // treble after zooming and made low-clef input feel vertically displaced.
  final mid = (trebleTop + bassTop) / 2;
  return y >= mid ? 2 : 1;
}

double staffYForMidi(
  int midi, {
  required double staffTop,
  required double lineGap,
  required bool bass,
}) {
  final pitch = pitchFromMidi(midi);
  final steps = (pitch.octave - 4) * 7 + pitch.step.index;
  final reference = bass ? -2 : 2;
  return staffTop - ((steps - reference) * (lineGap / 2));
}

int midiAtStaffY(
  double y, {
  required double staffTop,
  required double lineGap,
  required bool bass,
}) {
  final half = lineGap / 2;
  final reference = bass ? -2 : 2;
  final steps = (reference + ((staffTop - y) / half)).round();
  final octave = 4 + (steps / 7).floor();
  final rem = ((steps % 7) + 7) % 7;
  final step = PitchStep.values[rem];
  return MusicPitch(step: step, octave: octave).midi.clamp(21, 108);
}

/// Treble [staffTop] is E4 (bottom line). Bass [staffTop] is A3 (top line).
class GrandStaffFrame {
  const GrandStaffFrame({
    required this.trebleStaffTop,
    required this.bassStaffTop,
    required this.lineGap,
  });

  final double trebleStaffTop;
  final double bassStaffTop;
  final double lineGap;
}

/// Guess staff lines from a Verovio measure box when no staff hit exists.
///
/// The measure rect's 19% line is the visual top of the treble staff (F5).
/// Pitch mapping uses the bottom line (E4), four spaces below that.
GrandStaffFrame fallbackGrandStaffFrame(Rect measure, {int staves = 2}) {
  final height = math.max(36.0, measure.height);
  final lineGap = math.max(3.0, height * (staves > 1 ? 0.045 : 0.09));
  final trebleTopLine = measure.top + height * (staves > 1 ? 0.19 : 0.28);
  final trebleStaffTop = trebleTopLine + 4 * lineGap;
  final bassStaffTop = staves > 1
      ? measure.top + height * 0.65
      : trebleStaffTop;
  return GrandStaffFrame(
    trebleStaffTop: trebleStaffTop,
    bassStaffTop: bassStaffTop,
    lineGap: lineGap,
  );
}

/// Map Verovio `staff` boxes onto the pitch grid.
///
/// Treble staff hits cover F5–E4, so the bottom edge is E4. Bass staff hits
/// cover A3–G2, so the top edge is A3.
GrandStaffFrame grandStaffFrameFromStaffRects(
  List<Rect> staffRects,
  Rect measure, {
  int staves = 2,
}) {
  if (staffRects.isEmpty) {
    return fallbackGrandStaffFrame(measure, staves: staves);
  }
  final sorted = [...staffRects]..sort((a, b) => a.top.compareTo(b.top));
  final treble = sorted.first;
  final lineGap = math.max(3.0, treble.height / 4);
  final trebleStaffTop = treble.bottom;
  final bassStaffTop = sorted.length > 1
      ? sorted[1].top
      : fallbackGrandStaffFrame(measure, staves: staves).bassStaffTop;
  return GrandStaffFrame(
    trebleStaffTop: trebleStaffTop,
    bassStaffTop: bassStaffTop,
    lineGap: lineGap,
  );
}

double contentLeftAfterClefs({
  required Rect measure,
  required List<Rect> clefs,
  int measureIndex = 0,
}) {
  var left = measure.left + math.min(12, measure.width * 0.08);
  for (final clef in clefs) {
    if (clef.right + 6 > left) left = clef.right + 6;
  }
  if (clefs.isEmpty && measureIndex == 0) {
    left = math.max(left, measure.left + measure.width * 0.32);
  }
  final right = measure.left + measure.width - 8;
  if (left > right - 16) {
    left = measure.left + measure.width * 0.32;
  }
  return left;
}

List<NativeOnsetAnchor> buildOnsetAnchors({
  required double contentLeft,
  required double contentWidth,
  required int capacity,
  required Map<int, List<double>> noteXs,
}) {
  final merged = <int, List<double>>{
    for (final entry in noteXs.entries) entry.key: [...entry.value],
  };
  if (!merged.containsKey(0)) {
    merged[0] = [contentLeft];
  }
  if (!merged.containsKey(capacity)) {
    merged[capacity] = [contentLeft + contentWidth];
  }
  return [
    for (final entry in merged.entries)
      NativeOnsetAnchor(
        onset: entry.key,
        x: entry.value.reduce((a, b) => a + b) / entry.value.length,
      ),
  ]..sort((a, b) => a.onset.compareTo(b.onset));
}
