import 'dart:convert';

import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/session/jam_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<Song> localSongCandidatesForJam(
  Iterable<Song> localSongs,
  JamSharedSong shared,
) {
  final title = shared.title.trim().toLowerCase();
  final artist = shared.artist?.trim().toLowerCase();
  final matches = localSongs
      .where((song) => song.title.trim().toLowerCase() == title)
      .toList(growable: false);
  final sorted = [...matches]
    ..sort((a, b) {
      final artistA =
          artist != null &&
              artist.isNotEmpty &&
              a.artist?.trim().toLowerCase() == artist
          ? 0
          : 1;
      final artistB =
          artist != null &&
              artist.isNotEmpty &&
              b.artist?.trim().toLowerCase() == artist
          ? 0
          : 1;
      final artistOrder = artistA.compareTo(artistB);
      if (artistOrder != 0) {
        return artistOrder;
      }
      return (a.offlineAvailable ? 0 : 1).compareTo(b.offlineAvailable ? 0 : 1);
    });
  return sorted;
}

Song? matchLocalSongForJam(Iterable<Song> localSongs, JamSharedSong shared) {
  final matches = localSongCandidatesForJam(localSongs, shared);
  return matches.firstOrNull;
}

String jamLocalSongBindingKey({
  required String setlistId,
  required String entryId,
}) => '$setlistId/$entryId';

class JamLocalSongBindingStore {
  const JamLocalSongBindingStore._();

  static const _preferencesKey = 'jam_local_song_bindings_v1';

  static Future<Map<String, String>> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(
      _preferencesKey,
    );
    if (raw == null) {
      return {};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return {};
      }
      return {
        for (final entry in decoded.entries)
          if (entry.key is String && entry.value is String)
            entry.key as String: entry.value as String,
      };
    } on FormatException {
      return {};
    }
  }

  static Future<void> save(Map<String, String> bindings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferencesKey, jsonEncode(bindings));
  }
}
