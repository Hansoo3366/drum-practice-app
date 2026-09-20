import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_notemus/flutter_notemus.dart' as nm;
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_layout.dart';
import 'package:page_a_diddle/features/digital_score/presentation/piano_score_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('paginateSystemsOntoA4Pages never splits a system across pages', () async {
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

    const pad = 16.0;
    final painter = nm.GrandStaffPainter(
      groups: engraved.staffGroups,
      staffSpace: 10,
      metadata: metadata,
      theme: const nm.MusicScoreTheme(),
      availableWidth: scorePageWidthPx - pad * 2,
      staffGap: 120,
    );

    final pages = paginateSystemsOntoA4Pages(painter, pagePad: pad);
    expect(pages, isNotEmpty);

    final seen = <int>{};
    final block = painter.systemBlockHeight;
    final topInset = painter.contentTopInset;
    final n = painter.systemCount;
    final bottomInset = math.max(
      0.0,
      painter.totalHeight - n * block - topInset,
    );
    final usable = scorePageHeightPx - pad * 2;

    for (final page in pages) {
      expect(page, isNotEmpty);
      final used = topInset + page.length * block;
      expect(used + bottomInset, lessThanOrEqualTo(usable + 0.5));
      for (final sys in page) {
        expect(seen.contains(sys), isFalse);
        seen.add(sys);
      }
    }
    expect(seen.length, painter.systemCount);
  });
}
