import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/stage/domain/stage_section_preview.dart';

void main() {
  const markers = [
    StageSectionMarker(number: 1, section: 'INTRO'),
    StageSectionMarker(number: 5, section: 'VERSE'),
    StageSectionMarker(number: 13, section: 'CHORUS'),
    StageSectionMarker(number: 21, section: 'CHORUS'),
    StageSectionMarker(number: 29, section: 'BRIDGE'),
  ];

  test('현재 Section과 다음 변경까지 남은 마디를 계산한다', () {
    final preview = calculateStageSectionPreview(markers, currentMeasure: 8);

    expect(preview!.currentSection, 'VERSE');
    expect(preview.currentMeasure, 8);
    expect(preview.nextSection, 'CHORUS');
    expect(preview.measuresUntilNext, 5);
  });

  test('같은 Section 표식은 건너뛴다', () {
    final preview = calculateStageSectionPreview(markers, currentMeasure: 15);

    expect(preview!.currentSection, 'CHORUS');
    expect(preview.nextSection, 'BRIDGE');
    expect(preview.measuresUntilNext, 14);
  });

  test('현재 마디가 없으면 첫 마디에서 시작한다', () {
    final preview = calculateStageSectionPreview(markers);

    expect(preview!.currentMeasure, 1);
    expect(preview.currentSection, 'INTRO');
    expect(preview.nextSection, 'VERSE');
  });

  test('다음 Section이 없으면 현재 정보만 반환한다', () {
    final preview = calculateStageSectionPreview(markers, currentMeasure: 30);

    expect(preview!.currentSection, 'BRIDGE');
    expect(preview.nextSection, isNull);
    expect(preview.measuresUntilNext, isNull);
  });

  test('Measure가 없으면 Preview를 만들지 않는다', () {
    expect(calculateStageSectionPreview(const []), isNull);
  });
}
