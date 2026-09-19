import 'package:page_a_diddle/features/tools/domain/metronome_sequence.dart';

/// startAt 기준 절대 박자 타임라인. 네트워크 tick 없이 로컬로 박자를 맞춘다.
int jamMetronomeStepIndex({
  required DateTime startAt,
  required DateTime now,
  required int bpm,
  int stepsPerBeat = 1,
}) {
  final elapsed = now.toUtc().difference(startAt.toUtc());
  if (elapsed.isNegative) {
    return -1;
  }
  final intervalUs = MetronomeSequence.intervalFor(
    bpm,
    stepsPerBeat: stepsPerBeat,
  ).inMicroseconds;
  if (intervalUs <= 0) {
    return 0;
  }
  return elapsed.inMicroseconds ~/ intervalUs;
}

Duration jamMetronomeDelayUntilNext({
  required DateTime startAt,
  required DateTime now,
  required int bpm,
  int stepsPerBeat = 1,
}) {
  final intervalUs = MetronomeSequence.intervalFor(
    bpm,
    stepsPerBeat: stepsPerBeat,
  ).inMicroseconds;
  if (intervalUs <= 0) {
    return Duration.zero;
  }
  final elapsedUs = now.toUtc().difference(startAt.toUtc()).inMicroseconds;
  if (elapsedUs < 0) {
    final untilStart = startAt.toUtc().difference(now.toUtc());
    return untilStart.isNegative ? Duration.zero : untilStart;
  }
  final nextIndex = elapsedUs ~/ intervalUs + 1;
  final nextAt = startAt.toUtc().add(
    Duration(microseconds: nextIndex * intervalUs),
  );
  final delay = nextAt.difference(now.toUtc());
  return delay.isNegative ? Duration.zero : delay;
}
