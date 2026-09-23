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

  test(
    'dense bundled systems are uniformly fitted inside A4 content width',
    () async {
      final metadata = nm.SmuflMetadata();
      await metadata.load();
      for (final path in [
        'assets/scores/clair-de-lune-claude-debussy.mxl',
        'assets/scores/fantaisie-impromptu-in-c-minor-chopin.mxl',
      ]) {
        final bytes = File(path).readAsBytesSync();
        final score = const MusicXmlCodec().decode(
          Uint8List.fromList(bytes),
          fileName: path,
        );
        final xml = utf8.decode(const MusicXmlCodec().encodeMusicXml(score));
        final engraved = nm.MusicXMLParser.scoreFromMusicXML(xml);
        final painter = nm.GrandStaffPainter(
          groups: engraved.staffGroups,
          staffSpace: 10,
          metadata: metadata,
          theme: const nm.MusicScoreTheme(),
          availableWidth: scorePageWidthPx - 32,
          staffGap: 120,
        );
        final scales = a4SystemScales(painter);

        expect(scales.length, painter.systemCount);
        expect(scales.any((scale) => scale < 1.0), isTrue);
        for (
          var systemIndex = 0;
          systemIndex < painter.systemCount;
          systemIndex++
        ) {
          final maxPositionX = painter
              .alignedSystem(systemIndex)
              .expand((staff) => staff)
              .map((positioned) => positioned.position.dx)
              .fold<double>(0, (max, x) => x > max ? x : max);
          final estimatedWidth =
              painter.staffSpace * 2.2 + maxPositionX + painter.staffSpace * 8;
          expect(
            estimatedWidth * scales[systemIndex],
            lessThanOrEqualTo(scorePageWidthPx - 32 + 0.001),
          );
        }
      }
    },
  );
}
