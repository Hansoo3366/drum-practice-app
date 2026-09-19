import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/core/session/jam_metronome_sync.dart';
import 'package:page_a_diddle/features/tools/domain/metronome_sequence.dart';

void main() {
  test('startAt 기준으로 step 인덱스를 계산한다', () {
    final start = DateTime.utc(2026, 8, 20, 7, 0, 0);
    expect(
      jamMetronomeStepIndex(
        startAt: start,
        now: start.subtract(const Duration(milliseconds: 1)),
        bpm: 120,
      ),
      -1,
    );
    expect(jamMetronomeStepIndex(startAt: start, now: start, bpm: 120), 0);
    expect(
      jamMetronomeStepIndex(
        startAt: start,
        now: start.add(const Duration(milliseconds: 499)),
        bpm: 120,
      ),
      0,
    );
    expect(
      jamMetronomeStepIndex(
        startAt: start,
        now: start.add(const Duration(milliseconds: 500)),
        bpm: 120,
      ),
      1,
    );
    expect(
      jamMetronomeStepIndex(
        startAt: start,
        now: start.add(const Duration(milliseconds: 1500)),
        bpm: 120,
      ),
      3,
    );
  });

  test('연음 단위와 잘못된 BPM도 절대 타임라인에서 안전하게 처리한다', () {
    final start = DateTime.utc(2026, 8, 20, 7, 0, 0);
    expect(
      jamMetronomeStepIndex(
        startAt: start,
        now: start.add(const Duration(milliseconds: 125)),
        bpm: 120,
        stepsPerBeat: 4,
      ),
      1,
    );
    expect(
      jamMetronomeStepIndex(
        startAt: start,
        now: start.add(const Duration(milliseconds: 1500)),
        bpm: 0,
      ),
      1,
    );
    expect(
      jamMetronomeStepIndex(
        startAt: start,
        now: start.add(const Duration(milliseconds: 1500)),
        bpm: -10,
      ),
      1,
    );
  });

  test('다음 step까지 대기를 계산한다', () {
    final start = DateTime.utc(2026, 8, 20, 7, 0, 0);
    expect(
      jamMetronomeDelayUntilNext(
        startAt: start,
        now: start.subtract(const Duration(milliseconds: 200)),
        bpm: 120,
      ),
      const Duration(milliseconds: 200),
    );
    expect(
      jamMetronomeDelayUntilNext(
        startAt: start,
        now: start.add(const Duration(milliseconds: 100)),
        bpm: 120,
      ),
      const Duration(milliseconds: 400),
    );
    expect(
      jamMetronomeDelayUntilNext(
        startAt: start,
        now: start,
        bpm: 120,
        stepsPerBeat: 2,
      ),
      const Duration(milliseconds: 250),
    );
    expect(
      jamMetronomeDelayUntilNext(
        startAt: start,
        now: start.add(const Duration(seconds: 3)),
        bpm: 120,
      ),
      const Duration(milliseconds: 500),
    );
  });

  test('절대 step으로 Count-In 박을 만든다', () {
    final sequence = MetronomeSequence()
      ..configure(
        accentPattern: [
          MetronomeAccentLevel.strong,
          MetronomeAccentLevel.normal,
          MetronomeAccentLevel.normal,
          MetronomeAccentLevel.normal,
        ],
      );

    final first = sequence.beatAt(0, countInBars: 1);
    expect(first.number, 1);
    expect(first.isCountIn, isTrue);
    expect(first.isAccent, isTrue);

    final afterCountIn = sequence.beatAt(4, countInBars: 1);
    expect(afterCountIn.number, 1);
    expect(afterCountIn.isCountIn, isFalse);
    expect(afterCountIn.isAccent, isTrue);

    final twoBar = sequence.beatAt(7, countInBars: 2);
    expect(twoBar.number, 4);
    expect(twoBar.isCountIn, isTrue);
  });
}
