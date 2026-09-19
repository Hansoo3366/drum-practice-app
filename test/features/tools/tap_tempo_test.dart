import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/tools/domain/tap_tempo.dart';

void main() {
  test('최근 탭 간격 평균으로 BPM을 계산하고 긴 공백 뒤에는 다시 시작한다', () {
    final tempo = TapTempo();
    final start = DateTime(2026);

    tempo.tap(start);
    tempo.tap(start.add(const Duration(milliseconds: 500)));
    tempo.tap(start.add(const Duration(milliseconds: 1000)));
    tempo.tap(start.add(const Duration(milliseconds: 1480)));

    expect(tempo.bpm, 122);
    expect(tempo.tapCount, 4);

    tempo.tap(start.add(const Duration(seconds: 4)));

    expect(tempo.bpm, isNull);
    expect(tempo.tapCount, 1);
  });
}
