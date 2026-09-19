import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/features/score_viewer/domain/annotation_stroke.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart' as pdfrx;

/// 원본 PDF를 보존한 채 페이지와 앱 펜 주석을 평면화한 새 PDF를 만든다.
class AnnotatedPdfExporter {
  const AnnotatedPdfExporter();

  static const double _renderDpi = 144;
  static const double _maxRenderSide = 2400;

  Future<Uint8List> export({
    required String sourcePath,
    required String title,
    required Map<int, List<AnnotationStroke>> annotations,
  }) async {
    if (annotations.values.every((strokes) => strokes.isEmpty)) {
      throw const FormatException('내보낼 주석이 없습니다.');
    }

    await pdfrx.pdfrxFlutterInitialize();
    final source = await pdfrx.PdfDocument.openFile(sourcePath);
    try {
      final output = pw.Document(
        title: title,
        creator: 'Page-a-Diddle',
        subject: 'Flattened score annotations',
        compress: true,
      );

      for (final page in source.pages) {
        if (!page.width.isFinite ||
            !page.height.isFinite ||
            page.width <= 0 ||
            page.height <= 0) {
          throw const FormatException('PDF 페이지 크기를 확인하세요.');
        }

        final requestedScale = _renderDpi / 72;
        final sizeLimitedScale =
            _maxRenderSide / math.max(page.width, page.height);
        final scale = math.min(requestedScale, sizeLimitedScale);
        final pixelWidth = math.max(1, (page.width * scale).round());
        final pixelHeight = math.max(1, (page.height * scale).round());
        final rendered = await page.render(
          fullWidth: pixelWidth.toDouble(),
          fullHeight: pixelHeight.toDouble(),
          backgroundColor: 0xFFFFFFFF,
        );
        if (rendered == null) {
          throw FormatException('${page.pageNumber}페이지를 변환하지 못했습니다.');
        }

        late final Uint8List flattenedPng;
        try {
          flattenedPng = await composeAnnotatedPagePng(
            bgraPixels: rendered.pixels,
            pixelWidth: rendered.width,
            pixelHeight: rendered.height,
            pageWidth: page.width,
            pageHeight: page.height,
            strokes: annotations[page.pageNumber] ?? const <AnnotationStroke>[],
          );
        } finally {
          rendered.dispose();
        }

        final pageImage = pw.MemoryImage(flattenedPng);
        output.addPage(
          pw.Page(
            pageFormat: pdf.PdfPageFormat(
              page.width,
              page.height,
              marginAll: 0,
            ),
            build: (_) => pw.FullPage(
              ignoreMargins: true,
              child: pw.Image(pageImage, fit: pw.BoxFit.fill),
            ),
          ),
        );
      }

      return output.save();
    } finally {
      await source.dispose();
    }
  }
}

/// BGRA PDF 페이지에 정규화 좌표의 펜 획을 합성해 PNG로 반환한다.
///
/// 별도 투명 레이어에서 지우개를 적용하므로 지우개가 원본 PDF를 지우지 않는다.
Future<Uint8List> composeAnnotatedPagePng({
  required Uint8List bgraPixels,
  required int pixelWidth,
  required int pixelHeight,
  required double pageWidth,
  required double pageHeight,
  required List<AnnotationStroke> strokes,
}) async {
  if (pixelWidth <= 0 || pixelHeight <= 0) {
    throw ArgumentError('페이지 픽셀 크기는 0보다 커야 합니다.');
  }
  if (bgraPixels.lengthInBytes != pixelWidth * pixelHeight * 4) {
    throw ArgumentError('BGRA 픽셀 크기가 페이지와 맞지 않습니다.');
  }
  if (!pageWidth.isFinite ||
      !pageHeight.isFinite ||
      pageWidth <= 0 ||
      pageHeight <= 0) {
    throw ArgumentError('PDF 페이지 크기를 확인하세요.');
  }

  final baseImage = await _imageFromBgra(
    bgraPixels,
    width: pixelWidth,
    height: pixelHeight,
  );
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final bounds = ui.Rect.fromLTWH(
    0,
    0,
    pixelWidth.toDouble(),
    pixelHeight.toDouble(),
  );
  canvas.drawImage(baseImage, ui.Offset.zero, ui.Paint());
  canvas.saveLayer(bounds, ui.Paint());
  canvas.clipRect(bounds);

  final strokeScale = pixelWidth / pageWidth;
  for (final stroke in strokes) {
    if (stroke.points.length < 2) {
      continue;
    }
    final path = ui.Path()
      ..moveTo(
        stroke.points.first.dx * pixelWidth,
        stroke.points.first.dy * pixelHeight,
      );
    for (final point in stroke.points.skip(1)) {
      path.lineTo(point.dx * pixelWidth, point.dy * pixelHeight);
    }
    final paint = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = stroke.width * strokeScale
      ..strokeCap = ui.StrokeCap.round
      ..strokeJoin = ui.StrokeJoin.round
      ..blendMode = stroke.eraser ? ui.BlendMode.clear : ui.BlendMode.srcOver
      ..color = stroke.eraser
          ? const ui.Color(0x00000000)
          : stroke.color.withValues(alpha: stroke.opacity);
    canvas.drawPath(path, paint);
  }
  canvas.restore();

  final picture = recorder.endRecording();
  try {
    final flattened = await picture.toImage(pixelWidth, pixelHeight);
    try {
      final bytes = await flattened.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        throw StateError('PDF 페이지 이미지를 만들지 못했습니다.');
      }
      return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    } finally {
      flattened.dispose();
    }
  } finally {
    picture.dispose();
    baseImage.dispose();
  }
}

Future<ui.Image> _imageFromBgra(
  Uint8List pixels, {
  required int width,
  required int height,
}) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: width,
    height: height,
    rowBytes: width * 4,
    pixelFormat: ui.PixelFormat.bgra8888,
  );
  try {
    final codec = await descriptor.instantiateCodec();
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  } finally {
    descriptor.dispose();
    buffer.dispose();
  }
}

final annotatedPdfExporterProvider = Provider<AnnotatedPdfExporter>((ref) {
  return const AnnotatedPdfExporter();
});

String annotatedPdfFileName(String title) {
  final sanitized = title
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final base = sanitized.isEmpty ? 'score' : sanitized;
  return '$base-annotations.pdf';
}
