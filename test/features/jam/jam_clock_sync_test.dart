import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/core/session/jam_clock_sync.dart';
import 'package:page_a_diddle/core/session/jam_metronome_sync.dart';

void main() {
  group('jamClockOffsetSample', () {
    test('RTT가 0이면 offset은 memberRecvAt − conductorNow', () {
      final send = DateTime.utc(2026, 8, 21, 10, 0, 0);
      final conductorNow = DateTime.utc(2026, 8, 21, 10, 0, 0, 50);
      final recv = send;
      final offset = jamClockOffsetSample(
        memberSendAt: send,
        conductorNow: conductorNow,
        memberRecvAt: recv,
      );
      expect(offset, const Duration(milliseconds: -50));
    });

    test('RTT 20ms, conductor가 10ms 앞선 시계', () {
      final send = DateTime.utc(2026, 8, 21, 10, 0, 0);
      final conductorNow = DateTime.utc(2026, 8, 21, 10, 0, 0, 5);
      final recv = send.add(const Duration(milliseconds: 20));
      final offset = jamClockOffsetSample(
        memberSendAt: send,
        conductorNow: conductorNow,
        memberRecvAt: recv,
      );
      expect(offset.inMilliseconds, 5);
    });

    test('Member 시계가 빠르면 양수 offset', () {
      final send = DateTime.utc(2026, 8, 21, 10, 0, 0, 100);
      final conductorNow = DateTime.utc(2026, 8, 21, 10, 0, 0);
      final recv = DateTime.utc(2026, 8, 21, 10, 0, 0, 120);
      final offset = jamClockOffsetSample(
        memberSendAt: send,
        conductorNow: conductorNow,
        memberRecvAt: recv,
      );
      expect(offset.inMilliseconds, 110);
    });
  });

  group('jamClockOffsetFromSamples', () {
    test('최소 샘플 미만이면 null', () {
      expect(jamClockOffsetFromSamples([]), isNull);
      expect(
        jamClockOffsetFromSamples([
          const Duration(milliseconds: 5),
          const Duration(milliseconds: 10),
        ]),
        isNull,
      );
    });

    test('3개 이상이면 중앙값 반환', () {
      final offset = jamClockOffsetFromSamples([
        const Duration(milliseconds: 100),
        const Duration(milliseconds: 5),
        const Duration(milliseconds: 10),
      ]);
      expect(offset, const Duration(milliseconds: 10));
    });

    test('9개 샘플 중앙값', () {
      final offset = jamClockOffsetFromSamples([
        const Duration(milliseconds: 1),
        const Duration(milliseconds: 2),
        const Duration(milliseconds: 3),
        const Duration(milliseconds: 4),
        const Duration(milliseconds: 5),
        const Duration(milliseconds: 100),
        const Duration(milliseconds: 200),
        const Duration(milliseconds: 300),
        const Duration(milliseconds: 400),
      ]);
      expect(offset, const Duration(milliseconds: 5));
    });

    test('음수 offset도 정렬하고 짝수 샘플은 위쪽 중앙값을 쓴다', () {
      final offset = jamClockOffsetFromSamples([
        const Duration(milliseconds: -20),
        const Duration(milliseconds: -10),
        const Duration(milliseconds: 30),
        const Duration(milliseconds: 40),
      ]);
      expect(offset, const Duration(milliseconds: 30));
    });
  });

  group('jamClockAdjustedStartAt', () {
    test('offset만큼 startAt을 이동', () {
      final start = DateTime.utc(2026, 8, 21, 10, 0, 0);
      expect(
        jamClockAdjustedStartAt(start, const Duration(milliseconds: 50)),
        start.add(const Duration(milliseconds: 50)),
      );
    });
  });

  group('jamClockNextBarStep', () {
    test('4/4에서 step 0은 이미 마디 시작', () {
      expect(jamClockNextBarStep(0, beatsPerBar: 4), 0);
    });

    test('4/4에서 step 5는 다음 마디 step 8', () {
      expect(jamClockNextBarStep(5, beatsPerBar: 4), 8);
    });

    test('4/4에서 step 8은 마디 시작', () {
      expect(jamClockNextBarStep(8, beatsPerBar: 4), 8);
    });

    test('4/4 8분 음표(stepsPerBeat=2)에서 step 3은 step 8', () {
      expect(jamClockNextBarStep(3, beatsPerBar: 4, stepsPerBeat: 2), 8);
    });

    test('잘못된 마디 길이는 현재 step을 유지한다', () {
      expect(jamClockNextBarStep(7, beatsPerBar: 0), 7);
      expect(jamClockNextBarStep(7, beatsPerBar: 4, stepsPerBeat: 0), 7);
    });
  });

  group('jamClockDriftSteps', () {
    test('로컬이 앞서면 양수', () {
      expect(jamClockDriftSteps(expectedStep: 10, localStep: 12), 2);
    });

    test('로컬이 뒤쳐지면 음수', () {
      expect(jamClockDriftSteps(expectedStep: 10, localStep: 8), -2);
    });

    test('같으면 0', () {
      expect(jamClockDriftSteps(expectedStep: 10, localStep: 10), 0);
    });
  });

  group('jamClockNeedsCorrection', () {
    test('drift가 0이면 보정 불필요', () {
      expect(jamClockNeedsCorrection(driftSteps: 0, bpm: 120), isFalse);
    });

    test('120 BPM에서 1 step drift는 500ms로 보정 필요', () {
      expect(jamClockNeedsCorrection(driftSteps: 1, bpm: 120), isTrue);
    });

    test('240 BPM에서 1 step drift는 250ms로 보정 필요', () {
      expect(jamClockNeedsCorrection(driftSteps: 1, bpm: 240), isTrue);
    });

    test('임계값을 높이면 작은 drift는 무시', () {
      expect(
        jamClockNeedsCorrection(
          driftSteps: 1,
          bpm: 240,
          threshold: const Duration(seconds: 1),
        ),
        isFalse,
      );
    });

    test('임계값과 정확히 같으면 보정한다', () {
      expect(
        jamClockNeedsCorrection(
          driftSteps: 1,
          bpm: 240,
          threshold: const Duration(milliseconds: 250),
        ),
        isTrue,
      );
      expect(
        jamClockNeedsCorrection(
          driftSteps: -1,
          bpm: 240,
          threshold: const Duration(milliseconds: 251),
        ),
        isFalse,
      );
    });

    test('BPM이 범위를 벗어나도 0으로 나누지 않는다', () {
      expect(jamClockNeedsCorrection(driftSteps: 1, bpm: 0), isTrue);
      expect(jamClockNeedsCorrection(driftSteps: 0, bpm: 0), isFalse);
    });
  });

  group('jamClockCorrectedStartAt', () {
    test('offset 0이면 startAt 불변', () {
      final start = DateTime.utc(2026, 8, 21, 10, 0, 0);
      final corrected = jamClockCorrectedStartAt(
        startAt: start,
        offset: Duration.zero,
        nextBarStep: 8,
        bpm: 120,
      );
      expect(corrected, start);
    });

    test('보정 후 마디 경계의 로컬 시각이 유지됨', () {
      final start = DateTime.utc(2026, 8, 21, 10, 0, 0);
      const offset = Duration(milliseconds: 100);
      const bpm = 120;
      const nextBarStep = 8;
      final corrected = jamClockCorrectedStartAt(
        startAt: start,
        offset: offset,
        nextBarStep: nextBarStep,
        bpm: bpm,
      );
      final originalBoundary = jamClockBarBoundaryAt(
        startAt: start,
        nextBarStep: nextBarStep,
        bpm: bpm,
      );
      final correctedBoundary = jamClockBarBoundaryAt(
        startAt: corrected,
        nextBarStep: nextBarStep,
        bpm: bpm,
      );
      expect(correctedBoundary, originalBoundary);
    });

    test('보정 후 경계 직후 step이 offset만큼 이동', () {
      final start = DateTime.utc(2026, 8, 21, 10, 0, 0);
      const offset = Duration(milliseconds: 200);
      const bpm = 120;
      const nextBarStep = 4;
      final corrected = jamClockCorrectedStartAt(
        startAt: start,
        offset: offset,
        nextBarStep: nextBarStep,
        bpm: bpm,
      );
      final oneBeatAfter = jamClockBarBoundaryAt(
        startAt: start,
        nextBarStep: nextBarStep,
        bpm: bpm,
      ).add(const Duration(milliseconds: 250));
      final correctedStep = jamMetronomeStepIndex(
        startAt: corrected,
        now: oneBeatAfter,
        bpm: bpm,
      );
      expect(
        correctedStep,
        jamMetronomeStepIndex(
          startAt: start.add(offset),
          now: oneBeatAfter,
          bpm: bpm,
        ),
      );
    });
  });

  group('jamClockExpectedStep', () {
    test('offset 0이면 일반 step과 동일', () {
      final start = DateTime.utc(2026, 8, 21, 10, 0, 0);
      final now = start.add(const Duration(milliseconds: 1500));
      expect(
        jamClockExpectedStep(
          startAt: start,
          localNow: now,
          offset: Duration.zero,
          bpm: 120,
        ),
        jamMetronomeStepIndex(startAt: start, now: now, bpm: 120),
      );
    });

    test('offset이 양수면 같은 localNow에서 지난 step 수가 줄어든다', () {
      final start = DateTime.utc(2026, 8, 21, 10, 0, 0);
      final now = start.add(const Duration(milliseconds: 600));
      expect(
        jamClockExpectedStep(
          startAt: start,
          localNow: now,
          offset: const Duration(milliseconds: 200),
          bpm: 120,
        ),
        0,
      );
    });
  });
}
