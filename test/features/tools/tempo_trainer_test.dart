import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/tools/domain/tempo_trainer.dart';

void main() {
  test('반복 수만큼 완료하면 BPM을 올리고 목표 BPM에서 끝낸다', () {
    final trainer = TempoTrainer(
      startBpm: 80,
      targetBpm: 90,
      increment: 5,
      repetitions: 2,
    )..start();

    expect(trainer.currentBpm, 80);
    expect(trainer.completeRepetition(), isFalse);
    expect(trainer.currentBpm, 80);
    expect(trainer.completedRepetitions, 1);

    expect(trainer.completeRepetition(), isFalse);
    expect(trainer.currentBpm, 85);
    expect(trainer.completedRepetitions, 0);

    trainer.completeRepetition();
    trainer.completeRepetition();
    expect(trainer.completeRepetition(), isFalse);
    expect(trainer.completeRepetition(), isTrue);
    expect(trainer.currentBpm, 90);
    expect(trainer.isRunning, isFalse);
    expect(trainer.isComplete, isTrue);
  });

  test('목표 BPM과 입력 범위를 검증한다', () {
    expect(
      () => TempoTrainer(startBpm: 140, targetBpm: 80),
      throwsArgumentError,
    );
    expect(
      () => TempoTrainer(startBpm: 80, targetBpm: 140, repetitions: 0),
      throwsArgumentError,
    );
  });
}
