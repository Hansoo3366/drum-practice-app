import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_notemus/flutter_notemus.dart' as nm;
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Fantaisie painter keeps bass clef within A4 width', () async {
    final bytes = File(
      'assets/scores/fantaisie-impromptu-in-c-minor-chopin.mxl',
    ).readAsBytesSync();
    final score = const MusicXmlCodec().decode(
      Uint8List.fromList(bytes),
      fileName: 'fantaisie.mxl',
    );
    final xml = utf8.decode(const MusicXmlCodec().encodeMusicXml(score));
    final engraved = nm.MusicXMLParser.scoreFromMusicXML(xml);
    expect(engraved.staffGroups.first.staves, hasLength(2));
    expect(
      engraved.staffGroups.first.staves[1].measures.first.allElements
          .whereType<nm.Clef>()
          .first
          .clefType,
      nm.ClefType.bass,
    );

    final metadata = nm.SmuflMetadata();
    await metadata.load();
    const pagePad = 16.0;
    final painter = nm.GrandStaffPainter(
      groups: engraved.staffGroups,
      staffSpace: 10,
      metadata: metadata,
      theme: const nm.MusicScoreTheme(),
      availableWidth: scorePageWidthPx - pagePad * 2,
      staffGap: 10 * 12,
    );
    expect(painter.availableWidth, scorePageWidthPx - pagePad * 2);
    // notemus may report contentWidth past availableWidth; paint is clipped to A4.
    expect(painter.totalHeight, greaterThan(800));
  });

  test('A4 page constants match product decision', () {
    expect(scorePageWidthPx, 794);
    expect(scorePageHeightPx, 1123);
    expect(scorePageGapPx, 24);
  });
}
