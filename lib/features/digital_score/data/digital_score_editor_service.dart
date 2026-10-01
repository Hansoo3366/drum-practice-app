import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_profile.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_transpose.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_version.dart';
import 'package:path/path.dart' as path;

class DigitalScoreEditorService {
  const DigitalScoreEditorService({
    required SongFileStorage storage,
    MusicXmlCodec codec = const MusicXmlCodec(),
  }) : _storage = storage,
       _codec = codec;

  final SongFileStorage _storage;
  final MusicXmlCodec _codec;

  Future<void> save({
    required String songId,
    required String relativePath,
    required MusicScore score,
    PlaybackSequence sequence = PlaybackSequence.empty,
    ArrangementProfile arrangement = ArrangementProfile.off,
    String versionId = scoreVersionOriginalId,
  }) async {
    final bytes = _codec.encode(score, MusicXmlFileFormat.musicXml);
    _codec.decode(bytes, fileName: 'score.musicxml');
    if (versionId == scoreVersionOriginalId) {
      final format = path.extension(relativePath).toLowerCase() == '.mxl'
          ? MusicXmlFileFormat.mxl
          : MusicXmlFileFormat.musicXml;
      final originalBytes = format == MusicXmlFileFormat.musicXml
          ? bytes
          : _codec.encode(score, format);
      _codec.decode(originalBytes, fileName: relativePath);
      await _storage.replaceFile(relativePath, originalBytes);
    } else {
      await _storage.saveScoreVersionBytes(songId, versionId, bytes);
      if (versionId == scoreVersionLegacyPerformanceId) {
        await _storage.savePerformanceScore(songId, bytes);
      }
    }
    await saveSidecars(
      songId: songId,
      versionId: versionId,
      sequence: sequence,
      arrangement: arrangement,
    );
  }

  /// Saves playback order and accompaniment without touching the score file,
  /// so markings the codec does not model stay in the MusicXML.
  Future<void> saveSidecars({
    required String songId,
    required PlaybackSequence sequence,
    required ArrangementProfile arrangement,
    String versionId = scoreVersionOriginalId,
  }) async {
    await saveSequence(
      songId: songId,
      versionId: versionId,
      sequence: sequence,
    );
    await _storage.saveArrangementProfile(
      songId,
      jsonEncode(arrangement.toJson()),
    );
  }

  Future<MusicScore?> loadPerformanceScore(String songId) async {
    final bytes = await _storage.loadPerformanceScoreBytes(songId);
    if (bytes == null) return null;
    return _codec.decode(
      bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
      fileName: 'performance.musicxml',
    );
  }

  Future<bool> hasPerformanceScore(String songId) {
    return _storage.hasPerformanceScore(songId);
  }

  Future<MusicScore> ensurePerformanceScore({
    required String songId,
    required MusicScore original,
  }) async {
    final existing = await loadPerformanceScore(songId);
    if (existing != null) return existing;
    final bytes = _codec.encode(original, MusicXmlFileFormat.musicXml);
    await _storage.savePerformanceScore(songId, bytes);
    return original;
  }

