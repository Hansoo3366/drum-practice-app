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

  /// Records that the original of a converted song already has the AI
  /// review's corrections in it (see [OmrConvertService.importResult]).
  Future<void> saveOmrOriginalHasAi(String songId) async {
    await _saveSidecar(omrOriginalStagePathFor(songId), 'ai');
  }

  Future<bool> loadOmrOriginalHasAi(String songId) async =>
      (await _loadSidecar(omrOriginalStagePathFor(songId)))?.trim() == 'ai';

  String omrOriginalStagePathFor(String songId) =>
      path.join('omr_original', '$songId.txt');

  String omrAiReviewPathFor(String songId) =>
      path.join('omr_ai_review', '$songId.json');

  String omrQualityPathFor(String songId) =>
      path.join('omr_quality', '$songId.json');

  String omrValidationPathFor(String songId) =>
      path.join('omr_validation', '$songId.json');

  String omrAnnotationsPathFor(String songId) =>
      path.join('omr_annotations', '$songId.json');

  String omrCorrectionsPathFor(String songId) =>
      path.join('omr_corrections', '$songId.json');

  /// Where the crop [name] of a song is kept. A name is a plain file name:
  /// it comes from a server report.
  String omrSuspectImagePathFor(String songId, String name) {
    final file = path.basename(name);
    if (!RegExp(r'^[\w-][\w.-]*\.png$').hasMatch(file)) {
      throw FormatException('Not a crop name: $name');
    }
    return path.join('omr_suspects', songId, file);
  }

  /// Where a staff-line image [name] of a song's original is kept.
  String omrSystemImagePathFor(String songId, String name) {
    final file = path.basename(name);
    if (!RegExp(r'^[\w-][\w.-]*\.jpg$').hasMatch(file)) {
      throw FormatException('Not a staff-line image name: $name');
    }
    return path.join('omr_systems', songId, file);
  }

  String omrLayoutPathFor(String songId) =>
      path.join('omr_layout', '$songId.json');

  /// Where each measure is on the original, as the conversion found it.
  Future<void> saveOmrLayout(String songId, String jsonContent) async {
    await _saveSidecar(omrLayoutPathFor(songId), jsonContent);
  }

  Future<String?> loadOmrLayout(String songId) async {
    return _loadSidecar(omrLayoutPathFor(songId));
  }

  /// One staff line of the original page, as the server cut it.
  Future<void> saveOmrSystemImage(
    String songId,
    String name,
    List<int> bytes,
  ) async {
    await replaceFile(omrSystemImagePathFor(songId, name), bytes);
  }

  Future<List<int>?> loadOmrSystemImage(String songId, String name) async {
    final file = await resolve(omrSystemImagePathFor(songId, name));
    if (!await file.exists() || await file.length() == 0) return null;
    return file.readAsBytes();
  }

  /// Removes what a conversion left with a song: crops, staff lines of the
  /// original, review marks and the list of separated annotations.
  Future<void> deleteOmrReviewFiles(String songId) async {
    for (final folder in ['omr_suspects', 'omr_systems']) {
      final images = (await resolve(path.join(folder, songId, 'x'))).parent;
      if (await images.exists()) await images.delete(recursive: true);
    }
    await delete(omrLayoutPathFor(songId));
    await delete(omrReviewStatePathFor(songId));
    await delete(omrAnnotationsPathFor(songId));
    await delete(omrValidationPathFor(songId));
    await delete(omrOriginalStagePathFor(songId));
  }

  String omrReviewStatePathFor(String songId) =>
      path.join('omr_review', '$songId.json');

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

  /// The handwriting the conversion server separated from the score.
  Future<void> saveOmrAnnotations(String songId, String jsonContent) async {
    await _saveSidecar(omrAnnotationsPathFor(songId), jsonContent);
  }

  Future<String?> loadOmrAnnotations(String songId) async {
    return _loadSidecar(omrAnnotationsPathFor(songId));
  }

  /// The original crop around one suspect measure, as the server cut it.
  Future<void> saveOmrSuspectImage(
    String songId,
    String name,
    List<int> bytes,
  ) async {
    await replaceFile(omrSuspectImagePathFor(songId, name), bytes);
  }

  Future<List<int>?> loadOmrSuspectImage(String songId, String name) async {
    final file = await resolve(omrSuspectImagePathFor(songId, name));
    if (!await file.exists() || await file.length() == 0) return null;
    return file.readAsBytes();
  }

  /// Which suspect measures the user has looked at and accepted.
  Future<void> saveOmrReviewState(String songId, String jsonContent) async {
    await _saveSidecar(omrReviewStatePathFor(songId), jsonContent);
  }

  Future<String?> loadOmrReviewState(String songId) async {
    return _loadSidecar(omrReviewStatePathFor(songId));
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

  /// The directories whose entries are not a song's sidecars: the score and
  /// audio files themselves (the library records their paths) and uploads
  /// of conversions still running.
  static const _notSidecars = {'scores', 'audio', 'omr_pending', 'jam_host'};

  /// Everything kept beside a song's score file. Each is a file
  /// `<songId>.<extension>` or a folder `<songId>` in a directory of its
  /// own: versions, sections and playing orders, key, accompaniment, the
  /// conversion's reports and pictures of the original.
  Future<List<FileSystemEntity>> _sidecars(String songId) async {
    final root = await _rootDirectoryProvider();
    if (!await root.exists()) return const [];
    final found = <FileSystemEntity>[];
    await for (final directory in root.list()) {
      if (directory is! Directory ||
          _notSidecars.contains(path.basename(directory.path))) {
        continue;
      }
      await for (final entry in directory.list()) {
        final name = path.basename(entry.path);
        if (entry is Directory ? name == songId : name.startsWith('$songId.')) {
          found.add(entry);
        }
      }
    }
    return found;
  }

  /// Gives the copy [toSongId] of a song what [fromSongId] has beside its
  /// score file, so the copy opens as the song does: same versions with the
  /// same one active, same sections, same review.
  Future<void> copySongSidecars(String fromSongId, String toSongId) async {
    for (final entry in await _sidecars(fromSongId)) {
      final name = path.basename(entry.path);
      final target = path.join(
        entry.parent.path,
        '$toSongId${name.substring(fromSongId.length)}',
      );
      if (entry is File) {
        await entry.copy(target);
      } else if (entry is Directory) {
        await for (final item in entry.list(recursive: true)) {
          if (item is! File) continue;
          final copy = File(
            path.join(target, path.relative(item.path, from: entry.path)),
          );
          await copy.parent.create(recursive: true);
          await item.copy(copy.path);
        }
      }
    }
  }

  /// Removes what a deleted song left beside its score file.
  Future<void> deleteSongSidecars(String songId) async {
    for (final entry in await _sidecars(songId)) {
      await entry.delete(recursive: true);
    }
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
