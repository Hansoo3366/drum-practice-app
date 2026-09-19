import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/session/jam_session.dart';
import 'package:page_a_diddle/features/setlists/data/setlist_repository.dart';

void main() {
  late AppDatabase database;
  late List<String> ids;
  late SetlistRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    ids = ['setlist-1', 'entry-1', 'entry-2', 'pending-song-1'];
    repository = SetlistRepository(
      database: database,
      idGenerator: () => ids.removeAt(0),
      clock: () => DateTime(2026, 8, 19),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('저장된 세트리스트를 id로 조회한다', () async {
    final id = await repository.createSetlist('합주');
    final setlist = await repository.getSetlist(id);

    expect(setlist == null, isFalse);
    expect(setlist!.title, '합주');
  });

  test('현재 세트리스트 목록을 일회성으로 조회한다', () async {
    await repository.createSetlist('합주');

    final setlists = await repository.getSetlists();

    expect(setlists.map((setlist) => setlist.title), ['합주']);
  });

  test('세트리스트를 만들고 이름을 바꾼다', () async {
    final id = await repository.createSetlist(' 8월 합주 ');
    await repository.renameSetlist(id: id, title: '공연');

    final setlists = await repository.watchSetlists().first;

    expect(setlists.single.id, 'setlist-1');
    expect(setlists.single.title, '공연');
  });

  test('곡을 추가하고 순서와 BPM을 변경한다', () async {
    await _insertSong(database, id: 'song-1', title: '첫 곡', tempo: 120);
    await _insertSong(database, id: 'song-2', title: '둘째 곡', tempo: 130);
    final setlistId = await repository.createSetlist('합주');
    final firstEntry = await repository.addSong(
      setlistId: setlistId,
      songId: 'song-1',
    );
    final secondEntry = await repository.addSong(
      setlistId: setlistId,
      songId: 'song-2',
      tempoOverride: 140,
    );

    await repository.reorderSongs(
      setlistId: setlistId,
      entryIds: [secondEntry, firstEntry],
    );
    final items = await repository.getItems(setlistId);

    expect(items.map((item) => item.song.id), ['song-2', 'song-1']);
    expect(items.first.tempo, 140);
    expect(items.last.tempo, 120);
  });

  test('세트리스트 곡마다 메트로놈 프로필을 저장하고 복원한다', () async {
    await _insertSong(database, id: 'song-1', title: '첫 곡', tempo: 120);
    final setlistId = await repository.createSetlist('합주');
    final entryId = await repository.addSong(
      setlistId: setlistId,
      songId: 'song-1',
    );

    await repository.updateMetronome(
      entryId: entryId,
      music: const JamMusicState(
        bpm: 132,
        meterNumerator: 6,
        meterDenominator: 8,
        subdivision: 'triplet',
        accents: [2, 1, 1, 0, 1, 1],
      ),
    );

    final item = (await repository.getItems(setlistId)).single;
    expect(item.tempo, 132);
    expect(
      item.metronome,
      const JamMusicState(
        bpm: 132,
        meterNumerator: 6,
        meterDenominator: 8,
        subdivision: 'triplet',
        accents: [2, 1, 1, 0, 1, 1],
      ),
    );
  });

  test('곡 제거와 세트리스트 삭제가 항목에 반영된다', () async {
    await _insertSong(database, id: 'song-1', title: '첫 곡');
    await _insertSong(database, id: 'song-2', title: '둘째 곡');
    final setlistId = await repository.createSetlist('합주');
    final firstEntry = await repository.addSong(
      setlistId: setlistId,
      songId: 'song-1',
    );
    await repository.addSong(setlistId: setlistId, songId: 'song-2');

    await repository.removeSong(firstEntry);
    var items = await repository.watchItems(setlistId).first;
    expect(items.single.entry.position, 0);

    await repository.deleteSetlist(setlistId);
    items = await repository.watchItems(setlistId).first;
    expect(items, isEmpty);
  });

  test('공유 세트리스트를 로컬 목록으로 저장하고 없는 악보는 대기시킨다', () async {
    await _insertSong(database, id: 'song-1', title: '첫 곡', tempo: 120);
    ids = ['pending-song-1'];

    final result = await repository.importSharedSetlist(
      id: 'shared-1',
      title: '공연 세트',
      entries: const [
        SetlistImportEntry(entryId: 'shared-entry-1', title: '첫 곡', bpm: 120),
        SetlistImportEntry(entryId: 'shared-entry-2', title: '없는 곡', bpm: 130),
      ],
      localSongIdsByEntry: const {'shared-entry-1': 'song-1'},
    );

    final items = await repository.getItems('shared-1');
    final pending = await database
        .select(database.songs)
        .get()
        .then(
          (songs) => songs.singleWhere((song) => song.id == 'pending-song-1'),
        );

    expect(items.map((item) => item.song.title), ['첫 곡', '없는 곡']);
    expect(items.map((item) => item.song.id), ['song-1', 'pending-song-1']);
    expect(result.localSongIdsByEntry, const {'shared-entry-1': 'song-1'});
    expect(pending.sourceProvider, 'jam_pending');
    expect(pending.offlineAvailable, isFalse);

    await repository.replaceEntrySong(
      entryId: 'shared-entry-2',
      songId: 'song-1',
    );
    expect((await repository.getItems('shared-1')).last.song.id, 'song-1');
  });
}

Future<void> _insertSong(
  AppDatabase database, {
  required String id,
  required String title,
  int? tempo,
}) {
  final now = DateTime(2026, 8, 19);
  return database
      .into(database.songs)
      .insert(
        SongsCompanion.insert(
          id: id,
          title: title,
          defaultTempo: Value(tempo),
          sourcePath: 'scores/$id.pdf',
          createdAt: now,
          updatedAt: now,
        ),
      );
}
