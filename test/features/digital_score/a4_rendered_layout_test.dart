import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_notemus/flutter_notemus.dart' as nm;
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_layout.dart';
import 'package:page_a_diddle/features/digital_score/presentation/piano_score_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('projects highlights and hit-tests onto rendered A4 pages', () async {
    final bytes = File(
      'assets/scores/clair-de-lune-claude-debussy.mxl',
    ).readAsBytesSync();
    final score = const MusicXmlCodec().decode(
      Uint8List.fromList(bytes),
      fileName: 'clair.mxl',
    );
    final xml = utf8.decode(const MusicXmlCodec().encodeMusicXml(score));
    final engraved = nm.MusicXMLParser.scoreFromMusicXML(xml);
    final metadata = nm.SmuflMetadata();
    await metadata.load();
    const pagePad = 16.0;
    final painter = nm.GrandStaffPainter(
      groups: engraved.staffGroups,
      staffSpace: 10,
      metadata: metadata,
      theme: const nm.MusicScoreTheme(),
      availableWidth: scorePageWidthPx - pagePad * 2,
      staffGap: 120,
    );
    final pages = paginateSystemsOntoA4Pages(painter, pagePad: pagePad);
    final projected = layoutRenderedScoreForA4(
      score: score,
      painter: painter,
      pages: pages,
      pagePad: pagePad,
    );

    expect(pages.length, greaterThan(1));
    expect(projected.measures.length, score.parts.first.measures.length);
    expect(projected.systemStarts, isNotEmpty);

    for (final measure in projected.measures) {
      final pageIndex =
          (measure.rect.top / (scorePageHeightPx + scorePageGapPx)).floor();
      final pageTop = pageIndex * (scorePageHeightPx + scorePageGapPx);
      expect(measure.rect.top, greaterThanOrEqualTo(pageTop));
      expect(measure.rect.top, lessThan(pageTop + scorePageHeightPx));
      expect(
        projected.measureAt(measure.rect.center)?.measureIndex,
        measure.measureIndex,
      );
    }

    final laterPageMeasure = projected.measures.firstWhere(
      (measure) => measure.rect.top >= scorePageHeightPx + scorePageGapPx,
    );
    expect(laterPageMeasure.measureIndex, greaterThan(0));
  });
}
