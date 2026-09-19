import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/core/storage/storage_provider.dart';
import 'package:page_a_diddle/features/library/data/label_repository.dart';
import 'package:page_a_diddle/features/library/data/song_repository.dart';
import 'package:page_a_diddle/features/library/domain/library_filter.dart';
import 'package:page_a_diddle/features/library/domain/score_type.dart';
import 'package:page_a_diddle/features/storage/data/webdav_connection.dart';
import 'package:page_a_diddle/features/storage/domain/sync_status.dart';

void main() {
  late AppDatabase database;
  late SongRepository repository;
  late LabelRepository labels;
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('page_a_diddle_songs_');
    database = AppDatabase(NativeDatabase.memory());
    labels = LabelRepository(database);
    repository = SongRepository(
      database,
      labels,
      SongFileStorage(rootDirectoryProvider: () async => root),
    );
  });

  tearDown(() async {
    await database.close();
    await root.delete(recursive: true);
  });

  test('곡을 저장하고 검색 조건으로 조회한다', () async {
    final now = DateTime(2026, 8, 19);
    await repository.saveSong(
      SongsCompanion.insert(
        id: 'song-1',
        title: 'Atlantis Princess',
        artist: const Value('BoA'),
        defaultTempo: const Value(128),
        sourcePath: 'scores/atlantis.pdf',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final result = await repository.watchSongs(query: '128').first;

    expect(result, hasLength(1));
    expect(result.single.title, 'Atlantis Princess');
  });

  test('즐겨찾기 상태를 변경하고 필터링한다', () async {
    final now = DateTime(2026, 8, 19);
    await repository.saveSong(
      SongsCompanion.insert(
        id: 'song-1',
        title: 'Practice Song',
        sourcePath: 'scores/practice.pdf',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await repository.toggleFavorite('song-1');
    final result = await repository
        .watchSongs(filter: LibraryFilter.favorites)
        .first;

    expect(result.single.isFavorite, isTrue);
  });

  test('라벨로 검색한다', () async {
    final now = DateTime(2026, 8, 19);
    await repository.saveSong(
      SongsCompanion.insert(
        id: 'song-1',
        title: 'Groove Song',
        sourcePath: 'scores/groove.pdf',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await labels.setSongLabels(songId: 'song-1', labelNames: ['funk']);

    final result = await repository.watchSongs(query: 'funk').first;
    expect(result.map((song) => song.id), contains('song-1'));
  });

  test('곡 정보와 메모를 수정한다', () async {
    final now = DateTime(2026, 8, 19);
    await repository.saveSong(
      SongsCompanion.insert(
        id: 'song-1',
        title: 'Before',
        sourcePath: 'scores/practice.pdf',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await repository.updateMetadata(
      id: 'song-1',
      title: 'After',
      artist: 'Band',
      defaultTempo: 132,
      note: '2절 전 필인 주의',
    );
    final song = await database.select(database.songs).getSingle();

    expect(song.title, 'After');
    expect(song.artist, 'Band');
    expect(song.defaultTempo, 132);
    expect(song.note, '2절 전 필인 주의');
  });

  test('곡별 목표 BPM을 저장하고 해제한다', () async {
    final now = DateTime(2026, 8, 19);
    await repository.saveSong(
      SongsCompanion.insert(
        id: 'song-1',
        title: 'Target Song',
        sourcePath: 'scores/target.pdf',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await repository.updateTargetBpm(id: 'song-1', targetBpm: 140);
    expect((await repository.getSong('song-1'))!.targetBpm, 140);

    await repository.updateTargetBpm(id: 'song-1', targetBpm: null);
    expect((await repository.getSong('song-1'))!.targetBpm, equals(null));
    expect(
      () => repository.updateTargetBpm(id: 'song-1', targetBpm: 20),
      throwsArgumentError,
    );
  });

  test('악보를 열면 최근 열람 시각을 기록한다', () async {
    final now = DateTime(2026, 8, 19);
    await repository.saveSong(
      SongsCompanion.insert(
        id: 'song-1',
        title: 'Viewer Song',
        sourcePath: 'scores/viewer.pdf',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await repository.markOpened('song-1');
    final song = await repository.getSong('song-1');

    expect(song == null, isFalse);
    expect(song!.lastOpenedAt == null, isFalse);
  });

  test('WebDAV 폴더 조회 결과로 동기화와 누락 상태를 갱신한다', () async {
    final now = DateTime.utc(2026, 8, 20, 5);
    final directory = Uri.parse('https://example.com/webdav/');
    final remoteUri = directory.resolve('score.pdf');
    await repository.saveSong(
      SongsCompanion.insert(
        id: 'song-1',
        title: 'Remote Score',
        sourcePath: 'scores/remote.pdf',
        sourceProvider: Value(StorageProvider.webDav.key),
        remoteUri: Value(remoteUri.toString()),
        remoteModifiedAt: Value(now),
        remoteSize: const Value(2048),
        createdAt: now,
        updatedAt: now,
      ),
    );

    await repository.reconcileWebDavDirectory(
      directory: directory,
      entries: [
        WebDavEntry(
          name: 'score.pdf',
          uri: remoteUri,
          isDirectory: false,
          size: 2048,
          modifiedAt: now,
        ),
      ],
    );
    expect(
      (await repository.getSong('song-1'))!.syncStatus,
      SyncStatus.synced.key,
    );

    await repository.reconcileWebDavDirectory(
      directory: directory,
      entries: const [],
    );
    expect(
      (await repository.getSong('song-1'))!.syncStatus,
      SyncStatus.missing.key,
    );
  });

  test('전자 악보 메타데이터를 수정해도 scoreType을 유지한다', () async {
    final now = DateTime(2026, 9, 19);
    await repository.saveSong(
      SongsCompanion.insert(
        id: 'musicxml-1',
        title: 'Before',
        scoreType: Value(ScoreType.musicXml.key),
        sourcePath: 'scores/musicxml-1.musicxml',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await repository.updateMetadata(id: 'musicxml-1', title: 'After');

    final song = await repository.getSong('musicxml-1');
    expect(song?.title, 'After');
    expect(song?.scoreType, ScoreType.musicXml.key);
  });
}
