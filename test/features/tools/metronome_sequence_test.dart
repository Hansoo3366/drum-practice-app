import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/tools/domain/metronome_sequence.dart';
import 'package:page_a_diddle/l10n/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('ko'));
  test('120 BPM 간격과 4박 Count-In 뒤의 첫 마디를 만든다', () {
    final sequence = MetronomeSequence()..start(countIn: true);

    expect(
      MetronomeSequence.intervalFor(120),
      const Duration(milliseconds: 500),
    );
    for (var beat = 1; beat <= 4; beat++) {
      final current = sequence.next();
      expect(current.number, beat);
      expect(current.isCountIn, isTrue);
    }

    final firstBeat = sequence.next();
    expect(firstBeat.number, 1);
    expect(firstBeat.isCountIn, isFalse);
    expect(firstBeat.isAccent, isTrue);
  });

  test('BPM과 연음 단위의 경계를 안전하게 제한한다', () {
    expect(
      MetronomeSequence.intervalFor(0),
      const Duration(milliseconds: 1500),
    );
    expect(
      MetronomeSequence.intervalFor(999),
      const Duration(milliseconds: 250),
    );
    expect(
      MetronomeSequence.intervalFor(240, stepsPerBeat: 0),
      const Duration(milliseconds: 250),
    );
    expect(
      MetronomeSequence.intervalFor(240, stepsPerBeat: 99),
      const Duration(microseconds: 41666),
    );
  });

  test('생성자의 잘못된 마디와 연음 단위를 보정하고 악센트를 초기화한다', () {
    final sequence = MetronomeSequence(beatsPerBar: 99, stepsPerBeat: 0)
      ..start();

    expect(sequence.beatsPerBar, 12);
    expect(sequence.stepsPerBeat, 1);
    expect(sequence.next().accentLevel, MetronomeAccentLevel.strong);
    for (var beat = 2; beat <= 12; beat++) {
      expect(sequence.next().number, beat);
    }
    expect(sequence.next().number, 1);
  });

  test('2마디 Count-In 뒤의 첫 마디를 만든다', () {
    final sequence = MetronomeSequence()..start(countInBars: 2);

    for (var beat = 0; beat < 8; beat++) {
      expect(sequence.next().isCountIn, isTrue);
    }
    expect(sequence.next().isCountIn, isFalse);
  });

  test('Count-In 선택지는 0·1·2·4마디의 모든 경우를 처리한다', () {
    for (final bars in metronomeCountInBarOptions) {
      final sequence = MetronomeSequence()..start(countInBars: bars);
      for (var step = 0; step < bars * 4; step++) {
        expect(sequence.next().isCountIn, isTrue, reason: 'bars=$bars');
      }
      expect(sequence.next().isCountIn, isFalse, reason: 'bars=$bars');
    }
  });

  test('Count-In 마디 수를 정규화한다', () {
    expect(normalizeMetronomeCountInBars(null), 0);
    expect(normalizeMetronomeCountInBars(3), 2);
    expect(normalizeMetronomeCountInBars(5), 4);
    expect(metronomeCountInLabel(0, l10n), '없음');
    expect(metronomeCountInLabel(2, l10n), '2마디');
    expect(normalizeMetronomeCountInBars(-10), 0);
    expect(normalizeMetronomeCountInBars(1), 1);
    expect(normalizeMetronomeCountInBars(2), 2);
    expect(normalizeMetronomeCountInBars(4), 4);
  });

  test('8분음표 단위와 선택 악센트를 만든다', () {
    final sequence = MetronomeSequence()
      ..configure(
        stepsPerBeat: MetronomeSubdivision.eighth.stepsPerBeat,
        accentPattern: [
          MetronomeAccentLevel.normal,
          MetronomeAccentLevel.strong,
        ],
      )
      ..start(countIn: false);

    expect(sequence.next().isSubdivision, isFalse);
    expect(sequence.next().isSubdivision, isTrue);
    final beat2 = sequence.next();
    expect(beat2.number, 2);
    expect(beat2.isAccent, isTrue);
    expect(beat2.accentLevel, MetronomeAccentLevel.strong);
    expect(sequence.next().isAccent, isFalse);
  });

  test('각 연음 단위는 박 시작과 하위 박을 정확히 구분한다', () {
    for (final subdivision in MetronomeSubdivision.values) {
      final sequence = MetronomeSequence()
        ..configure(stepsPerBeat: subdivision.stepsPerBeat)
        ..start();
      for (var step = 0; step < subdivision.stepsPerBeat; step++) {
        final beat = sequence.next();
        expect(beat.number, 1, reason: subdivision.name);
        expect(
          beat.isSubdivision,
          step != 0,
          reason: '${subdivision.name} step=$step',
        );
      }
      expect(sequence.next().number, 2, reason: subdivision.name);
    }
  });

  test('절대 step 조회는 Count-In·마디 순환·음수 입력을 안전하게 처리한다', () {
    final sequence = MetronomeSequence()
      ..configure(
        beatsPerBar: 3,
        stepsPerBeat: 2,
        accentPattern: const [
          MetronomeAccentLevel.strong,
          MetronomeAccentLevel.mute,
          MetronomeAccentLevel.normal,
        ],
      );

    final beforeStart = sequence.beatAt(-1, countInBars: 0);
    expect(beforeStart.number, 1);
    expect(beforeStart.isCountIn, isFalse);
    expect(sequence.beatAt(0, countInBars: 1).isCountIn, isTrue);
    expect(sequence.beatAt(5, countInBars: 1).isCountIn, isTrue);
    expect(sequence.beatAt(6, countInBars: 1).isCountIn, isFalse);
    expect(sequence.beatAt(7, countInBars: 1).number, 1);
    expect(sequence.beatAt(11, countInBars: 1).number, 3);
    expect(sequence.beatAt(12, countInBars: 1).number, 1);
    expect(
      sequence.beatAt(6, countInBars: 1).accentLevel,
      MetronomeAccentLevel.strong,
    );
    expect(
      sequence.beatAt(8, countInBars: 1).accentLevel,
      MetronomeAccentLevel.mute,
    );
  });

  test('start는 진행 중인 Count-In과 박을 처음부터 다시 시작한다', () {
    final sequence = MetronomeSequence()..start(countInBars: 2);
    expect(sequence.next().isCountIn, isTrue);
    sequence.start(countInBars: 0);
    expect(sequence.next().isCountIn, isFalse);
    expect(sequence.next().number, 2);
  });

  test('박자표 변경에 맞춰 마디를 순환한다', () {
    final sequence = MetronomeSequence()
      ..configure(
        beatsPerBar: 3,
        accentPattern: [
          MetronomeAccentLevel.normal,
          MetronomeAccentLevel.normal,
          MetronomeAccentLevel.strong,
        ],
      )
      ..start(countIn: false);

    expect(sequence.next().number, 1);
    expect(sequence.next().number, 2);
    expect(sequence.next().isAccent, isTrue);
    expect(sequence.next().number, 1);
  });

  test('악센트 순환은 강박·기본·뮤트 순서다', () {
    expect(MetronomeAccentLevel.strong.next, MetronomeAccentLevel.normal);
    expect(MetronomeAccentLevel.normal.next, MetronomeAccentLevel.mute);
    expect(MetronomeAccentLevel.mute.next, MetronomeAccentLevel.strong);
  });

  test('박자표는 값과 hashCode가 일치할 때 같은 값이다', () {
    const first = MetronomeMeter(7, 8);
    const second = MetronomeMeter(7, 8);
    expect(first, second);
    expect(first.hashCode, second.hashCode);
    expect(first, isNot(const MetronomeMeter(7, 4)));
    expect(first.label, '7/8');
  });

  test('요청한 박자표와 연음 단위 목록을 제공한다', () {
    expect(metronomeMeters.map((meter) => meter.label), [
      '1/4',
      '2/4',
      '3/4',
      '4/4',
      '5/4',
      '6/4',
      '3/8',
      '5/8',
      '6/8',
      '7/8',
      '9/8',
      '12/8',
    ]);
    expect(
      MetronomeSubdivision.values.map(
        (subdivision) => subdivision.stepsPerBeat,
      ),
      [1, 2, 4, 3, 6],
    );
  });

  test('지원하는 모든 박자표에서 한 마디를 끝까지 순환한다', () {
    for (final meter in metronomeMeters) {
      final sequence = MetronomeSequence()
        ..configure(beatsPerBar: meter.numerator)
        ..start();
      for (var beat = 1; beat <= meter.numerator; beat++) {
        expect(sequence.next().number, beat, reason: meter.label);
      }
      expect(sequence.next().number, 1, reason: meter.label);
    }
  });
}
