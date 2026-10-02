import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/database/database_providers.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/core/storage/storage_provider.dart';
import 'package:page_a_diddle/features/library/data/label_repository.dart';
import 'package:page_a_diddle/features/library/domain/library_filter.dart';
import 'package:page_a_diddle/features/library/domain/picked_local_file.dart';
import 'package:page_a_diddle/features/library/domain/score_type.dart';
import 'package:page_a_diddle/features/storage/data/webdav_connection.dart';
import 'package:page_a_diddle/features/storage/domain/sync_status.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class SongRepository {
  const SongRepository(this._database, this._labels, this._storage);

  final AppDatabase _database;
  final LabelRepository _labels;
  final SongFileStorage _storage;

  Stream<List<Song>> watchSongs({
    String query = '',
    LibraryFilter filter = LibraryFilter.all,
    String? folderId,
    bool unfiledOnly = false,
    String? labelName,
  }) {
    final statement = _database.select(_database.songs)
      ..orderBy([
        (song) =>
            OrderingTerm(expression: song.updatedAt, mode: OrderingMode.desc),
      ]);

    final normalizedQuery = query.trim().toLowerCase();
    final needsLabelQuery = normalizedQuery.isNotEmpty;
    final needsLabelFilter = labelName != null && labelName.isNotEmpty;

    List<Song> applyFilter(
      List<Song> songs, {
      Set<String> labelMatchedIds = const {},
      Set<String>? labelFilterIds,
    }) {
      final filtered = songs.where((song) {
        if (song.sourceProvider == jamPendingSourceProvider ||
            song.sourceProvider == jamHostSourceProvider) {
          return false;
        }
        if (unfiledOnly && song.folderId != null) {
          return false;
        }
        if (folderId != null && song.folderId != folderId) {
          return false;
        }
        if (labelFilterIds != null && !labelFilterIds.contains(song.id)) {
          return false;
        }

        final matchesQuery =
            normalizedQuery.isEmpty ||
            song.title.toLowerCase().contains(normalizedQuery) ||
            (song.artist?.toLowerCase().contains(normalizedQuery) ?? false) ||
            song.defaultTempo?.toString() == normalizedQuery ||
            labelMatchedIds.contains(song.id);

        if (!matchesQuery) {
          return false;
        }

        return switch (filter) {
          LibraryFilter.all => true,
          LibraryFilter.favorites => song.isFavorite,
          LibraryFilter.recent => song.lastOpenedAt != null,
        };
      }).toList();

      if (filter == LibraryFilter.recent) {
        filtered.sort((a, b) => b.lastOpenedAt!.compareTo(a.lastOpenedAt!));
      }

      return filtered;
    }

    // Avoid asyncMap on the common path so the first emission is sync.
    if (!needsLabelQuery && !needsLabelFilter) {
      return statement.watch().map(applyFilter);
    }

    return statement.watch().asyncMap((songs) async {
      final labelMatchedIds = needsLabelQuery
          ? await _labels.songIdsMatchingLabelQuery(normalizedQuery)
          : const <String>{};
      final activeLabel = labelName;
      final labelFilterIds =
          needsLabelFilter && activeLabel != null && activeLabel.isNotEmpty
          ? await _labels.songIdsForLabelName(activeLabel)
          : null;
      return applyFilter(
        songs,
        labelMatchedIds: labelMatchedIds,
        labelFilterIds: labelFilterIds,
      );
    });
  }

  /// Recent scores only — SQL-filtered so home doesn't wait on the full library.
  Stream<List<Song>> watchRecentSongs({int limit = 8}) {
    final statement = _database.select(_database.songs)
      ..where(
        (song) =>
            song.lastOpenedAt.isNotNull() &
            song.sourceProvider.isNotIn([
              jamPendingSourceProvider,
              jamHostSourceProvider,
            ]),
      )
      ..orderBy([
        (song) => OrderingTerm(
          expression: song.lastOpenedAt,
          mode: OrderingMode.desc,
        ),
      ])
      ..limit(limit);
    return statement.watch();
  }

  Future<void> saveSong(SongsCompanion song) async {
    await _database.into(_database.songs).insertOnConflictUpdate(song);
  }

  Future<Song?> getSong(String id) {
    return (_database.select(
      _database.songs,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Future<Map<String, Song>> getSongsByRemoteUris(
    Iterable<Uri> remoteUris,
  ) async {
    final values = remoteUris.map((uri) => uri.toString()).toSet().toList();
    if (values.isEmpty) return const {};

    final songs = await (_database.select(
      _database.songs,
    )..where((song) => song.remoteUri.isIn(values))).get();
    return {for (final song in songs) song.remoteUri!: song};
  }

  Future<void> reconcileWebDavDirectory({
    required Uri directory,
    required Iterable<WebDavEntry> entries,
  }) async {
    final remoteFiles = {
      for (final entry in entries)
        if (!entry.isDirectory) entry.uri.toString(): entry,
    };
    final songs =
        await (_database.select(_database.songs)..where(
              (song) =>
                  song.sourceProvider.equals(StorageProvider.webDav.key) &
                  song.remoteUri.isNotNull(),
            ))
            .get();
    final directoryPath = _normalizedDirectoryPath(directory);

    await _database.transaction(() async {
      for (final song in songs) {
        final remoteUri = Uri.parse(song.remoteUri!);
        if (_normalizedDirectoryPath(remoteUri.resolve('.')) != directoryPath) {
          continue;
        }

        final remote = remoteFiles[song.remoteUri];
        final status = resolveSyncStatus(
          hasLocalRecord: true,
          offlineAvailable: song.offlineAvailable,
          remotePresent: remote != null,
          syncedModifiedAt: song.remoteModifiedAt,
          syncedSize: song.remoteSize,
          remoteModifiedAt: remote?.modifiedAt,
          remoteSize: remote?.size,
        );
        if (song.syncStatus == status.key) continue;

        await (_database.update(_database.songs)
              ..where((row) => row.id.equals(song.id)))
            .write(SongsCompanion(syncStatus: Value(status.key)));
      }
    });
  }

  Future<void> completeRemoteDownload({
    required String songId,
    required String sourcePath,
    required DateTime? remoteModifiedAt,
    required int remoteSize,
  }) {
    return (_database.update(
      _database.songs,
    )..where((song) => song.id.equals(songId))).write(
      SongsCompanion(
        sourcePath: Value(sourcePath),
        remoteModifiedAt: Value(remoteModifiedAt),
        remoteSize: Value(remoteSize),
        syncStatus: Value(SyncStatus.synced.key),
        offlineAvailable: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markOpened(String id) async {
    final now = DateTime.now();
    await (_database.update(_database.songs)..where((row) => row.id.equals(id)))
        .write(SongsCompanion(lastOpenedAt: Value(now), updatedAt: Value(now)));
  }

  Future<void> toggleFavorite(String id) async {
    final song = await (_database.select(
      _database.songs,
    )..where((row) => row.id.equals(id))).getSingle();

    await (_database.update(
      _database.songs,
    )..where((row) => row.id.equals(id))).write(
      SongsCompanion(
        isFavorite: Value(!song.isFavorite),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateTargetBpm({
    required String id,
    required int? targetBpm,
  }) async {
    if (targetBpm != null && (targetBpm < 40 || targetBpm > 240)) {
      throw ArgumentError.value(
        targetBpm,
        'targetBpm',
        '목표 BPM은 40~240이어야 합니다.',
      );
    }
    await (_database.update(
      _database.songs,
    )..where((row) => row.id.equals(id))).write(
      SongsCompanion(
        targetBpm: Value(targetBpm),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateMetadata({
    required String id,
    required String title,
    String? artist,
    int? defaultTempo,
    String? note,
    String? folderId,
    bool clearFolder = false,
  }) async {
    await (_database.update(
      _database.songs,
    )..where((row) => row.id.equals(id))).write(
      SongsCompanion(
        title: Value(title.trim()),
        artist: Value(_emptyToNull(artist)),
        defaultTempo: Value(defaultTempo),
        note: Value(_emptyToNull(note)),
        folderId: clearFolder
            ? const Value(null)
            : folderId == null
            ? const Value.absent()
            : Value(folderId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setFolder({required String id, String? folderId}) async {
    await (_database.update(
      _database.songs,
    )..where((row) => row.id.equals(id))).write(
      SongsCompanion(
        folderId: Value(folderId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setFolders({
    required Iterable<String> ids,
    String? folderId,
  }) async {
    final idList = ids.toSet().toList();
    if (idList.isEmpty) return;
    await (_database.update(
      _database.songs,
    )..where((row) => row.id.isIn(idList))).write(
      SongsCompanion(
        folderId: Value(folderId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> duplicateSongs({
    required Iterable<String> ids,
    String? folderId,
    bool clearFolder = false,
  }) async {
    for (final id in ids) {
      final song = await getSong(id);
      if (song == null) continue;
      final newId = const Uuid().v4();
      final source = await _storage.resolve(song.sourcePath);
      if (!await source.exists()) continue;
      final scoreType = ScoreType.fromKey(song.scoreType);
      final pickedSource = PickedLocalFile(
        name: path.basename(song.sourcePath),
        path: source.path,
      );
      final relativePath = await switch (scoreType) {
        ScoreType.pdf => _storage.storePdf(source: pickedSource, songId: newId),
        ScoreType.musicXml => _storage.storeMusicXml(
          source: pickedSource,
          songId: newId,
        ),
      };
      final now = DateTime.now();
      final nextFolder = clearFolder ? null : folderId ?? song.folderId;
      try {
        await saveSong(
          SongsCompanion.insert(
            id: newId,
            title: song.title,
            artist: Value(song.artist),
            defaultTempo: Value(song.defaultTempo),
            targetBpm: Value(song.targetBpm),
            scoreType: Value(song.scoreType),
            sourcePath: relativePath,
            sourceProvider: Value(song.sourceProvider),
            note: Value(song.note),
            folderId: Value(nextFolder),
            createdAt: now,
            updatedAt: now,
          ),
        );
        final labels = await _labels.labelsForSong(song.id);
        if (labels.isNotEmpty) {
          await _labels.setSongLabels(
            songId: newId,
            labelNames: labels.map((label) => label.name),
          );
        }
        final sequence = await _storage.loadPlaybackSequence(song.id);
        if (sequence != null) {
          await _storage.savePlaybackSequence(newId, sequence);
        }
        final arrangement = await _storage.loadArrangementProfile(song.id);
        if (arrangement != null) {
          await _storage.saveArrangementProfile(newId, arrangement);
        }
      } on Object {
        await _storage.delete(relativePath);
        rethrow;
      }
    }
  }

  Future<void> deleteSongs(Iterable<String> ids) async {
    final idList = ids.toSet().toList();
    if (idList.isEmpty) return;
    final songs = await (_database.select(
      _database.songs,
    )..where((row) => row.id.isIn(idList))).get();
    await (_database.delete(
      _database.songs,
    )..where((row) => row.id.isIn(idList))).go();
    for (final song in songs) {
      try {
        await _storage.delete(song.sourcePath);
      } on Object {
        // Best-effort file cleanup.
      }
      if (song.audioPath case final audio?) {
        try {
          await _storage.delete(audio);
        } on Object {
          // Best-effort file cleanup.
        }
      }
      try {
        await _storage.delete(_storage.playbackSequencePathFor(song.id));
      } on Object {
        // Best-effort file cleanup.
      }
      try {
        await _storage.delete(_storage.arrangementProfilePathFor(song.id));
      } on Object {
        // Best-effort file cleanup.
      }
      try {
        await _storage.delete(_storage.originalKeyPathFor(song.id));
      } on Object {
        // Best-effort file cleanup.
      }
      try {
        await _storage.deleteOmrReviewFiles(song.id);
      } on Object {
        // Best-effort file cleanup.
      }
    }
  }

  Future<void> clearJamHostSongs() async {
    final songs =
        await (_database.select(_database.songs)..where(
              (song) => song.sourceProvider.equals(jamHostSourceProvider),
            ))
            .get();
    await deleteSongs(songs.map((song) => song.id));
  }

  Future<void> attachAudio({
    required String id,
    required String path,
    required String name,
  }) async {
    await (_database.update(
      _database.songs,
    )..where((row) => row.id.equals(id))).write(
      SongsCompanion(
        audioPath: Value(path),
        audioName: Value(name),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  String? _emptyToNull(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  String _normalizedDirectoryPath(Uri uri) {
    return uri.path.endsWith('/') ? uri.path : '${uri.path}/';
  }
}

final songRepositoryProvider = Provider<SongRepository>((ref) {
  return SongRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(labelRepositoryProvider),
    ref.watch(songFileStorageProvider),
  );
});
