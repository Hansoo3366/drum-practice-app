import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/features/setlists/data/setlist_repository.dart';
import 'package:page_a_diddle/features/setlists/domain/setlist_song.dart';

final setlistsProvider = StreamProvider<List<Setlist>>((ref) {
  return ref.watch(setlistRepositoryProvider).watchSetlists();
});

final setlistProvider = FutureProvider.family<Setlist?, String>((ref, id) {
  return ref.watch(setlistRepositoryProvider).getSetlist(id);
});

final setlistItemsProvider = StreamProvider.family<List<SetlistSong>, String>((
  ref,
  setlistId,
) {
  return ref.watch(setlistRepositoryProvider).watchItems(setlistId);
});
