import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/database/database_providers.dart';
import 'package:page_a_diddle/core/session/jam_session.dart';
import 'package:page_a_diddle/core/storage/storage_provider.dart';
import 'package:page_a_diddle/features/setlists/domain/setlist_song.dart';
import 'package:uuid/uuid.dart';

typedef SetlistIdGenerator = String Function();
typedef SetlistClock = DateTime Function();

class SetlistImportEntry {
  const SetlistImportEntry({
    required this.entryId,
    required this.title,
    this.artist,
    this.bpm,
    this.music,
  });

  final String entryId;
  final String title;
  final String? artist;
  final int? bpm;
  final JamMusicState? music;
}

class SetlistImportResult {
  const SetlistImportResult({required this.localSongIdsByEntry});

  /// Only entries already bound to a real local song are returned. Pending
  /// placeholders deliberately stay unbound until the member imports a file.
  final Map<String, String> localSongIdsByEntry;
}

class SetlistRepository {
  SetlistRepository({
    required AppDatabase database,
    SetlistIdGenerator? idGenerator,
    SetlistClock? clock,
  }) : _database = database,
       _idGenerator = idGenerator ?? const Uuid().v4,
       _clock = clock ?? DateTime.now;

  final AppDatabase _database;
  final SetlistIdGenerator _idGenerator;
  final SetlistClock _clock;

  Stream<List<Setlist>> watchSetlists() {
    final query = _database.select(_database.setlists)
      ..orderBy([(setlist) => OrderingTerm.desc(setlist.updatedAt)]);
    return query.watch();
  }

  /// Reads the current list for actions that leave or replace this screen.
  Future<List<Setlist>> getSetlists() async {
    final query = _database.select(_database.setlists)
      ..orderBy([(setlist) => OrderingTerm.desc(setlist.updatedAt)]);
    return query.get();
  }

  Future<Setlist?> getSetlist(String id) {
    return (_database.select(
      _database.setlists,
    )..where((setlist) => setlist.id.equals(id))).getSingleOrNull();
  }

  Stream<List<SetlistSong>> watchItems(String setlistId) {
    final entries = _database.setlistEntries;
    final songs = _database.songs;
    final query =
        _database.select(entries).join([
            innerJoin(songs, songs.id.equalsExp(entries.songId)),
          ])
          ..where(entries.setlistId.equals(setlistId))
          ..orderBy([OrderingTerm.asc(entries.position)]);

    return query.watch().map((rows) => _mapItems(rows, entries, songs));
  }

  /// Reads a stable snapshot for actions that leave this screen, such as Jam.
  /// A live Drift stream can be invalidated while a route is being replaced.
  Future<List<SetlistSong>> getItems(String setlistId) async {
    final entries = _database.setlistEntries;
    final songs = _database.songs;
    final rows =
        await (_database.select(entries).join([
                innerJoin(songs, songs.id.equalsExp(entries.songId)),
              ])
              ..where(entries.setlistId.equals(setlistId))
              ..orderBy([OrderingTerm.asc(entries.position)]))
            .get();
    return _mapItems(rows, entries, songs);
  }

  List<SetlistSong> _mapItems(
    Iterable<TypedResult> rows,
    $SetlistEntriesTable entries,
    $SongsTable songs,
  ) {
    return [
      for (final row in rows)
        SetlistSong(entry: row.readTable(entries), song: row.readTable(songs)),
    ];
  }

