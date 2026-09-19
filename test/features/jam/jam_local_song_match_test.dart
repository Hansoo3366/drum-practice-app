import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/session/jam_session.dart';
import 'package:page_a_diddle/features/jam/domain/jam_local_song_match.dart';
import 'package:page_a_diddle/features/jam/domain/jam_shared_setlist_mapper.dart';
import 'package:page_a_diddle/features/setlists/domain/setlist_song.dart';

void main() {
  Song song({
    required String id,
    required String title,
    String? artist,
    bool offline = true,
  }) {
    final now = DateTime.utc(2026, 8, 20);
    return Song(
      id: id,
      title: title,
      artist: artist,
      scoreType: 'pdf',
      sourcePath: 'scores/$id.pdf',
      sourceProvider: 'local',
      createdAt: now,
      updatedAt: now,
      offlineAvailable: offline,
      isFavorite: false,
    );
  }

  test('제목과 아티스트로 로컬 악보를 찾는다', () {
    final local = [
      song(id: '1', title: 'Song A', artist: 'Band', offline: false),
      song(id: '2', title: 'Song A', artist: 'Band'),
      song(id: '3', title: 'Song A', artist: 'Other'),
    ];

    expect(
      localSongCandidatesForJam(
        local,
        const JamSharedSong(entryId: 'entry', title: 'Song A', artist: 'Band'),
      ).map((song) => song.id),
      ['2', '1', '3'],
    );

    expect(
      matchLocalSongForJam(
        local,
        const JamSharedSong(entryId: 'entry', title: 'Song A', artist: 'Band'),
      )?.id,
      '2',
    );
    expect(
      matchLocalSongForJam(
        local,
        const JamSharedSong(entryId: 'entry-missing', title: 'Missing'),
      ),
      isNull,
    );
  });

  test('기기별 악보 매핑 키는 세트리스트와 항목을 함께 사용한다', () {
    expect(
      jamLocalSongBindingKey(setlistId: 'setlist-1', entryId: 'entry-1'),
      'setlist-1/entry-1',
    );
  });

  test('공유 세트리스트는 로컬 Song.id가 아닌 entry.id를 보낸다', () {
    final now = DateTime.utc(2026, 8, 20);
    final local = song(id: 'local-score', title: 'Song A', artist: 'Band');
    final shared = jamSharedSetlistFromLibrary(
      setlist: Setlist(
        id: 'setlist-1',
        title: '공연',
        createdAt: now,
        updatedAt: now,
      ),
      songs: [
        SetlistSong(
          entry: SetlistEntry(
            id: 'entry-1',
            setlistId: 'setlist-1',
            songId: local.id,
            position: 0,
            createdAt: now,
          ),
          song: local,
        ),
      ],
    );

    expect(shared.id, 'setlist-1');
    expect(shared.songs.single.entryId, 'entry-1');
    expect(shared.songs.single.entryId, isNot(local.id));
    expect(shared.toJson()['songs'], [
      {'entryId': 'entry-1', 'title': 'Song A', 'artist': 'Band', 'bpm': null},
    ]);
  });
}
