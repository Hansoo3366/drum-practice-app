import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/features/digital_score/data/digital_score_editor_service.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_import_service.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_convert_client.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_convert_config.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_quality_analyzer.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_review.dart';
import 'package:page_a_diddle/features/library/domain/picked_local_file.dart';

/// The version [OmrConvertService.fetchAiVersion] adds when the AI review
/// did not finish with the conversion and is fetched afterwards. A
/// conversion whose review did finish has it in the original instead.
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

  /// The original crop around a suspect measure: the stored one, or fetched
  /// from the server while it still has the job (songs converted earlier).
  Future<Uint8List?> suspectImage(String songId, String name) async {
    try {
      if (await _storage.loadOmrSuspectImage(songId, name) case final stored?) {
        return Uint8List.fromList(stored);
      }
    } on FormatException {
      return null;
    }
    final jobId = await _storage.loadOmrJobId(songId);
    if (jobId == null) return null;
    try {
      final image = await _client.jobSuspectImage(jobId, name);
      if (image != null) {
        await _storage.saveOmrSuspectImage(songId, name, image);
      }
      return image;
    } on Object {
      return null;
    }
  }

  static const _downloads = 6;

  /// Fetches [names] a few at a time: a long song has dozens of images. One
  /// that cannot be fetched or kept must not fail the import; the screens
  /// that show it fetch it again.
  static Future<void> _inBatches(
    Iterable<String> names,
    Future<void> Function(String name) fetch,
  ) async {
    final all = names.toList();
    for (var at = 0; at < all.length; at += _downloads) {
      await Future.wait([
        for (final name in all.skip(at).take(_downloads))
          () async {
            try {
              await fetch(name);
            } on Object {
              // Best effort.
            }
          }(),
      ]);
    }
  }

  /// Where the measures of a converted song are on its original, or null
  /// when that is not known: the stored layout, or fetched from the server
  /// while it still has the job (songs converted earlier).
  Future<List<List<OmrBarPlace?>>?> barPlaces(String songId) async {
    try {
      var layout = await _storage.loadOmrLayout(songId);
      if (layout == null) {
        final jobId = await _storage.loadOmrJobId(songId);
        if (jobId == null) return null;
        layout = await _client.jobLayout(jobId);
        if (layout == null) return null;
        await _storage.saveOmrLayout(songId, layout);
      }
      final places = omrLayout(layout);
      return places.isEmpty ? null : places;
    } on Object {
      return null;
    }
  }

  /// A staff line of the original: the stored image, or fetched from the
  /// server while it still has the job.
  Future<Uint8List?> systemImage(String songId, String name) async {
    try {
      if (await _storage.loadOmrSystemImage(songId, name) case final stored?) {
        return Uint8List.fromList(stored);
      }
      final jobId = await _storage.loadOmrJobId(songId);
      if (jobId == null) return null;
      final image = await _client.jobSystemImage(jobId, name);
      if (image != null) {
        await _storage.saveOmrSystemImage(songId, name, image);
      }
      return image;
    } on Object {
      return null;
    }
  }

  Future<String> importResult({
    required String jobId,
    required String title,
    String? folderId,
    PickedLocalFile? original,
  }) async {
    final mxl = await _client.jobResult(jobId);
    final corrections = await _client.jobCorrections(jobId);
    final validation = await _client.jobValidation(jobId);
    final annotations = await _client.jobAnnotations(jobId);
    final ai = await _client.jobAiResult(jobId);
    final aiReview = await _client.jobAiReview(jobId);
    // The score the user asked for is the finished one: read by the engine,
    // corrected by the server's rules and, when the AI review ran, by it.
    // That is the original. The stages before it are not versions to choose
    // from (the user's decision, D-220); what each stage changed is kept in
    // the correction history and the review.
    final finished = ai ?? mxl;
    final songId = await _importer.importMusicXml(
      file: PickedLocalFile(name: '$title.mxl', bytes: finished),
      title: title,
      folderId: folderId,
    );
    if (corrections != null) {
      await _storage.saveOmrCorrections(songId, corrections);
    }
    if (ai != null) {
      // No "AI 보정 받기" for this song: it already has it.
      await _storage.saveOmrOriginalHasAi(songId);
    }
    if (aiReview != null) {
      await _storage.saveOmrAiReview(songId, aiReview);
    }
    await _storage.saveOmrJobId(songId, jobId);
    if (validation != null) {
      await _storage.saveOmrValidation(songId, validation);
      // The crops go with the song: the server forgets a job after a while.
      await _inBatches(omrSuspectImageNames(validation), (name) async {
        if (await _client.jobSuspectImage(jobId, name) case final image?) {
          await _storage.saveOmrSuspectImage(songId, name, image);
        }
      });
    }
    // The original of every measure, for proofreading against it later.
    if (await _client.jobLayout(jobId) case final layout?) {
      await _storage.saveOmrLayout(songId, layout);
      await _inBatches(omrSystemImageNames(layout), (name) async {
        if (await _client.jobSystemImage(jobId, name) case final image?) {
          await _storage.saveOmrSystemImage(songId, name, image);
        }
      });
    }
    // What the server took out of the upload (pen, highlighter) stays with
    // the song: the original keeps it, the score no longer has it.
    if (annotations != null) {
      await _storage.saveOmrAnnotations(songId, annotations);
    }
    if (original?.bytes != null) {
      await _storage.saveOmrSource(
        songId: songId,
        fileName: original!.name,
        bytes: original.bytes!,
      );
    }
    final xml = codec.xmlString(finished, fileName: '$title.mxl');
    final report = analyzer.analyze(codec.decodeXml(xml), sourceXml: xml);
    await _storage.saveOmrQuality(songId, jsonEncode(report.toJson()));
    return songId;
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

/// This install's secret for the conversion server, with the device's other
/// credentials. One per server address.
class _SecureOmrSecretStore implements OmrClientSecretStore {
  const _SecureOmrSecretStore();

  static const _storage = FlutterSecureStorage();
  static const _key = 'omr_client_secret:${OmrConvertConfig.defaultBaseUrl}';

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } on Object {
      // A store that cannot be read: register again.
      return null;
    }
  }

  @override
  Future<void> write(String secret) async {
    try {
      await _storage.write(key: _key, value: secret);
    } on Object {
      // Kept for this run only.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } on Object {
      // Overwritten by the next registration.
    }
  }
}

final omrConvertClientProvider = Provider<OmrConvertClient>((ref) {
  return OmrConvertClient(secrets: const _SecureOmrSecretStore());
});

final omrConvertServiceProvider = Provider<OmrConvertService>((ref) {
  return OmrConvertService(
    client: ref.watch(omrConvertClientProvider),
    importer: ref.watch(musicXmlImportServiceProvider),
    storage: ref.watch(songFileStorageProvider),
  );
});
