import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_layout.dart';
import 'package:page_a_diddle/features/digital_score/presentation/piano_score_view.dart';

void main() {
  test('a4FitWidthLetterboxTransform keeps uniform scale and centers vertically', () {
    const viewW = 360.0;
    const viewH = 800.0;
    const docH = scorePageHeightPx;

    final matrix = a4FitWidthLetterboxTransform(
      viewW: viewW,
      viewH: viewH,
      docH: docH,
    );
    final scale = viewW / scorePageWidthPx;
    expect(matrix.entry(0, 0), closeTo(scale, 0.001));
    expect(matrix.entry(1, 1), closeTo(scale, 0.001));

    final topLeft = MatrixUtils.transformPoint(matrix, Offset.zero);
    expect(topLeft.dx, closeTo(0, 0.001));
    final scaledH = docH * scale;
    expect(topLeft.dy, closeTo((viewH - scaledH) / 2, 0.001));

    final pageCorner = MatrixUtils.transformPoint(
      matrix,
      const Offset(scorePageWidthPx, 0),
    );
    expect(pageCorner.dx, closeTo(viewW, 0.001));
  });

  test('a4FitWidthLetterboxTransform top-aligns when document is taller than viewport', () {
    const viewW = 360.0;
    const viewH = 400.0;
    const docH = scorePageHeightPx * 3;

    final matrix = a4FitWidthLetterboxTransform(
      viewW: viewW,
      viewH: viewH,
      docH: docH,
    );
    final topLeft = MatrixUtils.transformPoint(matrix, Offset.zero);
    expect(topLeft.dy, 0);
  });
}
