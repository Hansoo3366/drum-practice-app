import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/engraved_pdf_exporter.dart';
import 'package:page_a_diddle/features/digital_score/presentation/verovio_text_labels.dart';

ByteData _font(String path) =>
    ByteData.sublistView(File(path).readAsBytesSync());

void main() {
  const svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 840 1188">'
      '<path d="M100 200 L700 200" stroke="black" stroke-width="2"/></svg>';

  test('writes one PDF page per engraved page, with Korean text', () async {
    final bytes = await const EngravedPdfExporter().export(
      [
        const EngravedPage(
          svg: svg,
          width: 840,
          height: 1188,
          labels: [
            VerovioTextLabel(
              text: '주가 보이신',
              x: 120,
              baselineY: 260,
              fontSize: 30,
            ),
            VerovioTextLabel(
              text: 'B♭/D — F♯m7',
              x: 400,
              baselineY: 180,
              fontSize: 30,
              anchor: TextAlign.center,
            ),
            VerovioTextLabel(
              text: '12',
              x: 90,
              baselineY: 190,
              fontSize: 20,
              anchor: TextAlign.right,
            ),
          ],
        ),
        const EngravedPage(svg: svg, width: 840, height: 1188, labels: []),
        // A page without a size is passed over.
        const EngravedPage(svg: svg, width: 0, height: 0, labels: []),
      ],
      title: '테스트',
      text: _font('assets/fonts/SUIT-Regular.ttf'),
      fallbacks: [_font('assets/fonts/JetBrainsMono-Regular.ttf')],
    );

    final text = latin1.decode(bytes, allowInvalid: true);
    expect(text.substring(0, 5), '%PDF-');
    expect(RegExp(r'/Type\s*/Page\b').allMatches(text), hasLength(2));
    // Both fonts are embedded: the words, and the accidentals and dash.
    expect(
      RegExp('/FontFile2').allMatches(text).length,
      greaterThanOrEqualTo(2),
    );
  });

  test('the bundled text font is one the PDF writer can embed', () {
    // TrueType outlines start with 00 01 00 00; the app's OTF copy (OTTO)
    // cannot be embedded with its Korean glyphs.
    final head = File('assets/fonts/SUIT-Regular.ttf').readAsBytesSync();
    expect(head.sublist(0, 4), [0, 1, 0, 0]);
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- assets/fonts/SUIT-Regular.ttf'),
    );
  });
}
