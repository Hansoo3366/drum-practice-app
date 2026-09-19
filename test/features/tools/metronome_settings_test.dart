import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/tools/data/metronome_settings.dart';
import 'package:page_a_diddle/features/tools/domain/metronome_sequence.dart';
import 'package:page_a_diddle/features/tools/presentation/metronome_settings_sheet.dart';

void main() {
  test('MetronomeSettings round-trips through JSON', () {
    const original = MetronomeSettings(
      bpm: 144,
      meter: MetronomeMeter(7, 8),
      subdivision: MetronomeSubdivision.triplet,
      accents: [
        MetronomeAccentLevel.strong,
        MetronomeAccentLevel.mute,
        MetronomeAccentLevel.normal,
        MetronomeAccentLevel.normal,
        MetronomeAccentLevel.strong,
        MetronomeAccentLevel.normal,
        MetronomeAccentLevel.mute,
      ],
      countInBars: 2,
      haptics: false,
    );

    final restored = MetronomeSettings.fromJson(original.toJson());
    expect(restored.bpm, 144);
    expect(restored.meter, const MetronomeMeter(7, 8));
    expect(restored.subdivision, MetronomeSubdivision.triplet);
    expect(restored.accents, original.accents);
    expect(restored.countInBars, 2);
    expect(restored.haptics, isFalse);
  });

  test('손상되거나 오래된 JSON은 기본값과 범위 안으로 복원한다', () {
    final restored = MetronomeSettings.fromJson({
      'bpm': '빠르기',
      'num': 999,
      'den': -2,
      'sub': 'unknown',
      'accents': [99, 'bad', -4, null],
      'countIn': 'none',
      'haptics': 'yes',
    });

    expect(restored.bpm, 120);
    expect(restored.meter, const MetronomeMeter(12, 1));
    expect(restored.subdivision, MetronomeSubdivision.quarter);
    expect(restored.accents, [
      MetronomeAccentLevel.strong,
      MetronomeAccentLevel.mute,
      MetronomeAccentLevel.normal,
      MetronomeAccentLevel.normal,
      MetronomeAccentLevel.normal,
      MetronomeAccentLevel.normal,
      MetronomeAccentLevel.normal,
      MetronomeAccentLevel.normal,
      MetronomeAccentLevel.normal,
      MetronomeAccentLevel.normal,
      MetronomeAccentLevel.normal,
      MetronomeAccentLevel.normal,
    ]);
    expect(restored.countInBars, 1);
    expect(restored.haptics, isTrue);
  });

  test('NaN과 무한대는 메트로놈 설정을 깨뜨리지 않는다', () {
    final restored = MetronomeSettings.fromJson({
      'bpm': double.nan,
      'num': double.infinity,
      'den': double.negativeInfinity,
      'accents': [double.nan, double.infinity, 1],
      'countIn': double.nan,
    });

    expect(restored.bpm, 120);
    expect(restored.meter, const MetronomeMeter(4, 4));
    expect(restored.accents, [
      MetronomeAccentLevel.normal,
      MetronomeAccentLevel.normal,
      MetronomeAccentLevel.normal,
      MetronomeAccentLevel.normal,
    ]);
    expect(restored.countInBars, 1);
  });

  test('누락된 JSON 값은 설정 기본값을 유지한다', () {
    final restored = MetronomeSettings.fromJson({});

    expect(restored.bpm, 120);
    expect(restored.meter, const MetronomeMeter(4, 4));
    expect(restored.subdivision, MetronomeSubdivision.quarter);
    expect(restored.countInBars, 1);
    expect(restored.haptics, isTrue);
    expect(restored.accents, [
      MetronomeAccentLevel.strong,
      MetronomeAccentLevel.normal,
      MetronomeAccentLevel.normal,
      MetronomeAccentLevel.normal,
    ]);
  });

  test('악센트가 짧거나 길어도 박자표 길이에 맞춘다', () {
    final short = MetronomeSettings.fromJson({
      'num': 3,
      'accents': [MetronomeAccentLevel.strong.index],
    });
    expect(short.accents, [
      MetronomeAccentLevel.strong,
      MetronomeAccentLevel.normal,
      MetronomeAccentLevel.normal,
    ]);

    final long = MetronomeSettings.fromJson({
      'num': 2,
      'accents': [
        MetronomeAccentLevel.mute.index,
        MetronomeAccentLevel.strong.index,
        MetronomeAccentLevel.strong.index,
      ],
    });
    expect(long.accents, [
      MetronomeAccentLevel.mute,
      MetronomeAccentLevel.strong,
    ]);
  });

  test('박자표 변경은 기존 악센트를 유지하고 새 박을 기본으로 채운다', () {
    expect(
      accentsForMeter(const MetronomeMeter(5, 4), const [
        MetronomeAccentLevel.mute,
        MetronomeAccentLevel.strong,
      ]),
      [
        MetronomeAccentLevel.mute,
        MetronomeAccentLevel.strong,
        MetronomeAccentLevel.normal,
        MetronomeAccentLevel.normal,
        MetronomeAccentLevel.normal,
      ],
    );
    expect(
      accentsForMeter(const MetronomeMeter(2, 4), const [
        MetronomeAccentLevel.strong,
        MetronomeAccentLevel.mute,
        MetronomeAccentLevel.strong,
      ]),
      [MetronomeAccentLevel.strong, MetronomeAccentLevel.mute],
    );
  });
}
