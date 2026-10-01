import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/features/digital_score/data/digital_score_editor_service.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_import_service.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_convert_client.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_quality_analyzer.dart';
import 'package:page_a_diddle/features/library/domain/picked_local_file.dart';

/// Name of the version holding the server's automatic OMR corrections.
const autoCorrectedVersionName = '자동 보정';

/// The server's AI review applied (chords and lyrics); kept as a separate
/// version the user opens to compare, never the one that opens first.
const aiCorrectedVersionName = 'AI 보정';

/// Origin of the AI version in the version catalog.
const aiVersionOrigin = 'omr-ai';

/// What [OmrConvertService.fetchAiVersion] got from the server.
enum OmrAiFetch {
  /// The AI version was added (and opened).
  added,

  /// The review ran and suggested nothing to change.
  unchanged,

  /// The server no longer has the job; convert the score again.
  expired,

  /// The server cannot run the AI review now (no API key or credit).
  unavailable,

  /// The AI review failed.
  failed,
}

class OmrConvertService {
  OmrConvertService({
    required OmrConvertClient client,
    required MusicXmlImportService importer,
    required SongFileStorage storage,
    this.codec = const MusicXmlCodec(),
    this.analyzer = const OmrQualityAnalyzer(),
  }) : _client = client,
       _importer = importer,
       _storage = storage;

  final OmrConvertClient _client;
  final MusicXmlImportService _importer;
  final SongFileStorage _storage;
  final MusicXmlCodec codec;
  final OmrQualityAnalyzer analyzer;

  Future<OmrRemoteJob> start({
    required PickedLocalFile source,
    OmrRecognitionProfile profile = OmrRecognitionProfile.standard,
  }) async {
    final bytes = await _read(source);
    return _client.startConvert(
      fileName: source.name,
      bytes: bytes,
      profile: profile,
    );
  }

  Future<OmrRemoteJob> status(String jobId) => _client.jobStatus(jobId);

  /// Fetches the AI version of a converted song again: from the finished
  /// review, or by asking the server to run the review once more (it may have
  /// failed at import, e.g. for lack of API credit). Waits while it runs.
  Future<OmrAiFetch> fetchAiVersion(
    String songId, {
    Duration pollInterval = const Duration(seconds: 3),
    Duration limit = const Duration(minutes: 10),
  }) async {
    final jobId = await _storage.loadOmrJobId(songId);
    if (jobId == null) return OmrAiFetch.expired;
    try {
      var job = await _client.jobStatus(jobId);
      if (job.ai == 'off' || job.ai == 'error') {
        job = await _client.retryAiReview(jobId);
      }
      final deadline = DateTime.now().add(limit);
      while (job.ai == 'running') {
        if (DateTime.now().isAfter(deadline)) return OmrAiFetch.failed;
        await Future<void>.delayed(pollInterval);
        job = await _client.jobStatus(jobId);
      }
      if (job.ai == 'unchanged') return OmrAiFetch.unchanged;
      if (job.ai != 'done') return OmrAiFetch.failed;
      final ai = await _client.jobAiResult(jobId);
      if (ai == null) return OmrAiFetch.failed;
      final editor = DigitalScoreEditorService(storage: _storage, codec: codec);
      final catalog = await editor.loadVersionCatalog(songId);
      await editor.addXmlVersion(
        songId: songId,
        musicXml: codec.xmlString(ai, fileName: '$songId.ai.mxl'),
        catalog: catalog,
        name: aiCorrectedVersionName,
        origin: aiVersionOrigin,
      );
      if (await _client.jobAiReview(jobId) case final review?) {
        await _storage.saveOmrAiReview(songId, review);
      }
      return OmrAiFetch.added;
    } on OmrJobNotFoundException {
      return OmrAiFetch.expired;
    } on OmrConvertException {
      return OmrAiFetch.unavailable;
    }
  }

  Future<String> importResult({
    required String jobId,
    required String title,
    String? folderId,
    PickedLocalFile? original,
  }) async {
    final mxl = await _client.jobResult(jobId);
    final raw = await _client.jobRawResult(jobId);
    final corrections = await _client.jobCorrections(jobId);
    final validation = await _client.jobValidation(jobId);
    final ai = await _client.jobAiResult(jobId);
    final aiReview = await _client.jobAiReview(jobId);
    // The engine's own export stays the original; the server's corrections
    // become a version on top, so the user can always go back (OMR spec §19).
    final corrected = raw != null && !_sameBytes(raw, mxl);
    final songId = await _importer.importMusicXml(
      file: PickedLocalFile(name: '$title.mxl', bytes: corrected ? raw : mxl),
      title: title,
      folderId: folderId,
    );
    if (corrected) {
      final editor = DigitalScoreEditorService(storage: _storage, codec: codec);
      await editor.addXmlVersion(
        songId: songId,
        musicXml: codec.xmlString(mxl, fileName: '$title.mxl'),
        catalog: await editor.loadVersionCatalog(songId),
        name: autoCorrectedVersionName,
      );
      if (corrections != null) {
        await _storage.saveOmrCorrections(songId, corrections);
      }
    }
    if (ai != null) {
      final editor = DigitalScoreEditorService(storage: _storage, codec: codec);
      final before = await editor.loadVersionCatalog(songId);
      final after = await editor.addXmlVersion(
        songId: songId,
        musicXml: codec.xmlString(ai, fileName: '$title.ai.mxl'),
        catalog: before,
        name: aiCorrectedVersionName,
        origin: aiVersionOrigin,
      );
      // Open on the rule-corrected (or original) score; AI is one tap away.
      await editor.saveVersionCatalog(
        songId,
        after.copyWith(activeId: before.activeId),
      );
    }
    if (aiReview != null) {
      await _storage.saveOmrAiReview(songId, aiReview);
    }
    await _storage.saveOmrJobId(songId, jobId);
    if (validation != null) {
      await _storage.saveOmrValidation(songId, validation);
    }
    if (original?.bytes != null) {
      await _storage.saveOmrSource(
        songId: songId,
        fileName: original!.name,
        bytes: original.bytes!,
      );
    }
    final xml = codec.xmlString(mxl, fileName: '$title.mxl');
    final report = analyzer.analyze(codec.decodeXml(xml), sourceXml: xml);
    await _storage.saveOmrQuality(songId, jsonEncode(report.toJson()));
    return songId;
  }

  static bool _sameBytes(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<Uint8List> _read(PickedLocalFile file) async {
    if (file.bytes case final bytes?) return bytes;
    final filePath = file.path;
    if (filePath == null) {
      throw const FormatException('변환할 파일을 읽을 수 없습니다.');
    }
    return File(filePath).readAsBytes();
  }
}

final omrConvertClientProvider = Provider<OmrConvertClient>((ref) {
  return OmrConvertClient();
});

final omrConvertServiceProvider = Provider<OmrConvertService>((ref) {
  return OmrConvertService(
    client: ref.watch(omrConvertClientProvider),
    importer: ref.watch(musicXmlImportServiceProvider),
    storage: ref.watch(songFileStorageProvider),
  );
});
