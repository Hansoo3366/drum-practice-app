import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/database/database_providers.dart';
import 'package:page_a_diddle/features/library/domain/folder_colors.dart';
import 'package:page_a_diddle/features/library/domain/folder_tree.dart';
import 'package:page_a_diddle/features/library/domain/label_name.dart';

class FolderRepository {
  const FolderRepository(this._database);

  final AppDatabase _database;

  Stream<List<Folder>> watchFolders() {
    final statement = _database.select(_database.folders)
      ..orderBy([
        (folder) => OrderingTerm(expression: folder.sortOrder),
        (folder) => OrderingTerm(expression: folder.name),
      ]);
    return statement.watch();
  }

  Future<List<Folder>> listFolders() {
    final statement = _database.select(_database.folders)
      ..orderBy([
        (folder) => OrderingTerm(expression: folder.sortOrder),
        (folder) => OrderingTerm(expression: folder.name),
      ]);
    return statement.get();
  }

  Future<Folder?> getFolder(String id) {
    return (_database.select(
      _database.folders,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Future<bool> _wouldCreateCycle({
    required String folderId,
    required String? newParentId,
  }) async {
    var cursor = newParentId;
    while (cursor != null) {
      if (cursor == folderId) return true;
      final parent = await getFolder(cursor);
      cursor = parent?.parentId;
    }
    return false;
  }

  Future<int> depthOf(String? folderId) async {
    if (folderId == null) return -1;
    var depth = 0;
    String? cursor = folderId;
    final seen = <String>{};
    while (cursor != null) {
      if (!seen.add(cursor)) {
        throw StateError('Folder cycle detected');
      }
      final folder = await getFolder(cursor);
      if (folder == null) break;
      final parentId = folder.parentId;
      if (parentId == null) return depth;
      depth += 1;
      cursor = parentId;
      if (depth > maxFolderDepth + 2) {
        throw StateError('Folder nest too deep');
      }
    }
    return depth;
  }

  Future<Folder> createFolder({
    required String name,
    int? color,
    String? parentId,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Folder name is required');
    }
    if (parentId != null) {
      final parent = await getFolder(parentId);
      if (parent == null) {
        throw ArgumentError.value(parentId, 'parentId', 'Parent not found');
      }
      final parentDepth = await depthOf(parentId);
      if (!canCreateSubfolderAtDepth(parentDepth)) {
        throw StateError('folder_depth_limit');
      }
    }
    final siblings = (await listFolders())
        .where((folder) => folder.parentId == parentId)
        .toList();
    final folder = FoldersCompanion.insert(
      id: newLibraryId(),
      name: trimmed,
      color: FolderColors.normalize(color),
      parentId: Value(parentId),
      sortOrder: Value(siblings.length),
      createdAt: DateTime.now(),
    );
    await _database.into(_database.folders).insert(folder);
    return (await getFolder(folder.id.value))!;
  }

  Future<void> updateFolder({
    required String id,
    required String name,
    required int color,
    String? parentId,
    bool clearParent = false,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Folder name is required');
    }
    final nextParent = clearParent ? null : parentId;
    if (nextParent == id) {
      throw ArgumentError.value(nextParent, 'parentId', 'Invalid parent');
    }
    if (await _wouldCreateCycle(folderId: id, newParentId: nextParent)) {
      throw ArgumentError.value(nextParent, 'parentId', 'Would create a cycle');
    }
    await (_database.update(
      _database.folders,
    )..where((row) => row.id.equals(id))).write(
      FoldersCompanion(
        name: Value(trimmed),
        color: Value(FolderColors.normalize(color)),
        parentId: clearParent
            ? const Value(null)
            : parentId == null
            ? const Value.absent()
            : Value(parentId),
      ),
    );
  }

  Future<void> deleteFolder(String id) async {
    final folder = await getFolder(id);
    if (folder == null) return;
    await _database.transaction(() async {
      await (_database.update(_database.folders)
            ..where((row) => row.parentId.equals(id)))
          .write(FoldersCompanion(parentId: Value(folder.parentId)));
      await (_database.delete(
        _database.folders,
      )..where((row) => row.id.equals(id))).go();
    });
  }
}

final folderRepositoryProvider = Provider<FolderRepository>((ref) {
  return FolderRepository(ref.watch(appDatabaseProvider));
});

final libraryFoldersProvider = StreamProvider<List<Folder>>((ref) {
  return ref.watch(folderRepositoryProvider).watchFolders();
});

final libraryFolderForestProvider = Provider<List<FolderNode>>((ref) {
  final folders = ref.watch(libraryFoldersProvider).asData?.value ?? const [];
  return buildFolderForest(folders);
});
