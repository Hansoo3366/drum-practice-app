import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_notemus/flutter_notemus.dart' as nm;
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('probe Clair system widths at A4', () async {
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
    final aw = scorePageWidthPx - pad * 2;
    final p = nm.GrandStaffPainter(
      groups: engraved.staffGroups,
      staffSpace: 10,
      metadata: metadata,
      theme: const nm.MusicScoreTheme(),
      availableWidth: aw,
      staffGap: 120,
    );
    // ignore: avoid_print
    print('aw=$aw systems=${p.systemCount} contentW=${p.contentWidth}');
    for (var sys = 0; sys < p.systemCount && sys < 12; sys++) {
      var maxBar = 0.0;
      var maxAny = 0.0;
      for (final staff in p.alignedSystem(sys)) {
        for (final pe in staff) {
          if (pe.position.dx > maxAny) maxAny = pe.position.dx;
          if (pe.element is nm.Barline && pe.position.dx > maxBar) {
            maxBar = pe.position.dx;
          }
        }
      }
      final right = maxBar > 0 ? maxBar : maxAny;
      final fill = (22 + right) / aw;
      // ignore: avoid_print
      print('sys$sys right=${right.toStringAsFixed(1)} fill=${fill.toStringAsFixed(2)}');
    }
  });
}
