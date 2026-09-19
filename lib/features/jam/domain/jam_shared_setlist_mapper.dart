import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/session/jam_session.dart';
import 'package:page_a_diddle/features/setlists/domain/setlist_song.dart';

JamSharedSetlist jamSharedSetlistFromLibrary({
  required Setlist setlist,
  required Iterable<SetlistSong> songs,
}) {
  return JamSharedSetlist(
    id: setlist.id,
    title: setlist.title,
    songs: [
      for (final item in songs)
        JamSharedSong(
          entryId: item.entry.id,
          title: item.song.title,
          artist: item.song.artist,
          bpm: item.tempo,
          music: item.metronome,
        ),
    ],
  );
}
