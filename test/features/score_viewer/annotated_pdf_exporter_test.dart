import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/score_viewer/data/annotated_pdf_exporter.dart';
import 'package:page_a_diddle/features/score_viewer/domain/annotation_stroke.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('곡명을 안전한 주석 PDF 파일명으로 바꾼다', () {
    expect(
      annotatedPdfFileName('  My / Score:*  '),
      'My Score-annotations.pdf',
    );
    expect(annotatedPdfFileName('  '), 'score-annotations.pdf');
  });

  test('원본 페이지 위에 색상 펜 획을 합성한다', () async {
    final png = await composeAnnotatedPagePng(
      bgraPixels: _whiteBgra(32, 32),
      pixelWidth: 32,
      pixelHeight: 32,
      pageWidth: 32,
      pageHeight: 32,
      strokes: const [
        AnnotationStroke(
          points: [Offset(0.1, 0.5), Offset(0.9, 0.5)],
          color: Color(0xFFFF0000),
          width: 6,
        ),
      ],
    );

    final center = await _rgbaAt(png, width: 32, x: 16, y: 16);
    expect(center.$1, greaterThan(220));
    expect(center.$2, lessThan(80));
    expect(center.$3, lessThan(80));
    expect(center.$4, 255);
  });

  test('지우개는 앞선 펜 획만 지우고 원본 페이지를 보존한다', () async {
    final png = await composeAnnotatedPagePng(
      bgraPixels: _whiteBgra(32, 32),
      pixelWidth: 32,
      pixelHeight: 32,
      pageWidth: 32,
      pageHeight: 32,
      strokes: const [
        AnnotationStroke(
          points: [Offset(0.1, 0.5), Offset(0.9, 0.5)],
          color: Color(0xFFFF0000),
          width: 8,
        ),
        AnnotationStroke(
          points: [Offset(0.5, 0.2), Offset(0.5, 0.8)],
          color: Colors.transparent,
          width: 8,
          eraser: true,
        ),
      ],
    );

    final center = await _rgbaAt(png, width: 32, x: 16, y: 16);
    expect(center, (255, 255, 255, 255));
  });

  test('픽셀 크기가 맞지 않으면 내보내기를 거부한다', () {
    expect(
      () => composeAnnotatedPagePng(
        bgraPixels: Uint8List(4),
        pixelWidth: 2,
        pixelHeight: 2,
        pageWidth: 2,
        pageHeight: 2,
        strokes: const [],
      ),
      throwsArgumentError,
    );
  });
}

Uint8List _whiteBgra(int width, int height) {
  final pixels = Uint8List(width * height * 4);
  for (var i = 0; i < pixels.length; i += 4) {
    pixels[i] = 255;
    pixels[i + 1] = 255;
    pixels[i + 2] = 255;
    pixels[i + 3] = 255;
  }
  return pixels;
}

Future<(int, int, int, int)> _rgbaAt(
  Uint8List png, {
  required int width,
  required int x,
  required int y,
}) async {
  final codec = await ui.instantiateImageCodec(png);
  try {
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final bytes = data!.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final offset = (y * width + x) * 4;
      return (
        bytes[offset],
        bytes[offset + 1],
        bytes[offset + 2],
        bytes[offset + 3],
      );
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}
