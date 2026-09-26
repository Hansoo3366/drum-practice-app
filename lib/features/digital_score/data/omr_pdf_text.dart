import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

class OmrPdfText {
  const OmrPdfText();

  Future<String> extract(Uint8List bytes) async {
    final document = await PdfDocument.openData(
      bytes,
      sourceName: 'omr-source',
    );
    try {
      final buffer = StringBuffer();
      for (final page in document.pages) {
        final text = await page.loadText();
        if (text == null || text.fullText.isEmpty) continue;
        buffer.writeln(text.fullText);
      }
      return buffer.toString();
    } finally {
      await document.dispose();
    }
  }
}
