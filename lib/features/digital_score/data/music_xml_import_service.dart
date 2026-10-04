import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/core/storage/storage_provider.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/blank_piano_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/library/data/song_repository.dart';
import 'package:page_a_diddle/features/library/domain/picked_local_file.dart';
import 'package:page_a_diddle/features/library/domain/score_type.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

typedef MusicXmlIdGenerator = String Function();
typedef MusicXmlClock = DateTime Function();

class MusicXmlImportService {
  MusicXmlImportService({
    required SongRepository repository,
    required SongFileStorage storage,
    MusicXmlCodec codec = const MusicXmlCodec(),
    MusicXmlIdGenerator? idGenerator,
    MusicXmlClock? clock,
  }) : _repository = repository,
       _storage = storage,
       _codec = codec,
       _idGenerator = idGenerator ?? const Uuid().v4,
       _clock = clock ?? DateTime.now;

  final SongRepository _repository;
  final SongFileStorage _storage;
  final MusicXmlCodec _codec;
  final MusicXmlIdGenerator _idGenerator;
  final MusicXmlClock _clock;

  Future<String> createBlank({
    required String title,
    String? artist,
    int? defaultTempo,
    String? folderId,
  }) {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw const FormatException('곡명이 필요합니다.');
    }
    final score = blankPianoScore(
      title: normalizedTitle,
      composer: _nonEmpty(artist),
      tempoBpm: defaultTempo?.toDouble(),
    );
    return importMusicXml(
      file: PickedLocalFile(
        name: 'score.musicxml',
        bytes: _codec.encode(score, MusicXmlFileFormat.musicXml),
      ),
      title: normalizedTitle,
      artist: artist,
      defaultTempo: defaultTempo,
      sourceProvider: StorageProvider.local,
      folderId: folderId,
    );
  }

  /// Reads [file] as a score. Whatever is wrong with it (empty, cut off,
  /// not MusicXML at all, values no score can have) is one thing to the
  /// user: this file cannot be read as a score.
  Future<MusicScore> inspect(PickedLocalFile file) async {
    final bytes = await _read(file);
    try {
      return _codec.decode(bytes, fileName: file.name);
    } on Object {
      throw const FormatException(
        '악보로 읽을 수 없는 파일입니다. MusicXML(.musicxml, .mxl, .xml) 파일인지 확인하세요.',
      );
    }
  }

  Future<String> importMusicXml({
    required PickedLocalFile file,
    String? title,
    String? artist,
    int? defaultTempo,
    StorageProvider sourceProvider = StorageProvider.local,
    String? folderId,
  }) async {
    if (defaultTempo != null && (defaultTempo < 40 || defaultTempo > 240)) {
      throw const FormatException('BPM 40~240');
    }

    final score = await inspect(file);
    final normalizedTitle =
        _nonEmpty(title) ??
        _nonEmpty(score.title) ??
        path.basenameWithoutExtension(file.name);
    if (normalizedTitle.trim().isEmpty) {
      throw const FormatException('곡명이 필요합니다.');
    }
    final metadataTempo = score.tempoBpm?.round();
    final resolvedTempo =
        defaultTempo ??
        (metadataTempo != null && metadataTempo >= 40 && metadataTempo <= 240
            ? metadataTempo
            : null);
    final id = _idGenerator();
    final relativePath = await _storage.storeMusicXml(source: file, songId: id);
    final now = _clock();

    try {
      await _repository.saveSong(
        SongsCompanion.insert(
          id: id,
          title: normalizedTitle.trim(),
          artist: Value(_nonEmpty(artist) ?? _nonEmpty(score.composer)),
          defaultTempo: Value(resolvedTempo),
          scoreType: Value(ScoreType.musicXml.key),
          sourcePath: relativePath,
          sourceProvider: Value(sourceProvider.key),
          folderId: Value(folderId),
          createdAt: now,
          updatedAt: now,
        ),
      );
    } on Object {
      await _storage.delete(relativePath);
      rethrow;
    }
    return id;
  }

  Future<Uint8List> _read(PickedLocalFile file) async {
    if (file.bytes case final bytes?) return bytes;
    final filePath = file.path;
    if (filePath == null) {
      throw const FormatException('MusicXML 파일을 읽을 수 없습니다.');
    }
    return File(filePath).readAsBytes();
  }

  String? _nonEmpty(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

final musicXmlImportServiceProvider = Provider<MusicXmlImportService>((ref) {
  return MusicXmlImportService(
    repository: ref.watch(songRepositoryProvider),
    storage: ref.watch(songFileStorageProvider),
  );
});
