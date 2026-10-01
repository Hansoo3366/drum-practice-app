import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/features/library/domain/picked_local_file.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

typedef RootDirectoryProvider = Future<Directory> Function();

class SongFileStorage {
  SongFileStorage({RootDirectoryProvider? rootDirectoryProvider})
    : _rootDirectoryProvider =
          rootDirectoryProvider ?? getApplicationDocumentsDirectory;

  final RootDirectoryProvider _rootDirectoryProvider;

  String pdfPathFor(String songId) => path.join('scores', '$songId.pdf');

  String musicXmlPathFor(String songId, {required bool compressed}) =>
      path.join('scores', '$songId.${compressed ? 'mxl' : 'musicxml'}');

  Future<String> storePdf({
    required PickedLocalFile source,
    required String songId,
  }) async {
    final relativePath = await _store(
      source: source,
      directory: 'scores',
      fileName: path.basename(pdfPathFor(songId)),
      invalidMessage: 'PDF를 다시 선택하세요.',
    );
    final file = await resolve(relativePath);

    try {
      final reader = await file.open();
      try {
        final header = String.fromCharCodes(await reader.read(1024));
        if (!header.contains('%PDF-')) {
          throw const FormatException('PDF를 다시 선택하세요.');
        }
      } finally {
        await reader.close();
      }
    } on Object {
      await delete(relativePath);
      rethrow;
    }

    return relativePath;
  }

  Future<String> storeMusicXml({
    required PickedLocalFile source,
    required String songId,
  }) {
    final extension = path.extension(source.name).toLowerCase();
    if (!const {'.musicxml', '.mxl', '.xml'}.contains(extension)) {
      throw const FormatException('MusicXML 또는 MXL 파일을 선택하세요.');
    }
    final relativePath = musicXmlPathFor(
      songId,
      compressed: extension == '.mxl',
    );
    return _store(
      source: source,
      directory: 'scores',
      fileName: path.basename(relativePath),
      invalidMessage: 'MusicXML 파일을 다시 선택하세요.',
    );
  }

  String performanceScorePathFor(String songId) =>
      path.join('performance_scores', '$songId.musicxml');

  String scoreVersionManifestPathFor(String songId) =>
      path.join('score_versions', songId, 'manifest.json');

  String scoreVersionPathFor(String songId, String versionId) =>
      path.join('score_versions', songId, '$versionId.musicxml');

  String annotationPathFor(String songId) =>
      path.join('annotations', '$songId.json');

  /// Playback order for the original score, or for one score version.
  String playbackSequencePathFor(String songId, [String? versionId]) =>
      versionId == null
      ? path.join('playback_sequences', '$songId.json')
      : path.join('playback_sequences', songId, '$versionId.json');

  String arrangementProfilePathFor(String songId) =>
      path.join('arrangement_profiles', '$songId.json');

  String originalKeyPathFor(String songId) =>
      path.join('original_keys', '$songId.json');

  /// The server's AI review: suggestions per measure and what was applied.
  Future<void> saveOmrAiReview(String songId, String jsonContent) async {
    await _saveSidecar(omrAiReviewPathFor(songId), jsonContent);
  }

  Future<String?> loadOmrAiReview(String songId) async {
    return _loadSidecar(omrAiReviewPathFor(songId));
  }

  /// Id of the server job that converted the song, to fetch its AI version
  /// later.
  Future<void> saveOmrJobId(String songId, String jobId) async {
    await _saveSidecar(omrJobPathFor(songId), jobId);
  }

  Future<String?> loadOmrJobId(String songId) async {
    final id = (await _loadSidecar(omrJobPathFor(songId)))?.trim();
    return id == null || id.isEmpty ? null : id;
  }

  String omrJobPathFor(String songId) => path.join('omr_jobs', '$songId.txt');

  String omrAiReviewPathFor(String songId) =>
      path.join('omr_ai_review', '$songId.json');

  String omrQualityPathFor(String songId) =>
      path.join('omr_quality', '$songId.json');

  String omrValidationPathFor(String songId) =>
      path.join('omr_validation', '$songId.json');

  String omrCorrectionsPathFor(String songId) =>
      path.join('omr_corrections', '$songId.json');

  String omrSourcePathFor(String songId, String extension) =>
      path.join('omr_sources', '$songId$extension');

  Future<void> saveAnnotations(String songId, String jsonContent) async {
    final relativePath = annotationPathFor(songId);
    final fullPath = path.join(
      (await _rootDirectoryProvider()).path,
      relativePath,
    );
    final file = File(fullPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonContent);
  }

