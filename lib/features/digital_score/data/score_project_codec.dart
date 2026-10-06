import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_profile.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';

class ScoreProjectCodec {
  const ScoreProjectCodec();

  static const String formatName = 'page-a-diddle-score';
  static const int formatVersion = 1;

  Uint8List encode({
    required MusicScore written,
    required PlaybackSequence sequence,
    required ArrangementProfile arrangement,
    String? sourceXml,
  }) {
    final archive = Archive();
    archive.add(
      ArchiveFile.string(
        'manifest.json',
        jsonEncode({
          'format': formatName,
          'version': formatVersion,
          'title': written.title,
          'sequence': sequence.toJson(),
          'arrangement': arrangement.toJson(),
        }),
      ),
    );
    archive.add(
      ArchiveFile.bytes(
        'score.musicxml',
        sourceXml == null
            ? const MusicXmlCodec().encodeMusicXml(written)
            : Uint8List.fromList(utf8.encode(sourceXml)),
      ),
    );
    return ZipEncoder().encodeBytes(archive);
  }

  ScoreProject decode(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const FormatException('The project file is empty.');
    }
    final archive = ZipDecoder().decodeBytes(bytes);
    final manifestFile = archive.findFile('manifest.json');
    final scoreFile = archive.findFile('score.musicxml');
    if (manifestFile == null || scoreFile == null) {
      throw const FormatException('The project file is incomplete.');
    }
    final manifest = jsonDecode(utf8.decode(manifestFile.content as List<int>));
    if (manifest is! Map || manifest['format'] != formatName) {
      throw const FormatException('Unsupported project format.');
    }
    return ScoreProject(
      score: const MusicXmlCodec().decode(
        Uint8List.fromList(scoreFile.content as List<int>),
        fileName: 'score.musicxml',
      ),
      sequence: PlaybackSequence.fromJson(manifest['sequence']),
      arrangement: ArrangementProfile.fromJson(manifest['arrangement']),
    );
  }
}

class ScoreProject {
  const ScoreProject({
    required this.score,
    required this.sequence,
    required this.arrangement,
  });

  final MusicScore score;
  final PlaybackSequence sequence;
  final ArrangementProfile arrangement;
}
