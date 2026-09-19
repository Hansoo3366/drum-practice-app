import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/features/score_viewer/domain/annotation_stroke.dart';

void main() {
  test('구 형식 점 목록을 주석 획으로 읽는다', () {
    final stroke = AnnotationStroke.tryParse([
      [0.1, 0.2],
      [0.3, 0.4],
    ]);
    expect(stroke, isNotNull);
    expect(stroke!.points, [const Offset(0.1, 0.2), const Offset(0.3, 0.4)]);
    expect(stroke.color, AppColors.accent);
    expect(stroke.width, AnnotationPen.medium.width);
  });

  test('색·굵기·투명도를 저장하고 다시 읽는다', () {
    final original = AnnotationStroke(
      points: const [Offset(0.2, 0.5), Offset(0.8, 0.5)],
      color: const Color(0xFF1E88E5),
      width: AnnotationPen.bold.width,
      opacity: AnnotationPen.marker.opacity,
    );
    final restored = AnnotationStroke.tryParse(original.toJson());
    expect(restored, isNotNull);
    expect(restored!.points, original.points);
    expect(restored.color.toARGB32(), original.color.toARGB32());
    expect(restored.width, original.width);
    expect(restored.opacity, original.opacity);
  });

  test('손상된 점은 건너뛰고 유효한 점만 읽는다', () {
    final stroke = AnnotationStroke.tryParse({
      'p': [
        [0.1, 0.2],
        ['bad', 0.3],
        [double.nan, 0.4],
        [0.5],
        [0.6, 0.7, 'extra'],
      ],
      'w': -10,
      'o': 4,
      'e': true,
    });

    expect(stroke, isNotNull);
    expect(stroke!.points, [const Offset(0.1, 0.2), const Offset(0.6, 0.7)]);
    expect(stroke.width, 0.5);
    expect(stroke.opacity, 1);
    expect(stroke.eraser, isTrue);
  });

  test('점이 없거나 타입이 잘못된 주석은 null이다', () {
    expect(AnnotationStroke.tryParse(null), isNull);
    expect(AnnotationStroke.tryParse('stroke'), isNull);
    expect(AnnotationStroke.tryParse([]), isNull);
    expect(
      AnnotationStroke.tryParse({
        'p': [
          ['x', 'y'],
          [double.infinity, 1],
        ],
      }),
      isNull,
    );
    expect(AnnotationStroke.tryParse({'p': 'not-a-list'}), isNull);
  });

  test('기존 map 형식의 누락된 스타일은 안전한 기본값을 사용한다', () {
    final stroke = AnnotationStroke.tryParse({
      'p': [
        [0, 0],
        [1, 1],
      ],
      'c': double.nan,
      'w': double.nan,
      'o': double.nan,
    });

    expect(stroke, isNotNull);
    expect(stroke!.color, AppColors.accent);
    expect(stroke.width, AnnotationPen.medium.width);
    expect(stroke.opacity, 1);
  });
}