  Future<String?> loadAnnotations(String songId) async {
    final relativePath = annotationPathFor(songId);
    final fullPath = path.join(
      (await _rootDirectoryProvider()).path,
      relativePath,
    );
    final file = File(fullPath);
    if (await file.exists()) {
      return file.readAsString();
    }
    return null;
  }

  Future<void> savePlaybackSequence(
    String songId,
    String jsonContent, {
    String? versionId,
  }) async {
    await _saveSidecar(playbackSequencePathFor(songId, versionId), jsonContent);
  }

  Future<String?> loadPlaybackSequence(String songId, {String? versionId}) {
    return _loadSidecar(playbackSequencePathFor(songId, versionId));
  }

  Future<void> saveArrangementProfile(String songId, String jsonContent) async {
    await _saveSidecar(arrangementProfilePathFor(songId), jsonContent);
  }

  Future<String?> loadArrangementProfile(String songId) async {
    return _loadSidecar(arrangementProfilePathFor(songId));
  }

  Future<void> saveOriginalKey(String songId, String jsonContent) async {
    await _saveSidecar(originalKeyPathFor(songId), jsonContent);
  }

  Future<String?> loadOriginalKey(String songId) async {
    return _loadSidecar(originalKeyPathFor(songId));
  }

  Future<void> saveOmrQuality(String songId, String jsonContent) async {
    await _saveSidecar(omrQualityPathFor(songId), jsonContent);
  }

  Future<String?> loadOmrQuality(String songId) async {
    return _loadSidecar(omrQualityPathFor(songId));
  }

  /// Before/after items of the server's automatic OMR corrections.
  Future<void> saveOmrCorrections(String songId, String jsonContent) async {
    await _saveSidecar(omrCorrectionsPathFor(songId), jsonContent);
  }

  Future<String?> loadOmrCorrections(String songId) async {
    return _loadSidecar(omrCorrectionsPathFor(songId));
  }

  /// Suspect measures the server's rule-based validation found.
  Future<void> saveOmrValidation(String songId, String jsonContent) async {
    await _saveSidecar(omrValidationPathFor(songId), jsonContent);
  }

  Future<String?> loadOmrValidation(String songId) async {
    return _loadSidecar(omrValidationPathFor(songId));
  }

  Future<void> saveOmrSource({
    required String songId,
    required String fileName,
    required List<int> bytes,
  }) async {
    final extension = path.extension(fileName).toLowerCase();
    final safe = extension.isEmpty ? '.bin' : extension;
    await replaceFile(omrSourcePathFor(songId, safe), bytes);
    await _saveSidecar(
      path.join('omr_sources', '$songId.json'),
      jsonEncode({'fileName': fileName, 'extension': safe}),
    );
  }

  Future<({String fileName, List<int> bytes})?> loadOmrSource(
    String songId,
  ) async {
    final meta = await _loadSidecar(path.join('omr_sources', '$songId.json'));
    var extension = '.pdf';
    var fileName = '$songId.pdf';
    if (meta != null && meta.isNotEmpty) {
      try {
        final decoded = jsonDecode(meta);
        if (decoded is Map) {
          fileName = decoded['fileName']?.toString() ?? fileName;
          extension = decoded['extension']?.toString() ?? extension;
        }
      } on Object {
        // Fall through to the default name.
      }
    }
    final file = await resolve(omrSourcePathFor(songId, extension));
    if (!await file.exists() || await file.length() == 0) return null;
    return (fileName: fileName, bytes: await file.readAsBytes());
  }

  Future<bool> hasPerformanceScore(String songId) async {
    final file = await resolve(performanceScorePathFor(songId));
    return file.exists();
  }

  Future<List<int>?> loadPerformanceScoreBytes(String songId) async {
    final file = await resolve(performanceScorePathFor(songId));
    if (!await file.exists() || await file.length() == 0) return null;
    return file.readAsBytes();
  }

  Future<void> savePerformanceScore(String songId, List<int> bytes) async {
    await replaceFile(performanceScorePathFor(songId), bytes);
  }

  Future<void> deletePerformanceScore(String songId) async {
    await delete(performanceScorePathFor(songId));
  }

  Future<String?> loadScoreVersionManifest(String songId) {
    return _loadSidecar(scoreVersionManifestPathFor(songId));
  }

  Future<void> saveScoreVersionManifest(String songId, String jsonContent) {
    return replaceFile(
      scoreVersionManifestPathFor(songId),
      utf8.encode(jsonContent),
    );
  }

