import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/features/library/data/label_repository.dart';
import 'package:page_a_diddle/features/library/data/song_repository.dart';
import 'package:page_a_diddle/features/setlists/data/setlist_offline_service.dart';
import 'package:page_a_diddle/features/setlists/data/setlist_repository.dart';
import 'package:page_a_diddle/features/storage/data/remote_score_service.dart';
import 'package:page_a_diddle/features/storage/data/webdav_connection.dart';
import 'package:page_a_diddle/features/storage/domain/sync_status.dart';

void main() {
  late Directory root;
  late AppDatabase database;
  late SongRepository songs;
  late RemoteScoreService remoteScores;
  final modifiedAt = DateTime.utc(2026, 8, 20, 5);
  final remoteUri = Uri.parse('https://example.com/webdav/score.pdf');

  setUp(() async {
    root = await Directory.systemTemp.createTemp('page_a_diddle_remote_');
    database = AppDatabase(NativeDatabase.memory());
    songs = SongRepository(
      database,
      LabelRepository(database),
      SongFileStorage(rootDirectoryProvider: () async => root),
    );
    remoteScores = RemoteScoreService(
      repository: songs,
      storage: SongFileStorage(rootDirectoryProvider: () async => root),
      connection: WebDavConnection(
        download: (uri, username, password) async {
          expect(uri, remoteUri);
          return WebDavDownloadResult(
            bytes: Uint8List.fromList('%PDF-1.7 remote'.codeUnits),
            modifiedAt: modifiedAt,
          );
        },
      ),
      credentialsReader: () async => const WebDavCredentials(
        url: 'https://example.com/webdav/',
        username: 'drummer',
        password: 'secret',
      ),
      idGenerator: () => 'song-1',
      clock: () => modifiedAt,
    );
  });

  tearDown(() async {
    await database.close();
    await root.delete(recursive: true);
  });

  test('WebDAV PDF를 클라우드 곡으로 등록한다', () async {
    final id = await remoteScores.register(
      WebDavEntry(
        name: 'score.pdf',
        uri: remoteUri,
        isDirectory: false,
        size: 1024,
        modifiedAt: modifiedAt,
      ),
    );
    final song = await songs.getSong(id);

    expect(song!.title, 'score');
    expect(song.offlineAvailable, isFalse);
    expect(song.syncStatus, SyncStatus.cloudOnly.key);
    expect(File('${root.path}/${song.sourcePath}').existsSync(), isFalse);
  });

  test('세트리스트의 WebDAV 곡을 내려받아 동기화한다', () async {
    final songId = await remoteScores.register(
      WebDavEntry(
        name: 'score.pdf',
        uri: remoteUri,
        isDirectory: false,
        size: 1024,
        modifiedAt: modifiedAt,
      ),
    );
    final setlists = SetlistRepository(database: database);
    final setlistId = await setlists.createSetlist('공연');
    await setlists.addSong(setlistId: setlistId, songId: songId);

    final result = await SetlistOfflineService(
      setlists: setlists,
      remoteScores: remoteScores,
    ).download(setlistId);
    final song = await songs.getSong(songId);

    expect(result.downloaded, 1);
    expect(result.failedTitles, isEmpty);
    expect(song!.offlineAvailable, isTrue);
    expect(song.syncStatus, SyncStatus.synced.key);
    expect(File('${root.path}/${song.sourcePath}').existsSync(), isTrue);
  });
}
