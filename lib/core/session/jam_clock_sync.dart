import 'package:page_a_diddle/core/session/jam_metronome_sync.dart';
import 'package:page_a_diddle/features/tools/domain/metronome_sequence.dart';

/// Clock offset 보정에 쓰는 상수.
///
/// - [jamClockDriftThreshold]: 이 값 이상 drift가 감지되면 보정을 시도한다.
/// - [jamClockMinSamples]: offset 추정에 필요한 최소 샘플 수.
/// - [jamClockMaxSamples]: offset 추정 윈도우 최대 크기.
const jamClockDriftThreshold = Duration(milliseconds: 50);
const jamClockMinSamples = 3;
const jamClockMaxSamples = 9;

/// NTP 스타일 단일 round-trip으로 Conductor 시각을 추정한다.
///
/// Member가 [memberSendAt]에 ping을 보내고, Conductor가 [conductorNow]에
/// pong을 반환하면 Member는 [memberRecvAt]에 받는다.
/// 편도 지연 ≈ (RTT) / 2 라고 가정하면 Conductor의 pong 시각을
/// Member 로컬 시각으로 환산할 수 있다.
///
/// 반환값: Member 로컬 시계 − Conductor 로컬 시계.
/// 양수면 Member 시계가 Conductor보다 앞서 있음.
Duration jamClockOffsetSample({
  required DateTime memberSendAt,
  required DateTime conductorNow,
  required DateTime memberRecvAt,
}) {
  final rtt = memberRecvAt.difference(memberSendAt);
  final halfRtt = Duration(microseconds: rtt.inMicroseconds ~/ 2);
  final conductorEstimatedAtRecv = conductorNow.add(halfRtt);
  return memberRecvAt.difference(conductorEstimatedAtRecv);
}

/// 여러 offset 샘플에서 중앙값을 계산해 안정적 offset을 반환한다.
///
/// [jamClockMinSamples] 미만이면 `null`을 반환한다.
Duration? jamClockOffsetFromSamples(List<Duration> samples) {
  if (samples.length < jamClockMinSamples) {
    return null;
  }
  final sorted = [...samples]..sort((a, b) => a.compareTo(b));
  return sorted[sorted.length ~/ 2];
}

/// offset을 적용한 startAt을 반환한다.
///
/// [offset] = Member 로컬 시계 − Conductor 로컬 시계.
/// Member의 startAt을 [offset]만큼 밀어서 Conductor 타임라인에 맞춘다.
DateTime jamClockAdjustedStartAt(DateTime startAt, Duration offset) {
  return startAt.add(offset);
}

/// 현재 step에서 다음 마디 첫 박(step)을 반환한다.
///
/// [beatsPerBar] × [stepsPerBeat] = stepsPerBar.
/// 현재 step이 이미 마디 첫 박이면 그 step을 반환한다.
int jamClockNextBarStep(
  int currentStep, {
  required int beatsPerBar,
  int stepsPerBeat = 1,
}) {
  final stepsPerBar = beatsPerBar * stepsPerBeat;
  if (stepsPerBar <= 0) {
    return currentStep;
  }
  final barRemainder = currentStep % stepsPerBar;
  if (barRemainder == 0) {
    return currentStep;
  }
  return currentStep + (stepsPerBar - barRemainder);
}

/// 기대 step과 로컬 step의 drift를 반환한다.
///
/// 양수면 로컬이 앞서 있음(로컬 시계가 빠름).
/// 음수면 로컬이 뒤쳐짐(로컬 시계가 느림).
int jamClockDriftSteps({required int expectedStep, required int localStep}) {
  return localStep - expectedStep;
}

/// step 차이가 [jamClockDriftThreshold]를 초과하는지 확인한다.
bool jamClockNeedsCorrection({
  required int driftSteps,
  required int bpm,
  int stepsPerBeat = 1,
  Duration threshold = jamClockDriftThreshold,
}) {
  if (driftSteps == 0) {
    return false;
  }
  final intervalUs = MetronomeSequence.intervalFor(
    bpm,
    stepsPerBeat: stepsPerBeat,
  ).inMicroseconds;
  if (intervalUs <= 0) {
    return false;
  }
  final driftUs = driftSteps.abs() * intervalUs;
  return driftUs >= threshold.inMicroseconds;
}

/// 다음 마디 경계의 로컬 시각을 반환한다.
///
/// [startAt] 기준으로 [nextBarStep]이 발생하는 시각.
DateTime jamClockBarBoundaryAt({
  required DateTime startAt,
  required int nextBarStep,
  required int bpm,
  int stepsPerBeat = 1,
}) {
  final intervalUs = MetronomeSequence.intervalFor(
    bpm,
    stepsPerBeat: stepsPerBeat,
  ).inMicroseconds;
  return startAt.toUtc().add(Duration(microseconds: nextBarStep * intervalUs));
}

/// offset 보정 후 다음 마디 경계에서 사용할 새 startAt을 계산한다.
///
/// 현재 [startAt]을 [offset]만큼 보정하되, [nextBarStep]이 새 타임라인에서도
/// 같은 로컬 시각에 발생하도록 조정한다.
///
/// 구체적으로: `newStartAt = startAt + offset`이면 nextBarStep의 로컬 시각이
/// `offset`만큼 이동하므로, 그만큼을 다시 빼서 경계를 맞춘다.
/// 결과적으로 새 startAt에서 [nextBarStep]은 기존과 같은 로컬 시각에 도달하지만,
/// 그 이후 step은 Conductor 타임라인에 맞춰진다.
DateTime jamClockCorrectedStartAt({
  required DateTime startAt,
  required Duration offset,
  required int nextBarStep,
  required int bpm,
  int stepsPerBeat = 1,
}) {
  final intervalUs = MetronomeSequence.intervalFor(
    bpm,
    stepsPerBeat: stepsPerBeat,
  ).inMicroseconds;
  if (intervalUs <= 0) {
    return startAt;
  }
  final adjusted = jamClockAdjustedStartAt(startAt, offset);
  final boundaryShift = Duration(microseconds: nextBarStep * intervalUs);
  final oldBoundary = startAt.toUtc().add(boundaryShift);
  final newBoundary = adjusted.toUtc().add(boundaryShift);
  final correction = oldBoundary.difference(newBoundary);
  return adjusted.add(correction);
}

/// Conductor의 예상 step을 offset 기반으로 계산한다.
///
/// Member가 [localNow]에 측정한 로컬 step과, Conductor의 [expectedStep]을
/// 비교해 drift를 감지할 때 사용한다.
int jamClockExpectedStep({
  required DateTime startAt,
  required DateTime localNow,
  required Duration offset,
  required int bpm,
  int stepsPerBeat = 1,
}) {
  final adjusted = jamClockAdjustedStartAt(startAt, offset);
  return jamMetronomeStepIndex(
    startAt: adjusted,
    now: localNow,
    bpm: bpm,
    stepsPerBeat: stepsPerBeat,
  );
}