  Future<ScoreVersionCatalog> loadVersionCatalog(String songId) async {
    final raw = await _storage.loadScoreVersionManifest(songId);
    if (raw == null || raw.trim().isEmpty) return ScoreVersionCatalog.empty;
    late final ScoreVersionCatalog catalog;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return ScoreVersionCatalog.empty;
      catalog = ScoreVersionCatalog.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } on Object {
      // A cancelled/interrupted version write must not prevent the score from
      // opening. The original score remains the safe fallback.
      return ScoreVersionCatalog.empty;
    }
    // Drop legacy auto-migrated "performance" unless the user renamed it.
    final filtered = catalog.versions
        .where((version) => version.id != scoreVersionLegacyPerformanceId)
        .toList();
    if (filtered.length == catalog.versions.length) return catalog;
    final cleaned = catalog.copyWith(
      versions: filtered,
      activeId: catalog.activeId == scoreVersionLegacyPerformanceId
          ? scoreVersionOriginalId
          : catalog.activeId,
    );
    await saveVersionCatalog(songId, cleaned);
    return cleaned;
  }

  Future<ScoreVersionCatalog> deleteVersion({
    required String songId,
    required String versionId,
    required ScoreVersionCatalog catalog,
  }) async {
    if (versionId == scoreVersionOriginalId) return catalog;
    await _storage.deleteScoreVersion(songId, versionId);
    final next = catalog.copyWith(
      versions: [
        for (final version in catalog.versions)
          if (version.id != versionId) version,
      ],
      activeId: catalog.activeId == versionId
          ? scoreVersionOriginalId
          : catalog.activeId,
    );
    await saveVersionCatalog(songId, next);
    return next;
  }

  Future<void> saveVersionCatalog(String songId, ScoreVersionCatalog catalog) {
    return _storage.saveScoreVersionManifest(
      songId,
      jsonEncode(catalog.toJson()),
    );
  }

  Future<MusicScore?> loadVersionScore({
    required String songId,
    required String versionId,
  }) async {
    if (versionId == scoreVersionOriginalId) return null;
    final bytes = await _storage.loadScoreVersionBytes(songId, versionId);
    if (bytes == null && versionId == scoreVersionLegacyPerformanceId) {
      return loadPerformanceScore(songId);
    }
    if (bytes == null) return null;
    return _codec.decode(
      bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
      fileName: '$versionId.musicxml',
    );
  }

  Future<ScoreVersionCatalog> addVersion({
    required String songId,
    required MusicScore source,
    required ScoreVersionCatalog catalog,
    required String name,
    String? versionId,
  }) async {
    final id =
        versionId ??
        'v${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    final bytes = _codec.encode(source, MusicXmlFileFormat.musicXml);
    try {
      await _storage.saveScoreVersionBytes(songId, id, bytes);
      final next = catalog.copyWith(
        activeId: id,
        versions: [
          ...catalog.versions,
          ScoreVersionRef(id: id, name: name),
        ],
      );
      await saveVersionCatalog(songId, next);
      return next;
    } on Object {
      // Do not leave an orphaned score file if the manifest write fails.
      try {
        await _storage.deleteScoreVersion(songId, id);
      } on Object {
        // Preserve the original failure for the UI; cleanup is best effort.
      }
      rethrow;
    }
  }

  /// Preserve directions, harmony, lyrics and other XML outside edited notes.
  Future<ScoreVersionCatalog> addXmlVersion({
    required String songId,
    required String musicXml,
    required ScoreVersionCatalog catalog,
    required String name,
    String? origin,
  }) async {
    _codec.decodeXml(musicXml);
    final current = await loadVersionCatalog(songId);
    if (jsonEncode(current.toJson()) != jsonEncode(catalog.toJson())) {
      throw const FormatException('버전이 변경되었습니다. 악보를 다시 여세요.');
    }
    final id = 'ai${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    try {
      await _storage.saveScoreVersionBytes(songId, id, utf8.encode(musicXml));
      final next = catalog.copyWith(
        activeId: id,
        versions: [
          ...catalog.versions,
          ScoreVersionRef(id: id, name: name, origin: origin),
        ],
      );
      await saveVersionCatalog(songId, next);
      return next;
    } on Object {
      try {
        await _storage.deleteScoreVersion(songId, id);
      } on Object {
        /* Best effort. */
      }
      rethrow;
    }
  }

  Future<String?> loadVersionXml(String songId, String versionId) async {
    final bytes = await _storage.loadScoreVersionBytes(songId, versionId);
    return bytes == null
        ? null
        : _codec.xmlString(
            Uint8List.fromList(bytes),
            fileName: '$versionId.musicxml',
          );
  }

  /// Playback order of one score version. A version without its own order
  /// starts from the original's, since proofread versions keep the same bars.
  Future<PlaybackSequence> loadSequence(
    String songId, {
    String versionId = scoreVersionOriginalId,
  }) async {
    String? raw;
    if (versionId != scoreVersionOriginalId) {
      raw = await _storage.loadPlaybackSequence(songId, versionId: versionId);
    }
    raw ??= await _storage.loadPlaybackSequence(songId);
    if (raw == null || raw.trim().isEmpty) return PlaybackSequence.empty;
    return PlaybackSequence.fromJson(jsonDecode(raw));
  }

  Future<void> saveSequence({
    required String songId,
    required PlaybackSequence sequence,
    String versionId = scoreVersionOriginalId,
  }) {
    return _storage.savePlaybackSequence(
      songId,
      jsonEncode(sequence.toJson()),
      versionId: versionId == scoreVersionOriginalId ? null : versionId,
    );
  }

  Future<ArrangementProfile> loadArrangement(String songId) async {
    final raw = await _storage.loadArrangementProfile(songId);
    if (raw == null || raw.trim().isEmpty) return ArrangementProfile.off;
    return ArrangementProfile.fromJson(jsonDecode(raw));
  }

  Future<int> loadOrCaptureOriginalFifths({
    required String songId,
    required MusicScore score,
  }) async {
    final stored = _originalFifthsFrom(await _storage.loadOriginalKey(songId));
    if (stored != null) return stored;
    final fifths = wrapKeyFifths(concertKeyFifths(score));
    await _storage.saveOriginalKey(songId, jsonEncode({'fifths': fifths}));
    return fifths;
  }
}

int? _originalFifthsFrom(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final fifths = decoded['fifths'];
    if (fifths is! int) return null;
    return wrapKeyFifths(fifths);
  } on Object {
    return null;
  }
}

final digitalScoreEditorServiceProvider = Provider<DigitalScoreEditorService>((
  ref,
) {
  return DigitalScoreEditorService(storage: ref.watch(songFileStorageProvider));
});