  Future<String> createSetlist(String title) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw const FormatException('이름을 입력하세요.');
    }

    final id = _idGenerator();
    final now = _clock();
    await _database
        .into(_database.setlists)
        .insert(
          SetlistsCompanion.insert(
            id: id,
            title: normalizedTitle,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> renameSetlist({
    required String id,
    required String title,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw const FormatException('이름을 입력하세요.');
    }

    await (_database.update(
      _database.setlists,
    )..where((setlist) => setlist.id.equals(id))).write(
      SetlistsCompanion(
        title: Value(normalizedTitle),
        updatedAt: Value(_clock()),
      ),
    );
  }

  Future<void> deleteSetlist(String id) {
    return (_database.delete(
      _database.setlists,
    )..where((setlist) => setlist.id.equals(id))).go();
  }

  Future<String> addSong({
    required String setlistId,
    required String songId,
    int? tempoOverride,
  }) async {
    final entries = _database.setlistEntries;
    final lastEntry =
        await (_database.select(entries)
              ..where((entry) => entry.setlistId.equals(setlistId))
              ..orderBy([(entry) => OrderingTerm.desc(entry.position)])
              ..limit(1))
            .getSingleOrNull();
    final entryId = _idGenerator();

    await _database.transaction(() async {
      await _database
          .into(entries)
          .insert(
            SetlistEntriesCompanion.insert(
              id: entryId,
              setlistId: setlistId,
              songId: songId,
              position: (lastEntry?.position ?? -1) + 1,
              tempoOverride: Value(tempoOverride),
              createdAt: _clock(),
            ),
          );
      await _touch(setlistId);
    });
    return entryId;
  }

  Future<void> removeSong(String entryId) async {
    final entries = _database.setlistEntries;
    final entry = await (_database.select(
      entries,
    )..where((row) => row.id.equals(entryId))).getSingle();

    await _database.transaction(() async {
      await (_database.delete(
        entries,
      )..where((row) => row.id.equals(entryId))).go();
      final remaining =
          await (_database.select(entries)
                ..where((row) => row.setlistId.equals(entry.setlistId))
                ..orderBy([(row) => OrderingTerm.asc(row.position)]))
              .get();
      await _writeOrder(remaining.map((item) => item.id).toList());
      await _touch(entry.setlistId);
    });
  }

  Future<void> reorderSongs({
    required String setlistId,
    required List<String> entryIds,
  }) async {
    final current = await (_database.select(
      _database.setlistEntries,
    )..where((entry) => entry.setlistId.equals(setlistId))).get();
    final currentIds = current.map((entry) => entry.id).toSet();
    if (entryIds.length != currentIds.length ||
        !currentIds.containsAll(entryIds)) {
      throw const FormatException('곡 순서가 올바르지 않습니다.');
    }

    await _database.transaction(() async {
      await _writeOrder(entryIds);
      await _touch(setlistId);
    });
  }

  Future<void> updateTempo({
    required String entryId,
    int? tempoOverride,
  }) async {
    await (_database.update(_database.setlistEntries)
          ..where((entry) => entry.id.equals(entryId)))
        .write(SetlistEntriesCompanion(tempoOverride: Value(tempoOverride)));
  }

  Future<void> updateMetronome({
    required String entryId,
    required JamMusicState music,
  }) async {
    final normalized = jamMusicProfile(music);
    if (normalized.isEmpty) {
      throw const FormatException('메트로놈 정보가 없습니다.');
    }
    final entry = await (_database.select(
      _database.setlistEntries,
    )..where((row) => row.id.equals(entryId))).getSingleOrNull();
    if (entry == null) {
      throw const FormatException('세트리스트 곡이 없습니다.');
    }
    await _database.transaction(() async {
      await (_database.update(
        _database.setlistEntries,
      )..where((row) => row.id.equals(entryId))).write(
        SetlistEntriesCompanion(
          tempoOverride: Value(normalized.bpm),
          metronomeJson: Value(jsonEncode(normalized.toJson())),
        ),
      );
      await _touch(entry.setlistId);
    });
  }

  Future<SetlistImportResult> importSharedSetlist({
    required String id,
    required String title,
    required List<SetlistImportEntry> entries,
    Map<String, String> localSongIdsByEntry = const {},
  }) async {
    final setlistId = id.trim();
    final normalizedTitle = title.trim();
    if (setlistId.isEmpty || normalizedTitle.isEmpty) {
      throw const FormatException('세트리스트 정보가 올바르지 않습니다.');
    }

    final uniqueEntries = <SetlistImportEntry>[];
    final seenEntryIds = <String>{};
    for (final entry in entries) {
      final entryId = entry.entryId.trim();
      final entryTitle = entry.title.trim();
      if (entryId.isEmpty || entryTitle.isEmpty || !seenEntryIds.add(entryId)) {
        continue;
      }
      final importedMusic = entry.music == null
          ? null
          : normalizeJamMusic(
              JamMusicState(
                bpm: normalizeJamBpm(entry.music?.bpm ?? entry.bpm),
                meterNumerator: entry.music?.meterNumerator,
                meterDenominator: entry.music?.meterDenominator,
                subdivision: entry.music?.subdivision,
                accents: entry.music?.accents,
              ),
            );
      uniqueEntries.add(
        SetlistImportEntry(
          entryId: entryId,
          title: entryTitle,
          artist: entry.artist?.trim().isEmpty == true
              ? null
              : entry.artist?.trim(),
          bpm: normalizeJamBpm(importedMusic?.bpm ?? entry.bpm),
          music: importedMusic?.isEmpty == true ? null : importedMusic,
        ),
      );
    }

    final validLocalSongIds = <String>{};
    final requestedLocalSongIds = localSongIdsByEntry.values.toSet();
    if (requestedLocalSongIds.isNotEmpty) {
      final songs = await (_database.select(
        _database.songs,
      )..where((song) => song.id.isIn(requestedLocalSongIds))).get();
      validLocalSongIds.addAll(songs.map((song) => song.id));
    }
    final bindings = <String, String>{};
    final now = _clock();

    await _database.transaction(() async {
      final existing = await getSetlist(setlistId);
      if (existing == null) {
        await _database
            .into(_database.setlists)
            .insert(
              SetlistsCompanion.insert(
                id: setlistId,
                title: normalizedTitle,
                createdAt: now,
                updatedAt: now,
              ),
            );
      } else {
        await (_database.update(
          _database.setlists,
        )..where((setlist) => setlist.id.equals(setlistId))).write(
          SetlistsCompanion(
            title: Value(normalizedTitle),
            updatedAt: Value(now),
          ),
        );
      }

      await (_database.delete(
        _database.setlistEntries,
      )..where((entry) => entry.setlistId.equals(setlistId))).go();

      for (var index = 0; index < uniqueEntries.length; index++) {
        final entry = uniqueEntries[index];
        final requestedSongId = localSongIdsByEntry[entry.entryId];
        final localSongId =
            requestedSongId != null &&
                validLocalSongIds.contains(requestedSongId)
            ? requestedSongId
            : null;
        final songId = localSongId ?? _idGenerator();

        if (localSongId == null) {
          await _database
              .into(_database.songs)
              .insert(
                SongsCompanion.insert(
                  id: songId,
                  title: entry.title,
                  artist: Value(entry.artist),
                  defaultTempo: Value(entry.bpm),
                  sourcePath: 'jam-pending/$songId.pdf',
                  sourceProvider: const Value(jamPendingSourceProvider),
                  offlineAvailable: const Value(false),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        } else {
          bindings[entry.entryId] = localSongId;
        }

        await _database
            .into(_database.setlistEntries)
            .insert(
              SetlistEntriesCompanion.insert(
                id: entry.entryId,
                setlistId: setlistId,
                songId: songId,
                position: index,
                tempoOverride: Value(entry.bpm),
                metronomeJson: Value(
                  entry.music == null || entry.music!.isEmpty
                      ? null
                      : jsonEncode(entry.music!.toJson()),
                ),
                createdAt: now,
              ),
            );
      }
    });

    return SetlistImportResult(localSongIdsByEntry: bindings);
  }

  Future<void> replaceEntrySong({
    required String entryId,
    required String songId,
  }) async {
    final songExists = await (_database.select(
      _database.songs,
    )..where((song) => song.id.equals(songId))).getSingleOrNull();
    if (songExists == null) return;
    await (_database.update(_database.setlistEntries)
          ..where((entry) => entry.id.equals(entryId)))
        .write(SetlistEntriesCompanion(songId: Value(songId)));
  }

  Future<void> _writeOrder(List<String> entryIds) async {
    for (var index = 0; index < entryIds.length; index++) {
      await (_database.update(_database.setlistEntries)
            ..where((entry) => entry.id.equals(entryIds[index])))
          .write(SetlistEntriesCompanion(position: Value(-index - 1)));
    }
    for (var index = 0; index < entryIds.length; index++) {
      await (_database.update(_database.setlistEntries)
            ..where((entry) => entry.id.equals(entryIds[index])))
          .write(SetlistEntriesCompanion(position: Value(index)));
    }
  }

  Future<void> _touch(String setlistId) {
    return (_database.update(_database.setlists)
          ..where((setlist) => setlist.id.equals(setlistId)))
        .write(SetlistsCompanion(updatedAt: Value(_clock())));
  }
}

final setlistRepositoryProvider = Provider<SetlistRepository>((ref) {
  return SetlistRepository(database: ref.watch(appDatabaseProvider));
});
