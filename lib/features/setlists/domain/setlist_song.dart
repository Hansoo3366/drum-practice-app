import 'dart:convert';

import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/session/jam_session.dart';

class SetlistSong {
  const SetlistSong({required this.entry, required this.song});

  final SetlistEntry entry;
  final Song song;

  int? get tempo => entry.tempoOverride ?? song.defaultTempo;

  /// Per-setlist-entry metronome profile. Older entries have no profile and
  /// fall back to the song BPM plus the user's global metronome defaults.
  JamMusicState? get metronome {
    final raw = entry.metronomeJson;
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      return musicStateFromMessage(decoded);
    } on Object {
      return null;
    }
  }
}
