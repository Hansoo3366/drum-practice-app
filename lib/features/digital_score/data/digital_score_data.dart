import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/features/digital_score/data/digital_score_editor_service.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_pdf_text.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_profile.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_quality.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_quality_analyzer.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_source_match.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_version.dart';
import 'package:page_a_diddle/features/library/data/song_repository.dart';

class DigitalScoreData {
  const DigitalScoreData({
    required this.song,
    required this.score,
    this.sourceXml,
    this.versionCatalog = ScoreVersionCatalog.empty,
    this.activeVersionScore,
    this.activeVersionXml,
    this.sequence = PlaybackSequence.empty,
    this.arrangement = ArrangementProfile.off,
    this.originalFifths = 0,
    this.quality,
    this.omrJobId,
  });

  final Song song;

  /// The immutable source score. Version editors are layered on top of it.
  final MusicScore score;

  /// Original MusicXML document, used so Verovio can keep chords, lyrics,
  /// and directions that the editor model does not round-trip.
  final String? sourceXml;
  final ScoreVersionCatalog versionCatalog;

  /// The persisted active version, when the catalog points at a version.
  /// `null` means the active score is the original source score.
  final MusicScore? activeVersionScore;
  final String? activeVersionXml;
  final PlaybackSequence sequence;
  final ArrangementProfile arrangement;
  final int originalFifths;
  final OmrQualityReport? quality;

  /// Server job that converted the song, while its AI version can be fetched.
  final String? omrJobId;
}

final digitalScoreDataProvider = FutureProvider.autoDispose
    .family<DigitalScoreData, String>((ref, songId) async {
      final repository = ref.watch(songRepositoryProvider);
      final song = await repository.getSong(songId);
      if (song == null) {
        throw StateError('악보를 찾을 수 없습니다.');
      }
      final file = await ref
          .watch(songFileStorageProvider)
          .resolve(song.sourcePath);
      if (!await file.exists() || await file.length() == 0) {
        throw StateError('MusicXML 파일을 찾을 수 없습니다.');
      }
      final bytes = await file.readAsBytes();
      final codec = const MusicXmlCodec();
      final sourceXml = codec.xmlString(bytes, fileName: file.path);
      final score = await decodeMusicXmlInBackground(sourceXml, codec);
      final editor = ref.watch(digitalScoreEditorServiceProvider);
      final arrangement = await editor.loadArrangement(songId);
      final originalFifths = await editor.loadOrCaptureOriginalFifths(
        songId: songId,
        score: score,
      );
      var versionCatalog = await editor.loadVersionCatalog(songId);
      MusicScore? activeVersionScore;
      String? activeVersionXml;
      if (versionCatalog.activeId != scoreVersionOriginalId) {
        try {
          final version = await editor.loadVersion(
            songId: songId,
            versionId: versionCatalog.activeId,
          );
          activeVersionScore = version?.score;
          activeVersionXml = version?.xml;
        } on Object {
          activeVersionScore = null;
        }
        if (activeVersionScore == null) {
          // A stale catalog must not prevent the original score from opening.
          versionCatalog = versionCatalog.copyWith(
            activeId: scoreVersionOriginalId,
          );
          await editor.saveVersionCatalog(songId, versionCatalog);
        }
      }
      final sequence = await editor.loadSequence(
        songId,
        versionId: versionCatalog.activeId,
      );
      await repository.markOpened(songId);
      final quality = await _loadOrBuildQuality(
        ref.watch(songFileStorageProvider),
        songId: songId,
        score: score,
        sourceXml: sourceXml,
      );
      return DigitalScoreData(
        song: song,
        score: score,
        sourceXml: sourceXml,
        versionCatalog: versionCatalog,
        activeVersionScore: activeVersionScore,
        activeVersionXml: activeVersionXml,
        sequence: sequence,
        arrangement: arrangement,
        originalFifths: originalFifths,
        quality: quality,
        omrJobId: await ref.watch(songFileStorageProvider).loadOmrJobId(songId),
      );
    });

Future<OmrQualityReport> _loadOrBuildQuality(
  SongFileStorage storage, {
  required String songId,
  required MusicScore score,
  required String sourceXml,
}) async {
  final raw = await storage.loadOmrQuality(songId);
  if (raw != null && raw.isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final report = OmrQualityReport.fromJson(
          Map<String, Object?>.from(decoded),
        );
        if (report.version >= OmrQualityReport.currentVersion) {
          return report;
        }
      }
    } on Object {
      // Rebuild if the sidecar is unreadable.
    }
  }
  var report = const OmrQualityAnalyzer().analyze(score, sourceXml: sourceXml);
  final original = await storage.loadOmrSource(songId);
  if (original != null && original.fileName.toLowerCase().endsWith('.pdf')) {
    try {
      final text = await const OmrPdfText().extract(
        Uint8List.fromList(original.bytes),
      );
      report = report.copyWith(
        sourceMatch: OmrSourceMatch.compare(
          referenceText: text,
          score: score,
          musicXml: sourceXml,
        ),
      );
    } on Object {
      // Scanned PDFs or missing text layers skip the match.
    }
  }
  await storage.saveOmrQuality(songId, jsonEncode(report.toJson()));
  return report;
}
