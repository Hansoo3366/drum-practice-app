import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/features/digital_score/data/bundled_score_seeder.dart';
import 'package:page_a_diddle/features/library/data/song_repository.dart';
import 'package:page_a_diddle/features/library/domain/library_filter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// How the library lists its scores: the one changed last first, or by
/// title, the two orders every score library offers.
enum LibrarySort { recent, title }

class LibrarySortNotifier extends Notifier<LibrarySort> {
  static const _prefsKey = 'library_sort';

  @override
  LibrarySort build() {
    unawaited(_restore());
    return LibrarySort.recent;
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_prefsKey) == LibrarySort.title.name) {
        state = LibrarySort.title;
      }
    } on Object {
      // The order chosen last is a convenience.
    }
  }

  Future<void> update(LibrarySort value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, value.name);
    } on Object {
      // Kept for this run only.
    }
  }
}

final librarySortProvider = NotifierProvider<LibrarySortNotifier, LibrarySort>(
  LibrarySortNotifier.new,
);

/// [songs] in the order [sort] asks for. Titles compare without case, and
/// equal titles keep the order they came in.
List<Song> sortLibrarySongs(List<Song> songs, LibrarySort sort) {
  if (sort == LibrarySort.recent) return songs;
  final indexed = [for (var i = 0; i < songs.length; i++) (i, songs[i])];
  indexed.sort((a, b) {
    final byTitle = a.$2.title.toLowerCase().compareTo(
      b.$2.title.toLowerCase(),
    );
    return byTitle != 0 ? byTitle : a.$1.compareTo(b.$1);
  });
  return [for (final entry in indexed) entry.$2];
}

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
  final sort = ref.watch(librarySortProvider);

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
      )
      .map((songs) => sortLibrarySongs(songs, sort));
});

final recentSongsProvider = StreamProvider<List<Song>>((ref) {
  return ref.watch(songRepositoryProvider).watchRecentSongs();
});
