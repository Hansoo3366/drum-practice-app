import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_editor.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ScorePdfExporter {
  const ScorePdfExporter();

  static const int measuresPerSystem = 4;
  static const int systemsPerPage = 3;
  static const int measuresPerPage = measuresPerSystem * systemsPerPage;

  Future<Uint8List> export(MusicScore score) async {
    final measures = score.parts.first.measures;
    final pageCount = math.max(1, (measures.length / measuresPerPage).ceil());
    final document = pw.Document(
      title: score.title ?? 'Score',
      creator: 'Page-a-Diddle',
      subject: 'Reconstructed piano score',
    );
    final fontData = await rootBundle.load('assets/fonts/SUIT-Regular.otf');
    final font = PdfTtfFont(document.document, fontData);
    for (var pageIndex = 0; pageIndex < pageCount; pageIndex++) {
      final start = pageIndex * measuresPerPage;
      final end = math.min(start + measuresPerPage, measures.length);
      final slice = measures.sublist(start, end);
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (context) {
            return pw.CustomPaint(
              size: PdfPoint(
                context.page.pageFormat.availableWidth,
                context.page.pageFormat.availableHeight,
              ),
              painter: (canvas, size) {
                _paintPage(
                  canvas,
                  size,
                  score: score,
                  measures: slice,
                  pageIndex: pageIndex,
                  font: font,
                );
              },
            );
          },
        ),
      );
    }
    return document.save();
  }

  void _paintPage(
    PdfGraphics canvas,
    PdfPoint size, {
    required MusicScore score,
    required List<MusicMeasure> measures,
    required int pageIndex,
    required PdfFont font,
  }) {
    if (pageIndex == 0 && (score.title ?? '').isNotEmpty) {
      canvas
        ..setFillColor(PdfColors.black)
        ..drawString(font, 16, score.title!, 0, size.y - 18);
    }
    final systemHeight = 96.0;
    final usableTop = size.y - (pageIndex == 0 ? 36 : 8);
    for (var system = 0; system < systemsPerPage; system++) {
      final systemStart = system * measuresPerSystem;
      if (systemStart >= measures.length) break;
      final systemMeasures = measures.sublist(
        systemStart,
        math.min(systemStart + measuresPerSystem, measures.length),
      );
      final top = usableTop - system * systemHeight;
      _paintSystem(canvas, font, size.x, top, systemMeasures);
    }
  }

  void _paintSystem(
    PdfGraphics canvas,
    PdfFont font,
    double width,
    double top,
    List<MusicMeasure> measures,
  ) {
    const lineGap = 6.0;
    final trebleTop = top - 18;
    final bassTop = trebleTop - 36;
    canvas
      ..setStrokeColor(PdfColors.black)
      ..setLineWidth(0.7);
    for (var line = 0; line < 5; line++) {
      final trebleY = trebleTop - line * lineGap;
      final bassY = bassTop - line * lineGap;
      canvas
        ..moveTo(16, trebleY)
        ..lineTo(width, trebleY)
        ..moveTo(16, bassY)
        ..lineTo(width, bassY);
    }
    canvas
      ..moveTo(16, trebleTop)
      ..lineTo(16, bassTop - 4 * lineGap)
      ..strokePath();
    canvas.drawString(font, 11, 'G', 18, trebleTop - 18);
    canvas.drawString(font, 11, 'F', 18, bassTop - 18);

    final measureWidth = (width - 36) / measures.length;
    for (var index = 0; index < measures.length; index++) {
      final left = 36 + index * measureWidth;
      canvas
        ..moveTo(left + measureWidth, trebleTop)
        ..lineTo(left + measureWidth, bassTop - 4 * lineGap)
        ..strokePath();
      _paintMeasure(
        canvas,
        font,
        measures[index],
        left: left,
        width: measureWidth,
        trebleTop: trebleTop,
        bassTop: bassTop,
        lineGap: lineGap,
      );
    }
  }

  void _paintMeasure(
    PdfGraphics canvas,
    PdfFont font,
    MusicMeasure measure, {
    required double left,
    required double width,
    required double trebleTop,
    required double bassTop,
    required double lineGap,
  }) {
    final section = measurePlaybackSection(measure);
    if (section != null) {
      canvas
        ..setFillColor(PdfColors.black)
        ..drawString(font, 8, section, left + 4, trebleTop + 14);
    }
    for (final harmony in measure.events.whereType<MusicHarmony>()) {
      canvas.drawString(
        font,
        8,
        _harmonyLabel(harmony),
        left +
            4 +
            (harmony.onset / math.max(1, measureCapacity(measure.attributes))) *
                (width - 12),
        trebleTop + 4,
      );
    }
    final notes = measure.notes.where((note) => !note.isRest).toList();
    for (final note in notes) {
      final pitch = note.pitch!;
      final staffTop = note.staff >= 2 ? bassTop : trebleTop;
      final y = _staffY(
        pitch,
        staffTop: staffTop,
        lineGap: lineGap,
        bass: note.staff >= 2,
      );
      final x =
          left +
          10 +
          (note.onset / math.max(1, measureCapacity(measure.attributes))) *
              (width - 20);
      canvas
        ..setFillColor(PdfColors.black)
        ..drawEllipse(x, y, 3.2, 2.2)
        ..fillPath();
    }
  }

  double _staffY(
    MusicPitch pitch, {
    required double staffTop,
    required double lineGap,
    required bool bass,
  }) {
    final steps = (pitch.octave - 4) * 7 + pitch.step.index;
    final reference = bass ? -2 : 2; // F3 vs E4
    return staffTop - ((steps - reference) * (lineGap / 2));
  }

  String _harmonyLabel(MusicHarmony harmony) {
    final accidental = switch (harmony.rootAlter) {
      < 0 => 'b',
      > 0 => '#',
      _ => '',
    };
    final suffix = switch (harmony.kind) {
      'minor' => 'm',
      'dominant' => '7',
      _ => '',
    };
    return '${harmony.rootStep.musicXmlName}$accidental$suffix';
  }
}
