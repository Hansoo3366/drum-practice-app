import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_notemus/flutter_notemus.dart' as nm;
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/presentation/piano_score_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('screen layout uses a continuous viewport-width document', () async {
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

    const viewportWidth = 360.0;
    const staffSpace = 9.0;
    final painter = nm.GrandStaffPainter(
      groups: engraved.staffGroups,
      staffSpace: staffSpace,
      metadata: metadata,
      theme: const nm.MusicScoreTheme(),
      availableWidth: viewportWidth,
      staffGap: staffSpace * 12,
    );
    final documentWidth = math.max(viewportWidth, painter.contentWidth);
    final projected = layoutRenderedScoreForScreen(
      score: score,
      painter: painter,
      documentWidth: documentWidth,
    );

    expect(projected.contentSize.width, greaterThanOrEqualTo(viewportWidth));
    expect(projected.contentSize.height, painter.totalHeight);
    expect(projected.measures.length, score.parts.first.measures.length);
    expect(projected.systemStarts, hasLength(painter.systemCount));

    for (final measure in projected.measures) {
      expect(measure.rect.left, greaterThanOrEqualTo(0));
      expect(measure.rect.right, lessThanOrEqualTo(documentWidth + 0.001));
      expect(measure.rect.top, greaterThanOrEqualTo(0));
      expect(
        measure.rect.bottom,
        lessThanOrEqualTo(painter.totalHeight + 0.001),
      );
    }

    final systemTopByStart = <int, double>{};
    for (final start in projected.systemStarts) {
      final first = projected.measures.firstWhere(
        (measure) => measure.measureIndex == start,
      );
      systemTopByStart[start] = first.rect.top;
    }
    final systemTops = systemTopByStart.values.toList();
    for (var index = 1; index < systemTops.length; index++) {
      expect(systemTops[index], greaterThan(systemTops[index - 1]));
    }

    for (
      var systemIndex = 0;
      systemIndex < painter.systemCount;
      systemIndex++
    ) {
      final aligned = painter.alignedSystem(systemIndex);
      final sharedEnd = grandStaffSystemEndX(
        aligned,
        staffSpace: painter.staffSpace,
      );
      for (final staff in aligned) {
        for (final positioned in staff) {
          if (positioned.element is nm.Barline) {
            expect(positioned.position.dx, lessThan(sharedEnd));
          }
        }
      }
    }
  });
}
