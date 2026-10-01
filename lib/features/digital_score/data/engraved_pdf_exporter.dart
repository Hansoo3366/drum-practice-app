import 'dart:typed_data';

import 'package:flutter/painting.dart' show TextAlign;
import 'package:page_a_diddle/features/digital_score/presentation/verovio_text_labels.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// One engraved page of a score as the viewer shows it: the notation as an
/// SVG without its text, and the text (lyrics, chord symbols, bar numbers,
/// section names) with where it stands, in the units of [width] and
/// [height].
class EngravedPage {
  const EngravedPage({
    required this.svg,
    required this.labels,
    required this.width,
    required this.height,
  });

  final String svg;
  final List<VerovioTextLabel> labels;
  final double width;
  final double height;
}

/// Writes engraved pages into a PDF, one page each, so what is printed is
/// what the screen shows: every part and staff, with lyrics and chords.
class EngravedPdfExporter {
  const EngravedPdfExporter();

  /// [text] is the font of the words; [fallbacks] are tried in order for a
  /// character it lacks (dashes, accidentals, note symbols).
  Future<Uint8List> export(
    List<EngravedPage> pages, {
    required String title,
    required ByteData text,
    List<ByteData> fallbacks = const [],
  }) async {
    final document = pw.Document(title: title, creator: 'Piano Score');
    final font = pw.Font.ttf(text);
    final others = [for (final data in fallbacks) pw.Font.ttf(data)];
    for (final page in pages) {
      if (page.width <= 0 || page.height <= 0) continue;
      // The engraving fills an A4 page, keeping its own proportions.
      final format = PdfPageFormat(
        PdfPageFormat.a4.width,
        PdfPageFormat.a4.width * page.height / page.width,
      );
      final scale = format.width / page.width;
      // Room on either side of a centred or right-aligned label.
      const reach = 400.0;
      document.addPage(
        pw.Page(
          pageFormat: format,
          margin: pw.EdgeInsets.zero,
          build: (context) => pw.Stack(
            children: [
              pw.Positioned.fill(
                child: pw.SvgImage(svg: page.svg, fit: pw.BoxFit.fill),
              ),
              for (final label in page.labels)
                if (label.text.isNotEmpty)
                  () {
                    final size = label.fontSize * scale * verovioTextScale;
                    final style = pw.TextStyle(
                      font: font,
                      fontFallback: others,
                      fontSize: size,
                      lineSpacing: 0,
                    );
                    // The top of the line box lies an ascent above the
                    // baseline.
                    final top =
                        label.baselineY * scale -
                        font.getFont(context).ascent * size;
                    final x = label.x * scale;
                    return switch (label.anchor) {
                      TextAlign.center => pw.Positioned(
                        left: x - reach,
                        top: top,
                        child: pw.SizedBox(
                          width: 2 * reach,
                          child: pw.Text(
                            label.text,
                            style: style,
                            maxLines: 1,
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ),
                      TextAlign.right => pw.Positioned(
                        left: x - reach,
                        top: top,
                        child: pw.SizedBox(
                          width: reach,
                          child: pw.Text(
                            label.text,
                            style: style,
                            maxLines: 1,
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ),
                      _ => pw.Positioned(
                        left: x,
                        top: top,
                        child: pw.Text(label.text, style: style, maxLines: 1),
                      ),
                    };
                  }(),
            ],
          ),
        ),
      );
    }
    return document.save();
  }
}