  Future<List<int>?> loadScoreVersionBytes(
    String songId,
    String versionId,
  ) async {
    final file = await resolve(scoreVersionPathFor(songId, versionId));
    if (!await file.exists() || await file.length() == 0) return null;
    return file.readAsBytes();
  }

  Future<void> saveScoreVersionBytes(
    String songId,
    String versionId,
    List<int> bytes,
  ) {
    return replaceFile(scoreVersionPathFor(songId, versionId), bytes);
  }

  Future<void> deleteScoreVersion(String songId, String versionId) async {
    await delete(scoreVersionPathFor(songId, versionId));
    await delete(playbackSequencePathFor(songId, versionId));
  }

  Future<void> _saveSidecar(String relativePath, String jsonContent) async {
    final fullPath = path.join(
      (await _rootDirectoryProvider()).path,
      relativePath,
    );
    final file = File(fullPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonContent);
  }

  Future<String?> _loadSidecar(String relativePath) async {
    final fullPath = path.join(
      (await _rootDirectoryProvider()).path,
      relativePath,
    );
    final file = File(fullPath);
    if (await file.exists()) {
      return file.readAsString();
    }
    return null;
  }

  Future<String> storeAudio({
    required PickedLocalFile source,
    required String songId,
  }) {
    final extension = path.extension(source.name).toLowerCase();
    return _store(
      source: source,
      directory: 'audio',
      fileName:
          '$songId-${DateTime.now().microsecondsSinceEpoch}'
          '${extension.isEmpty ? '.audio' : extension}',
      invalidMessage: '오디오를 다시 선택하세요.',
    );
  }

  Future<String> storeJamPdf({
    required List<int> bytes,
    required String songId,
  }) async {
    if (bytes.isEmpty) {
      throw const FormatException('빈 PDF입니다.');
    }
    final relativePath = path.join('jam_host', '$songId.pdf');
    final file = await resolve(relativePath);
    await file.parent.create(recursive: true);
    try {
      await file.writeAsBytes(bytes, flush: true);
      final header = String.fromCharCodes(bytes.take(1024));
      if (!header.contains('%PDF-') || await file.length() == 0) {
        throw const FormatException('PDF를 확인하세요.');
      }
      return relativePath;
    } on Object {
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    }
  }

  Future<String> _store({
    required PickedLocalFile source,
    required String directory,
    required String fileName,
    required String invalidMessage,
  }) async {
    final root = await _rootDirectoryProvider();
    final targetDirectory = Directory(path.join(root.path, directory));
    await targetDirectory.create(recursive: true);

    final relativePath = path.join(directory, fileName);
    final destination = File(path.join(root.path, relativePath));

    try {
      if (source.path case final sourcePath?) {
        await File(sourcePath).copy(destination.path);
      } else {
        await destination.writeAsBytes(source.bytes!, flush: true);
      }
      if (await destination.length() == 0) {
        throw FormatException(invalidMessage);
      }
    } on Object {
      if (await destination.exists()) {
        await destination.delete();
      }
      rethrow;
    }

    return relativePath;
  }

  Future<File> resolve(String relativePath) async {
    final root = await _rootDirectoryProvider();
    final normalized = path.normalize(relativePath);
    if (path.isAbsolute(normalized) ||
        normalized == '..' ||
        normalized.startsWith('..${path.separator}')) {
      throw const FormatException('파일 경로를 확인하세요.');
    }
    return File(path.join(root.path, normalized));
  }

  Future<void> delete(String relativePath) async {
    final file = await resolve(relativePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> replaceFile(String relativePath, List<int> bytes) async {
    if (bytes.isEmpty) {
      throw const FormatException('The replacement file is empty.');
    }
    final target = await resolve(relativePath);
    await target.parent.create(recursive: true);
    final suffix = DateTime.now().microsecondsSinceEpoch;
    final temporary = File('${target.path}.$suffix.tmp');
    final backup = File('${target.path}.$suffix.bak');
    var originalMoved = false;
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      if (await temporary.length() != bytes.length) {
        throw const FileSystemException('The replacement file is incomplete.');
      }
      if (await target.exists()) {
        await target.rename(backup.path);
        originalMoved = true;
      }
      await temporary.rename(target.path);
    } on Object {
      if (await target.exists()) await target.delete();
      if (originalMoved && await backup.exists()) {
        await backup.rename(target.path);
      }
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
    if (await backup.exists()) {
      try {
        await backup.delete();
      } on FileSystemException {
        // The score is already committed. A stale backup is safer than rollback.
      }
    }
  }
}

final songFileStorageProvider = Provider<SongFileStorage>((ref) {
  return SongFileStorage();
});
