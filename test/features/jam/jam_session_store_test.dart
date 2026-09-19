import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/core/session/jam_session.dart';
import 'package:page_a_diddle/core/session/jam_session_store.dart';

void main() {
  test('합주 호스트 악보 payload를 제공한다', () async {
    final store = MemoryJamSessionStore(codeGenerator: () => '7428');
    final created = await store.create(title: '합주', displayName: 'Hansoo');
    store.setHostScoreProvider(
      (_) async => JamHostScore(
        entryId: 'entry1',
        title: 'Song A',
        bytes: Uint8List.fromList('%PDF-1.7\n'.codeUnits),
      ),
    );

    final score = await store.requestHostScore(
      sessionId: created.session.id,
      participantId: created.participantId,
      entryId: 'entry1',
    );
    expect(score?.title, 'Song A');
    expect(JamHostScore.fromJson(score?.toJson())?.bytes, score?.bytes);
  });

  test('날짜로 기본 합주 이름을 만든다', () {
    expect(defaultJamTitle(DateTime(2026, 8, 20)), '8월 20일 합주');
  });

  test('참가 코드는 숫자 4자리만 받는다', () {
    expect(parseJoinCode('7428'), '7428');
    expect(parseJoinCode(' 74-28 '), '7428');
    expect(parseJoinCode('74'), isNull);
  });

  test('QR 초대 문구에서 코드를 읽는다', () {
    expect(jamInvitePayload('7428'), 'pageadiddle:jam:7428');
    expect(parseJamInvite('pageadiddle:jam:7428'), '7428');
    expect(parseJamInvite('7428'), '7428');
    expect(parseJamInvite('https://example.com'), isNull);
  });

  test('세션을 만들고 코드로 참가한다', () async {
    final ids = ['p1', 's1', 'p2'];
    final store = MemoryJamSessionStore(
      idGenerator: () => ids.removeAt(0),
      codeGenerator: () => '7428',
      clock: () => DateTime(2026, 8, 20),
    );

    final created = await store.create(title: '', displayName: ' Hansoo ');
    expect(created.session.code, '7428');
    expect(created.session.title, '8월 20일 합주');
    expect(created.session.conductor.displayName, 'Hansoo');
    expect(created.participantId, 'p1');

    final joined = await store.join(code: '7428', displayName: 'Bass');
    expect(joined.session.members.single.displayName, 'Bass');
    expect(joined.participantId, 'p2');
    expect(
      created.session.permissionsFor(created.participantId)?.isConductor,
      isTrue,
    );
    expect(
      joined.session.permissionsFor(joined.participantId)?.isMember,
      isTrue,
    );
  });

  test('생성·참가자가 선택한 악기 파트를 공유한다', () async {
    final ids = ['p1', 's1', 'p2'];
    final store = MemoryJamSessionStore(
      idGenerator: () => ids.removeAt(0),
      codeGenerator: () => '7428',
    );

    final created = await store.create(
      title: '합주',
      displayName: 'Vocal',
      instrument: JamInstrument.vocal,
    );
    final joined = await store.join(
      code: '7428',
      displayName: 'Other',
      instrument: JamInstrument.other,
      customInstrument: '색소폰',
    );

    expect(created.session.conductor.instrument, JamInstrument.vocal);
    expect(joined.session.members.single.instrument, JamInstrument.other);
    expect(joined.session.members.single.customInstrument, '색소폰');
  });

  test('Conductor만 초대와 합주 리드를 한다', () {
    const conductor = JamPermissions(JamRole.conductor);
    const member = JamPermissions(JamRole.member);

    expect(conductor.canInvite, isTrue);
    expect(conductor.canLead, isTrue);
    expect(conductor.canFollow, isFalse);
    expect(conductor.roleLabel, 'Conductor');
    expect(conductor.leaveLabel, '끝내기');

    expect(member.canInvite, isFalse);
    expect(member.canLead, isFalse);
    expect(member.canFollow, isTrue);
    expect(member.roleLabel, 'Member');
    expect(member.leaveLabel, '나가기');
  });

  test('세트리스트에서 이전·다음 곡을 고른다', () {
    const setlist = JamSharedSetlist(
      id: 'sl1',
      title: '공연',
      songs: [
        JamSharedSong(entryId: 'a', title: 'A'),
        JamSharedSong(entryId: 'b', title: 'B'),
        JamSharedSong(entryId: 'c', title: 'C'),
      ],
    );

    expect(jamAdjacentEntryId(setlist, currentEntryId: 'b', delta: -1), 'a');
    expect(jamAdjacentEntryId(setlist, currentEntryId: 'b', delta: 1), 'c');
    expect(jamAdjacentEntryId(setlist, currentEntryId: 'a', delta: -1), isNull);
    expect(jamEntryIdForSharedSetlist(setlist, previousEntryId: 'b'), 'b');
    expect(
      jamEntryIdForSharedSetlist(setlist, previousEntryId: 'missing'),
      'a',
    );
  });

  test('Conductor가 세트리스트를 공유하면 참가자도 본다', () async {
    final ids = ['p1', 's1', 'p2'];
    final store = MemoryJamSessionStore(
      idGenerator: () => ids.removeAt(0),
      codeGenerator: () => '7428',
    );
    const shared = JamSharedSetlist(
      id: 'sl1',
      title: '공연',
      songs: [JamSharedSong(entryId: 'entry1', title: 'Song A', bpm: 120)],
    );
    final created = await store.create(
      title: '합주',
      displayName: 'Hansoo',
      sharedSetlist: shared,
    );
    expect(created.session.sharedSetlist?.title, '공연');
    expect(created.session.setlistId, 'sl1');
    expect(created.session.currentEntryId, 'entry1');
    expect(created.session.music?.bpm, 120);

    final joined = await store.join(code: '7428', displayName: 'Bass');
    expect(joined.session.sharedSetlist?.songs.single.title, 'Song A');
    expect(joined.session.currentEntryId, 'entry1');

    await store.updateReady(
      sessionId: created.session.id,
      participantId: joined.participantId,
      ready: true,
    );
    expect(
      (await store.watch(created.session.id).first)?.members.single.ready,
      isTrue,
    );

    await store.shareSetlist(
      sessionId: created.session.id,
      participantId: created.participantId,
      setlist: const JamSharedSetlist(
        id: 'sl2',
        title: '연습',
        songs: [
          JamSharedSong(
            entryId: 'entry2',
            title: 'Song B',
            music: JamMusicState(
              bpm: 112,
              meterNumerator: 3,
              meterDenominator: 4,
              subdivision: 'eighth',
              accents: [2, 1, 1],
            ),
          ),
          JamSharedSong(
            entryId: 'entry3',
            title: 'Song C',
            music: JamMusicState(
              bpm: 96,
              meterNumerator: 6,
              meterDenominator: 8,
              subdivision: 'sixteenth',
              accents: [2, 1, 1, 1, 1, 1],
            ),
          ),
        ],
      ),
    );
    final after = await store.watch(created.session.id).first;
    expect(after?.sharedSetlist?.title, '연습');
    expect(after?.currentEntryId, 'entry2');
    expect(
      after?.music,
      const JamMusicState(
        bpm: 112,
        meterNumerator: 3,
        meterDenominator: 4,
        subdivision: 'eighth',
        accents: [2, 1, 1],
      ),
    );

    await store.selectSong(
      sessionId: created.session.id,
      participantId: created.participantId,
      entryId: 'entry3',
    );
    expect(
      (await store.watch(created.session.id).first)?.currentEntryId,
      'entry3',
    );
    expect(
      (await store.watch(created.session.id).first)?.music,
      const JamMusicState(
        bpm: 96,
        meterNumerator: 6,
        meterDenominator: 8,
        subdivision: 'sixteenth',
        accents: [2, 1, 1, 1, 1, 1],
      ),
    );
    expect((await store.watch(created.session.id).first)?.position, isNull);

    await store.updatePosition(
      sessionId: created.session.id,
      participantId: created.participantId,
      position: const JamScorePosition(page: 3, measure: 12),
    );
    expect(
      (await store.watch(created.session.id).first)?.position,
      const JamScorePosition(page: 3, measure: 12),
    );
    expect(
      jamPositionLabel(const JamScorePosition(page: 3, measure: 12)),
      '12마디',
    );

    await store.updateMusic(
      sessionId: created.session.id,
      participantId: created.participantId,
      music: const JamMusicState(
        bpm: 128,
        section: 'chorus',
        meterNumerator: 7,
        meterDenominator: 8,
        subdivision: 'triplet',
        accents: [2, 1, 0, 1, 1, 1, 1],
      ),
    );
    expect(
      (await store.watch(created.session.id).first)?.music,
      const JamMusicState(
        bpm: 128,
        section: 'CHORUS',
        meterNumerator: 7,
        meterDenominator: 8,
        subdivision: 'triplet',
        accents: [2, 1, 0, 1, 1, 1, 1],
      ),
    );
    expect(
      (await store.watch(created.session.id).first)?.sharedSetlist
          ?.songByEntryId('entry3')
          ?.music,
      const JamMusicState(
        bpm: 128,
        meterNumerator: 7,
        meterDenominator: 8,
        subdivision: 'triplet',
        accents: [2, 1, 0, 1, 1, 1, 1],
      ),
    );
    expect(
      jamMusicLabel(
        const JamMusicState(
          bpm: 128,
          section: 'CHORUS',
          meterNumerator: 7,
          meterDenominator: 8,
          subdivision: 'triplet',
          accents: [2, 1, 0, 1, 1, 1, 1],
        ),
      ),
      '128 BPM · 7/8 · ♪♪♪ · CHORUS',
    );
    final encoded = (await store.watch(created.session.id).first)!.toJson();
    expect(
      JamSession.fromJson(encoded).music,
      const JamMusicState(
        bpm: 128,
        section: 'CHORUS',
        meterNumerator: 7,
        meterDenominator: 8,
        subdivision: 'triplet',
        accents: [2, 1, 0, 1, 1, 1, 1],
      ),
    );

    await store.updatePlaying(
      sessionId: created.session.id,
      participantId: created.participantId,
      playing: true,
    );
    expect((await store.watch(created.session.id).first)?.playing, isTrue);
    final started = await store.watch(created.session.id).first;
    expect(started?.startAt, isNotNull);
    expect(
      jamWaitUntilStart(
        started!.startAt!,
        started.startAt!.subtract(const Duration(milliseconds: 100)),
      ),
      const Duration(milliseconds: 100),
    );
    expect(
      jamWaitUntilStart(
        started.startAt!,
        started.startAt!.add(const Duration(milliseconds: 10)),
      ),
      Duration.zero,
    );

    await store.updateCountInBars(
      sessionId: created.session.id,
      participantId: created.participantId,
      countInBars: 2,
    );
    expect((await store.watch(created.session.id).first)?.countInBars, 2);
    expect(jamCountInLabel(2), 'Count-In 2마디');

    await store.updateClickMode(
      sessionId: created.session.id,
      participantId: created.participantId,
      clickMode: JamClickMode.individual,
    );
    expect(
      (await store.watch(created.session.id).first)?.clickMode,
      JamClickMode.individual,
    );

    await store.updateLoop(
      sessionId: created.session.id,
      participantId: created.participantId,
      loop: const JamLoopState(
        enabled: true,
        startMeasure: 8,
        endMeasure: 16,
        section: 'BRIDGE',
      ),
    );
    final looped = await store.watch(created.session.id).first;
    expect(looped?.loop?.isActive, isTrue);
    expect(jamLoopLabel(looped?.loop), 'Loop BRIDGE · 8–16마디');

    expect(
      () => store.selectSong(
        sessionId: created.session.id,
        participantId: joined.participantId,
        entryId: 'entry2',
      ),
      throwsA(
        isA<JamSessionException>().having(
          (error) => error.message,
          'message',
          '권한 없음',
        ),
      ),
    );

    expect(
      () => store.shareSetlist(
        sessionId: created.session.id,
        participantId: joined.participantId,
        setlist: shared,
      ),
      throwsA(
        isA<JamSessionException>().having(
          (error) => error.message,
          'message',
          '권한 없음',
        ),
      ),
    );
  });

  test('없는 코드와 빈 이름은 막는다', () async {
    final store = MemoryJamSessionStore(codeGenerator: () => '1111');

    await store.create(title: '합주', displayName: 'Hansoo');

    expect(
      () => store.join(code: '0000', displayName: 'Bass'),
      throwsA(
        isA<JamSessionException>().having(
          (error) => error.message,
          'message',
          '세션 없음',
        ),
      ),
    );
    expect(
      () => store.create(title: '합주', displayName: '  '),
      throwsA(
        isA<JamSessionException>().having(
          (error) => error.message,
          'message',
          '이름 필요',
        ),
      ),
    );
  });

  test('연결된 사람만 센다', () {
    expect(
      jamPresence([
        const JamParticipant(
          id: 'p1',
          displayName: 'Hansoo',
          role: JamRole.conductor,
        ),
        const JamParticipant(
          id: 'p2',
          displayName: 'Bass',
          role: JamRole.member,
          connected: false,
        ),
        const JamParticipant(
          id: 'p3',
          displayName: 'Guitar',
          role: JamRole.member,
        ),
      ]).connectedCount,
      2,
    );
    expect(
      jamPresenceLabel(const JamPresence(connectedCount: 2, total: 3)),
      '2명',
    );
  });

  test('응답이 끊기면 먼저 자리를 비우고 다음에 뺀다', () {
    final now = DateTime(2026, 8, 20, 15);
    expect(
      jamPresenceTick(
        connected: true,
        now: now,
        lastSeen: now.subtract(const Duration(seconds: 2)),
        staleAfter: const Duration(seconds: 6),
      ),
      JamPresenceTick.stay,
    );
    expect(
      jamPresenceTick(
        connected: true,
        now: now,
        lastSeen: now.subtract(const Duration(seconds: 6)),
        staleAfter: const Duration(seconds: 6),
      ),
      JamPresenceTick.away,
    );
    expect(
      jamPresenceTick(
        connected: false,
        now: now,
        lastSeen: now.subtract(const Duration(seconds: 6)),
        staleAfter: const Duration(seconds: 6),
      ),
      JamPresenceTick.drop,
    );
  });

  test('멤버가 나가면 목록에서 빠진다', () async {
    final ids = ['p1', 's1', 'p2'];
    final store = MemoryJamSessionStore(
      idGenerator: () => ids.removeAt(0),
      codeGenerator: () => '7428',
    );
    final created = await store.create(title: '합주', displayName: 'Hansoo');
    final joined = await store.join(code: '7428', displayName: 'Bass');

    await store.leave(
      sessionId: created.session.id,
      participantId: joined.participantId,
    );

    final session = await store.watch(created.session.id).first;
    expect(session?.members, isEmpty);
    expect(jamPresence(session!.participants).connectedCount, 1);
  });

  test('Conductor가 나가면 세션이 끝난다', () async {
    final ids = ['p1', 's1', 'p2'];
    final store = MemoryJamSessionStore(
      idGenerator: () => ids.removeAt(0),
      codeGenerator: () => '7428',
    );
    final created = await store.create(title: '합주', displayName: 'Hansoo');
    await store.join(code: '7428', displayName: 'Bass');

    await store.leave(
      sessionId: created.session.id,
      participantId: created.participantId,
    );

    expect(await store.watch(created.session.id).first, isNull);
    expect(
      () => store.join(code: '7428', displayName: 'Guitar'),
      throwsA(isA<JamSessionException>()),
    );
  });
}
