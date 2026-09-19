import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/core/storage/storage_provider.dart';
import 'package:page_a_diddle/features/library/data/song_repository.dart';
import 'package:page_a_diddle/features/library/domain/picked_local_file.dart';
import 'package:page_a_diddle/features/storage/data/webdav_connection.dart';
import 'package:page_a_diddle/features/storage/domain/sync_status.dart';
import 'package:uuid/uuid.dart';

typedef RemoteScoreIdGenerator = String Function();
typedef RemoteScoreClock = DateTime Function();
typedef WebDavCredentialsReader = Future<WebDavCredentials?> Function();

class RemoteScoreService {
  RemoteScoreService({
    required SongRepository repository,
    required SongFileStorage storage,
    required WebDavConnection connection,
    required WebDavCredentialsReader credentialsReader,
    RemoteScoreIdGenerator? idGenerator,
    RemoteScoreClock? clock,
  }) : _repository = repository,
       _storage = storage,
       _connection = connection,
       _credentialsReader = credentialsReader,
       _idGenerator = idGenerator ?? const Uuid().v4,
       _clock = clock ?? DateTime.now;

  final SongRepository _repository;
  final SongFileStorage _storage;
  final WebDavConnection _connection;
  final WebDavCredentialsReader _credentialsReader;
  final RemoteScoreIdGenerator _idGenerator;
  final RemoteScoreClock _clock;

  Future<String> register(WebDavEntry entry) async {
    if (entry.isDirectory) {
      throw const FormatException('PDF를 선택하세요.');
    }
    final existing = await _repository.getSongsByRemoteUris([entry.uri]);
    if (existing[entry.uri.toString()] case final song?) return song.id;

    final id = _idGenerator();
    final now = _clock();
    await _repository.saveSong(
      SongsCompanion.insert(
        id: id,
        title: _titleFromName(entry.name),
        sourcePath: _storage.pdfPathFor(id),
        sourceProvider: Value(StorageProvider.webDav.key),
        remoteUri: Value(entry.uri.toString()),
        remoteModifiedAt: Value(entry.modifiedAt),
        remoteSize: Value(entry.size),
        syncStatus: Value(SyncStatus.cloudOnly.key),
        offlineAvailable: const Value(false),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  Future<void> download(Song song) async {
    final remoteUri = song.remoteUri;
    if (song.sourceProvider != StorageProvider.webDav.key ||
        remoteUri == null) {
      throw const FormatException('WebDAV 악보가 아닙니다.');
    }
    final credentials = await _credentialsReader();
    if (credentials == null) {
      throw const WebDavConnectionException('WebDAV 연결이 필요합니다.');
    }

    final result = await _connection.downloadPdf(
      credentials,
      Uri.parse(remoteUri),
    );
    final path = await _storage.storePdf(
      source: PickedLocalFile(name: '${song.title}.pdf', bytes: result.bytes),
      songId: song.id,
    );
    try {
      await _repository.completeRemoteDownload(
        songId: song.id,
        sourcePath: path,
        remoteModifiedAt: result.modifiedAt ?? song.remoteModifiedAt,
        remoteSize: result.bytes.length,
      );
    } on Object {
      await _storage.delete(path);
      rethrow;
    }
  }

  String _titleFromName(String name) {
    final title = name.toLowerCase().endsWith('.pdf')
        ? name.substring(0, name.length - 4)
        : name;
    return title.trim().isEmpty ? 'PDF 악보' : title;
  }
}

final remoteScoreServiceProvider = Provider<RemoteScoreService>((ref) {
  final settings = ref.watch(webDavSettingsStoreProvider);
  return RemoteScoreService(
    repository: ref.watch(songRepositoryProvider),
    storage: ref.watch(songFileStorageProvider),
    connection: ref.watch(webDavConnectionProvider),
    credentialsReader: settings.read,
  );
});
