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
  });

  final int measureIndex;
  final Rect rect;
  final double trebleStaffTop;
  final double bassStaffTop;
  final double lineGap;
  final double contentLeft;
  final double contentWidth;
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
  });

  final int partIndex;
  final int measureIndex;
  final int staff;
  final int onsetTicks;
  final int midi;
  final Offset ghostCenter;
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
    final staff = _staffForY(point.dy, measureBox);
    final staffTop = staff >= 2
        ? measureBox.bassStaffTop
        : measureBox.trebleStaffTop;
    final midi = midiAtStaffY(
      point.dy,
      staffTop: staffTop,
      lineGap: measureBox.lineGap,
      bass: staff >= 2,
    );
    final capacity = measureCapacity(measure.attributes);
    final duration = durationForType(measure.attributes, durationType);
    final ratio = measureBox.contentWidth <= 0
        ? 0.0
        : ((point.dx - measureBox.contentLeft) / measureBox.contentWidth).clamp(
            0.0,
            0.999,
          );
    final rawOnset = (ratio * capacity).round();
    final onset = clampOnsetForDuration(
      attributes: measure.attributes,
      onset: (rawOnset / math.max(1, duration)).round() * duration,
      duration: duration,
    );
    final ghost = Offset(
      measureBox.contentLeft +
          10 +
          (onset / math.max(1, capacity)) * (measureBox.contentWidth - 20),
      staffYForMidi(
        midi,
        staffTop: staffTop,
        lineGap: measureBox.lineGap,
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
      for (var eventIndex = 0; eventIndex < musicMeasure.events.length; eventIndex++) {
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

  final height = math.max(
    systemCount * systemHeight + nativeTopMargin,
    200.0,
  );
  return NativeScoreLayout(
    contentSize: Size(pageWidth, height),
    measures: measures,
    notes: notes,
    systemStarts: systemStarts,
  );
}

int _staffForY(double y, NativeMeasureBox box) {
  final mid = (box.trebleStaffTop + 4 * box.lineGap + box.bassStaffTop) / 2;
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
  return staffTop - ((reference - steps) * (lineGap / 2));
}

int midiAtStaffY(
  double y, {
  required double staffTop,
  required double lineGap,
  required bool bass,
}) {
  final half = lineGap / 2;
  final reference = bass ? -2 : 2;
  final steps = (reference - ((staffTop - y) / half)).round();
  final octave = 4 + (steps / 7).floor();
  final rem = ((steps % 7) + 7) % 7;
  final step = PitchStep.values[rem];
  return MusicPitch(step: step, octave: octave).midi.clamp(21, 108);
}
