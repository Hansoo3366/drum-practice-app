import 'dart:typed_data';

import 'package:page_a_diddle/features/digital_score/data/midi_codec.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/data/score_pdf_exporter.dart';
import 'package:page_a_diddle/features/digital_score/data/score_project_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_profile.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/performance_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';

enum ScoreExportKind { musicXml, midi, pdf, project }

/// The extension an exported MusicXML file is saved under.
///
/// ".xml", not ".musicxml": Android does not know ".musicxml", and the
/// system's save dialog then numbers a second file of the same name after
/// the extension ("song.musicxml (1)"), which no program opens. ".xml" is
/// the other name MusicXML files go by, and one the system does know
/// ("song (1).xml").
const musicXmlExportExtension = 'xml';

class ScoreExport {
  const ScoreExport({
    required this.bytes,
    required this.fileName,
    required this.extension,
  });

  final Uint8List bytes;
  final String fileName;
  final String extension;
}

class ScoreExportService {
  const ScoreExportService({
    MusicXmlCodec musicXmlCodec = const MusicXmlCodec(),
    MidiCodec midiCodec = const MidiCodec(),
    ScorePdfExporter pdfExporter = const ScorePdfExporter(),
    ScoreProjectCodec projectCodec = const ScoreProjectCodec(),
  }) : _musicXmlCodec = musicXmlCodec,
       _midiCodec = midiCodec,
       _pdfExporter = pdfExporter,
       _projectCodec = projectCodec;

  final MusicXmlCodec _musicXmlCodec;
  final MidiCodec _midiCodec;
  final ScorePdfExporter _pdfExporter;
  final ScoreProjectCodec _projectCodec;

  Future<ScoreExport> encode({
    required MusicScore written,
    required String title,
    PlaybackSequence sequence = PlaybackSequence.empty,
    ArrangementProfile arrangement = ArrangementProfile.off,
    required ScoreExportKind kind,
    String? sourceXml,
  }) async {
    final safeTitle = safeExportFileName(title);
    final performance = kind == ScoreExportKind.project
        ? written
        : composePerformanceScore(
            written,
            sequence: sequence,
            arrangement: arrangement,
          );
    return switch (kind) {
      ScoreExportKind.musicXml => ScoreExport(
        bytes: _musicXmlCodec.encode(performance, MusicXmlFileFormat.musicXml),
        fileName: '$safeTitle.$musicXmlExportExtension',
        extension: musicXmlExportExtension,
      ),
      ScoreExportKind.midi => ScoreExport(
        bytes: _midiCodec.encode(performance),
        fileName: '$safeTitle.mid',
        extension: 'mid',
      ),
      ScoreExportKind.pdf => ScoreExport(
        bytes: await _pdfExporter.export(performance),
        fileName: '$safeTitle.pdf',
        extension: 'pdf',
      ),
      ScoreExportKind.project => ScoreExport(
        bytes: _projectCodec.encode(
          written: written,
          sequence: sequence,
          arrangement: arrangement,
          sourceXml: sourceXml,
        ),
        fileName: '$safeTitle.zip',
        extension: 'zip',
      ),
    };
  }
}

String safeExportFileName(String value) {
  final sanitized = value
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return sanitized.isEmpty ? 'score' : sanitized;
}
