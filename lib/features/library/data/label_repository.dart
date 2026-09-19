import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/database/database_providers.dart';
import 'package:page_a_diddle/features/library/domain/label_name.dart';

class LabelRepository {
  const LabelRepository(this._database);

  final AppDatabase _database;

  Stream<List<Label>> watchLabels() {
    final statement = _database.select(_database.labels)
      ..orderBy([(label) => OrderingTerm(expression: label.name)]);
    return statement.watch();
  }

  Future<List<Label>> labelsForSong(String songId) async {
    final query = _database.select(_database.labels).join([
      innerJoin(
        _database.songLabels,
        _database.songLabels.labelId.equalsExp(_database.labels.id),
      ),
    ])..where(_database.songLabels.songId.equals(songId));
    final rows = await query.get();
    final labels = rows.map((row) => row.readTable(_database.labels)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return labels;
  }

  Stream<List<Label>> watchLabelsForSong(String songId) {
    final query = _database.select(_database.labels).join([
      innerJoin(
        _database.songLabels,
        _database.songLabels.labelId.equalsExp(_database.labels.id),
      ),
    ])..where(_database.songLabels.songId.equals(songId));
    return query.watch().map((rows) {
      final labels = rows.map((row) => row.readTable(_database.labels)).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return labels;
    });
  }

  Future<Map<String, List<Label>>> labelsBySongIds(
    Iterable<String> songIds,
  ) async {
    final ids = songIds.toSet().toList();
    if (ids.isEmpty) return const {};

    final query = _database.select(_database.songLabels).join([
      innerJoin(
        _database.labels,
        _database.labels.id.equalsExp(_database.songLabels.labelId),
      ),
    ])..where(_database.songLabels.songId.isIn(ids));

    final rows = await query.get();
    final map = <String, List<Label>>{};
    for (final row in rows) {
      final link = row.readTable(_database.songLabels);
      final label = row.readTable(_database.labels);
      map.putIfAbsent(link.songId, () => []).add(label);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }
    return map;
  }

  Future<Set<String>> songIdsForLabelName(String labelName) async {
    final normalized = normalizeLabelName(labelName);
    if (normalized.isEmpty) return const {};

    final query = _database.select(_database.songLabels).join([
      innerJoin(
        _database.labels,
        _database.labels.id.equalsExp(_database.songLabels.labelId),
      ),
    ])..where(_database.labels.name.equals(normalized));

    final rows = await query.get();
    return rows.map((row) => row.readTable(_database.songLabels).songId).toSet();
  }

  Future<Set<String>> songIdsMatchingLabelQuery(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return const {};

    final queryBuilder = _database.select(_database.songLabels).join([
      innerJoin(
        _database.labels,
        _database.labels.id.equalsExp(_database.songLabels.labelId),
      ),
    ])..where(_database.labels.name.like('%$normalized%'));

    final rows = await queryBuilder.get();
    return rows.map((row) => row.readTable(_database.songLabels).songId).toSet();
  }

  Future<Label> _ensureLabel(String rawName) async {
    final name = normalizeLabelName(rawName);
    if (name.isEmpty) {
      throw ArgumentError.value(rawName, 'name', 'Label is required');
    }
    final existing = await (_database.select(
      _database.labels,
    )..where((row) => row.name.equals(name))).getSingleOrNull();
    if (existing != null) return existing;

    final companion = LabelsCompanion.insert(
      id: newLibraryId(),
      name: name,
      createdAt: DateTime.now(),
    );
    await _database.into(_database.labels).insert(companion);
    return (await (_database.select(
      _database.labels,
    )..where((row) => row.id.equals(companion.id.value))).getSingle());
  }

  Future<void> setSongLabels({
    required String songId,
    required Iterable<String> labelNames,
  }) async {
    final unique = <String>{};
    for (final raw in labelNames) {
      final name = normalizeLabelName(raw);
      if (name.isNotEmpty) unique.add(name);
    }

    await _database.transaction(() async {
      await (_database.delete(
        _database.songLabels,
      )..where((row) => row.songId.equals(songId))).go();

      for (final name in unique) {
        final label = await _ensureLabel(name);
        await _database
            .into(_database.songLabels)
            .insert(
              SongLabelsCompanion.insert(songId: songId, labelId: label.id),
            );
      }
    });
  }

  Future<void> addLabelToSong({
    required String songId,
    required String rawName,
  }) async {
    final label = await _ensureLabel(rawName);
    await _database
        .into(_database.songLabels)
        .insertOnConflictUpdate(
          SongLabelsCompanion.insert(songId: songId, labelId: label.id),
        );
  }

  Future<void> removeLabelFromSong({
    required String songId,
    required String labelId,
  }) async {
    await (_database.delete(_database.songLabels)..where(
          (row) => row.songId.equals(songId) & row.labelId.equals(labelId),
        ))
        .go();
  }
}

final labelRepositoryProvider = Provider<LabelRepository>((ref) {
  return LabelRepository(ref.watch(appDatabaseProvider));
});

final libraryLabelsProvider = StreamProvider<List<Label>>((ref) {
  return ref.watch(labelRepositoryProvider).watchLabels();
});

final songLabelsProvider = StreamProvider.family<List<Label>, String>((
  ref,
  songId,
) {
  return ref.watch(labelRepositoryProvider).watchLabelsForSong(songId);
});
