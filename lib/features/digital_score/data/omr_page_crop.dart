import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:xml/xml.dart';

int omrSourcePageForMeasure(String musicXml, int measureIndex, int pageCount) {
  if (pageCount < 1) {
    throw const FormatException('원본 PDF에 페이지가 없습니다.');
  }
  final root = XmlDocument.parse(musicXml).rootElement;
  if (root.name.local != 'score-partwise') {
    throw const FormatException('MusicXML의 페이지 위치를 읽을 수 없습니다.');
  }
  final parts = root.findElements('part').toList();
  if (parts.isEmpty) {
    throw const FormatException('MusicXML에 악보 파트가 없습니다.');
  }
  final measures = parts.first.findElements('measure').toList();
  if (measureIndex < 0 || measureIndex >= measures.length) {
    throw const FormatException('검토할 마디를 찾을 수 없습니다.');
  }

  var page = 0;
  var targetPage = 0;
  for (var index = 0; index < measures.length; index++) {
    final startsPage = measures[index]
        .findElements('print')
        .any((print) => print.getAttribute('new-page') == 'yes');
    if (index > 0 && startsPage) page++;
    if (index == measureIndex) targetPage = page;
  }
  if (page != pageCount - 1 || targetPage >= pageCount) {
    throw const FormatException(
      '변환 결과에 원본 PDF의 페이지 위치 정보가 없습니다. 페이지를 확인한 뒤 검토하세요.',
    );
  }
  return targetPage;
}

class OmrPageCrop {
  const OmrPageCrop();

  Future<({Uint8List png, double aspect, int pageCount})> loadPage(
    Uint8List pdfBytes,
    int pageIndex,
  ) async {
    final document = await PdfDocument.openData(
      pdfBytes,
      sourceName: 'omr-preview',
    );
    try {
      if (pageIndex < 0 || pageIndex >= document.pages.length) {
        throw const FormatException('PDF 페이지를 다시 선택하세요.');
      }
      final page = document.pages[pageIndex];
      final png = await renderRegion(
        pdfBytes: pdfBytes,
        pageIndex: pageIndex,
        region: const ui.Rect.fromLTWH(0, 0, 1, 1),
      );
      return (
        png: png,
        aspect: page.width / page.height,
        pageCount: document.pages.length,
      );
    } finally {
      await document.dispose();
    }
  }

  Future<Uint8List> renderRegion({
    required Uint8List pdfBytes,
    required int pageIndex,
    required ui.Rect region,
  }) async {
    validateRegion(region);
    final document = await PdfDocument.openData(
      pdfBytes,
      sourceName: 'omr-region',
    );
    try {
      if (pageIndex < 0 || pageIndex >= document.pages.length) {
        throw const FormatException('PDF 페이지를 다시 선택하세요.');
      }
      final page = document.pages[pageIndex];
      final rendered = await page.render(
        fullWidth: 2000,
        fullHeight: page.height / page.width * 2000,
      );
      if (rendered == null) throw const FormatException('PDF 페이지를 열 수 없습니다.');
      try {
        final left = (region.left * rendered.width).floor();
        final top = (region.top * rendered.height).floor();
        final right = (region.right * rendered.width).ceil().clamp(
          left + 1,
          rendered.width,
        );
        final bottom = (region.bottom * rendered.height).ceil().clamp(
          top + 1,
          rendered.height,
        );
        return await _bgraToPng(
          pixels: rendered.pixels,
          srcWidth: rendered.width,
          srcHeight: rendered.height,
          left: left,
          top: top,
          width: right - left,
          height: bottom - top,
        );
      } finally {
        rendered.dispose();
      }
    } finally {
      await document.dispose();
    }
  }

  static void validateRegion(ui.Rect region) {
    if (![
          region.left,
          region.top,
          region.right,
          region.bottom,
        ].every((v) => v.isFinite) ||
        region.left < 0 ||
        region.top < 0 ||
        region.right > 1 ||
        region.bottom > 1 ||
        region.width < 0.01 ||
        region.height < 0.01) {
      throw const FormatException('원본 마디 영역을 다시 지정하세요.');
    }
  }

  /// Sends a verified source page; MusicXML does not contain measure bounds.
  Future<Uint8List> renderMeasurePage({
    required Uint8List pdfBytes,
    required int measureIndex,
    required String musicXml,
  }) async {
    final document = await PdfDocument.openData(
      pdfBytes,
      sourceName: 'omr-ai-crop',
    );
    try {
      final pageCount = document.pages.length;
      final pageIndex = omrSourcePageForMeasure(
        musicXml,
        measureIndex,
        pageCount,
      );
      final page = document.pages[pageIndex];
      final fullWidth = 2000.0;
      final fullHeight = page.height / page.width * fullWidth;
      final rendered = await page.render(
        fullWidth: fullWidth,
        fullHeight: fullHeight,
      );
      if (rendered == null) {
        throw const FormatException('원본 PDF 페이지를 그리지 못했습니다.');
      }
      try {
        return _bgraToPng(
          pixels: rendered.pixels,
          srcWidth: rendered.width,
          srcHeight: rendered.height,
          left: 0,
          top: 0,
          width: rendered.width,
          height: rendered.height,
        );
      } finally {
        rendered.dispose();
      }
    } finally {
      await document.dispose();
    }
  }

  Future<Uint8List> _bgraToPng({
    required Uint8List pixels,
    required int srcWidth,
    required int srcHeight,
    required int left,
    required int top,
    required int width,
    required int height,
  }) async {
    final cropped = Uint8List(width * height * 4);
    for (var y = 0; y < height; y++) {
      final src = ((top + y) * srcWidth + left) * 4;
      final dst = y * width * 4;
      cropped.setRange(dst, dst + width * 4, pixels, src);
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      cropped,
      width,
      height,
      ui.PixelFormat.bgra8888,
      completer.complete,
    );
    final image = await completer.future;
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) {
      throw const FormatException('PNG로 바꾸지 못했습니다.');
    }
    return bytes.buffer.asUint8List();
  }
}

final omrPageCropProvider = Provider<OmrPageCrop>((ref) => const OmrPageCrop());
