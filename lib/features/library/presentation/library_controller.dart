import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/features/digital_score/data/bundled_score_seeder.dart';
import 'package:page_a_diddle/features/library/data/song_repository.dart';
import 'package:page_a_diddle/features/library/domain/library_filter.dart';

class LibraryQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String value) {
    state = value;
  }
}

class LibraryFilterNotifier extends Notifier<LibraryFilter> {
  @override
  LibraryFilter build() => LibraryFilter.all;

  void update(LibraryFilter value) {
    state = value;
  }
}

/// `null` = all folders; `__unfiled__` = no folder; otherwise folder id.
class LibraryFolderFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void update(String? value) {
    state = value;
  }
}

class LibraryLabelFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void update(String? value) {
    state = value;
  }
}

class LibrarySelectionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void toggle(String id) {
    final next = {...state};
    if (!next.add(id)) {
      next.remove(id);
    }
    state = next;
  }

  void clear() => state = {};

  void setAll(Iterable<String> ids) => state = ids.toSet();
}

const unfiledFolderFilterKey = '__unfiled__';

final libraryQueryProvider = NotifierProvider<LibraryQueryNotifier, String>(
  LibraryQueryNotifier.new,
);

final libraryFilterProvider =
    NotifierProvider<LibraryFilterNotifier, LibraryFilter>(
      LibraryFilterNotifier.new,
    );

final libraryFolderFilterProvider =
    NotifierProvider<LibraryFolderFilterNotifier, String?>(
      LibraryFolderFilterNotifier.new,
    );

final libraryLabelFilterProvider =
    NotifierProvider<LibraryLabelFilterNotifier, String?>(
      LibraryLabelFilterNotifier.new,
    );

final librarySelectionProvider =
    NotifierProvider<LibrarySelectionNotifier, Set<String>>(
      LibrarySelectionNotifier.new,
    );

final librarySongsProvider = StreamProvider<List<Song>>((ref) {
  unawaited(
    ref.watch(bundledScoreSeederProvider).ensureSeeded().onError((_, _) {
      // Keep the user's library usable if a bundled sample cannot import.
    }),
  );
  final query = ref.watch(libraryQueryProvider);
  final filter = ref.watch(libraryFilterProvider);
  final folderKey = ref.watch(libraryFolderFilterProvider);
  final labelName = ref.watch(libraryLabelFilterProvider);

  return ref
      .watch(songRepositoryProvider)
      .watchSongs(
        query: query,
        filter: filter,
        folderId: folderKey == null || folderKey == unfiledFolderFilterKey
            ? null
            : folderKey,
        unfiledOnly: false,
        labelName: labelName,
      );
});

final recentSongsProvider = StreamProvider<List<Song>>((ref) {
  return ref.watch(songRepositoryProvider).watchRecentSongs();
});
