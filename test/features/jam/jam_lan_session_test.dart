import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/core/session/jam_lan_codec.dart';
import 'package:page_a_diddle/core/session/jam_session.dart';
import 'package:page_a_diddle/core/session/jam_session_store.dart';
import 'package:page_a_diddle/core/session/lan_jam_session_store.dart';

void main() {
  test('시작 대기 시간을 계산한다', () {
    final start = DateTime.utc(2026, 8, 20, 7, 0, 1);
    expect(
      jamScheduleStartAt(DateTime.utc(2026, 8, 20, 7, 0, 0)),
      DateTime.utc(2026, 8, 20, 7, 0, 0, 750),
    );
    expect(
      jamWaitUntilStart(start, DateTime.utc(2026, 8, 20, 7, 0, 0, 500)),
      const Duration(milliseconds: 500),
    );
    expect(
      jamWaitUntilStart(start, DateTime.utc(2026, 8, 20, 7, 0, 2)),
      Duration.zero,
    );
  });

  test('세션 JSON을 복원한다', () {
    final session = JamSession(
      id: 's1',
      code: '7428',
      title: '합주',
      participants: const [
        JamParticipant(
          id: 'p1',
          displayName: 'Hansoo',
          role: JamRole.conductor,
        ),
      ],
      createdAt: DateTime.utc(2026, 8, 20, 6, 15),
    );

    final decoded = jsonDecode(jsonEncode(session.toJson()));
    expect(decoded, isA<Map<Object?, Object?>>());
    final restored = JamSession.fromJson(
      Map<String, dynamic>.from(decoded as Map),
    );

    expect(restored.code, '7428');
    expect(restored.conductor.displayName, 'Hansoo');
    expect(restored.conductor.connected, isTrue);
    expect(restored.countInBars, 1);
    expect(restored.clickMode, JamClickMode.individual);
  });

  test('합주 메트로놈은 모든 기기에서 로컬 재생한다', () {
    expect(jamShouldPlayClick(isConductor: false), isTrue);
    expect(
      jamShouldPlayClick(isConductor: true, mode: JamClickMode.host),
      isTrue,
    );
    expect(
      jamShouldPlayClick(isConductor: false, mode: JamClickMode.host),
      isTrue,
    );
    expect(
      jamShouldPlayClick(isConductor: false, mode: JamClickMode.individual),
      isTrue,
    );
    expect(jamClickModeLabel(JamClickMode.host), '공통 메트로놈');
  });

  test('Loop 상태를 정규화한다', () {
    expect(
      normalizeJamLoop(enabled: false),
      const JamLoopState(enabled: false),
    );
    expect(
      normalizeJamLoop(enabled: true, startMeasure: 5, endMeasure: 5),
      isNull,
    );
    expect(
      jamLoopLabel(
        const JamLoopState(
          enabled: true,
          startMeasure: 2,
          endMeasure: 8,
          section: 'VERSE',
        ),
      ),
      'Loop VERSE · 2–8마디',
    );
  });

  test('세트리스트 JSON을 복원한다', () {
    const shared = JamSharedSetlist(
      id: 'sl1',
      title: '공연',
      songs: [
        JamSharedSong(
          entryId: 'entry1',
          title: 'Song A',
          artist: 'Band',
          bpm: 120,
        ),
      ],
    );
    final session = JamSession(
      id: 's1',
      code: '7428',
      title: '합주',
      sharedSetlist: shared,
      participants: const [
        JamParticipant(
          id: 'p1',
          displayName: 'Hansoo',
          role: JamRole.conductor,
        ),
      ],
      createdAt: DateTime.utc(2026, 8, 20, 6, 15),
    );

    final restored = JamSession.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(jsonEncode(session.toJson())) as Map,
      ),
    );

    expect(restored.sharedSetlist?.title, '공연');
    expect(restored.sharedSetlist?.songs.single.bpm, 120);
  });

  test('구버전 곡 payload는 BPM을 유지하고 새 프로필은 선택적으로 복원한다', () {
    final legacy = JamSharedSong.fromJson(const {
      'songId': 'legacy-1',
      'title': 'Legacy',
      'bpm': 128,
    });
    expect(jamMusicForSong(legacy)?.bpm, 128);

    const current = JamSharedSong(
      entryId: 'entry-1',
      title: 'Current',
      music: JamMusicState(
        bpm: 132,
        meterNumerator: 6,
        meterDenominator: 8,
        subdivision: 'triplet',
        accents: [2, 1, 1, 1, 1, 1],
      ),
    );
    final json = current.toJson();
    expect(json['bpm'], 132);
    expect(
      JamSharedSong.fromJson(Map<String, dynamic>.from(json)).music,
      current.music,
    );
  });

  test('LAN 알림 메시지를 읽는다', () {
    final json = decodeJamLanMessage(
      jsonEncode(
        const JamLanAnnounce(
          code: '7428',
          port: 47828,
          title: '저녁 합주',
          participantCount: 2,
        ).toJson(),
      ),
    );

    expect(announceFromMessage(json!)?.code, '7428');
    expect(announceFromMessage(json)?.port, 47828);
    expect(announceFromMessage(json)?.title, '저녁 합주');
    expect(announceFromMessage(json)?.participantCount, 2);
  });

  test('같은 Wi-Fi의 공개 방을 탐색한다', () async {
    final host = LanJamSessionStore(
      tcpPort: 47950,
      udpPort: 47951,
      codeGenerator: () => '7428',
    );
    final browser = LanJamSessionStore(tcpPort: 47952, udpPort: 47951);
    addTearDown(() async {
      await browser.dispose();
      await host.dispose();
    });

    await host.create(title: '저녁 합주', displayName: 'Hansoo');
    final rooms = await browser.discoverRooms(
      timeout: const Duration(milliseconds: 450),
    );

    expect(
      rooms,
      contains(
        isA<JamNearbyRoom>()
            .having((room) => room.code, 'code', '7428')
            .having((room) => room.title, 'title', '저녁 합주')
            .having((room) => room.participantCount, 'participants', 1),
      ),
    );
  });

  test('같은 기기의 루프백에서 코드로 참가한다', () async {
    final host = LanJamSessionStore(
      tcpPort: 47910,
      udpPort: 47911,
      codeGenerator: () => '7428',
      joinTimeout: const Duration(seconds: 3),
    );
    final guest = LanJamSessionStore(
      tcpPort: 47912,
      udpPort: 47911,
      joinTimeout: const Duration(seconds: 3),
    );
    addTearDown(() async {
      await guest.dispose();
      await host.dispose();
    });

    await host.create(
      title: '합주',
      displayName: 'Hansoo',
      instrument: JamInstrument.drums,
    );
    final joined = await guest.join(
      code: '7428',
      displayName: 'Bass',
      instrument: JamInstrument.bass,
    );

    expect(joined.session.conductor.displayName, 'Hansoo');
    expect(joined.session.members.single.displayName, 'Bass');
    expect(joined.session.members.single.instrument, JamInstrument.bass);
    expect(jamPresence(joined.session.participants).connectedCount, 2);
  });

  test('게스트가 끊기면 호스트 목록에서 빠진다', () async {
    final host = LanJamSessionStore(
      tcpPort: 47920,
      udpPort: 47921,
      codeGenerator: () => '7428',
      joinTimeout: const Duration(seconds: 3),
    );
    final guest = LanJamSessionStore(
      tcpPort: 47922,
      udpPort: 47921,
      joinTimeout: const Duration(seconds: 3),
    );
    addTearDown(() async {
      await guest.dispose();
      await host.dispose();
    });

    final created = await host.create(title: '합주', displayName: 'Hansoo');
    await guest.join(code: '7428', displayName: 'Bass');
    await guest.dispose();

    final session = await host
        .watch(created.session.id)
        .firstWhere((value) => value != null && value.members.isEmpty)
        .timeout(const Duration(seconds: 3));

    expect(jamPresence(session!.participants).connectedCount, 1);
  });

  test('호스트가 닫히면 게스트 세션이 종료된다', () async {
    final host = LanJamSessionStore(
      tcpPort: 47924,
      udpPort: 47925,
      codeGenerator: () => '7428',
      joinTimeout: const Duration(seconds: 3),
    );
    final guest = LanJamSessionStore(
      tcpPort: 47926,
      udpPort: 47925,
      joinTimeout: const Duration(seconds: 3),
    );
    addTearDown(() async {
      await guest.dispose();
      await host.dispose();
    });

    final created = await host.create(title: '합주', displayName: 'Hansoo');
    final joined = await guest.join(code: '7428', displayName: 'Bass');
    final updates = guest.watch(joined.session.id);

    await host.leave(
      sessionId: created.session.id,
      participantId: created.participantId,
    );

    final closed = await updates
        .firstWhere((value) => value == null)
        .timeout(const Duration(seconds: 3));
    expect(closed, isNull);
  });

  test('호스트가 공유한 세트리스트를 게스트가 받는다', () async {
    final host = LanJamSessionStore(
      tcpPort: 47930,
      udpPort: 47931,
      codeGenerator: () => '7428',
      joinTimeout: const Duration(seconds: 3),
    );
    final guest = LanJamSessionStore(
      tcpPort: 47932,
      udpPort: 47931,
      joinTimeout: const Duration(seconds: 3),
    );
    addTearDown(() async {
      await guest.dispose();
      await host.dispose();
    });

    const shared = JamSharedSetlist(
      id: 'sl1',
      title: '공연',
      songs: [
        JamSharedSong(
          entryId: 'entry1',
          title: 'Song A',
          music: JamMusicState(
            bpm: 120,
            meterNumerator: 5,
            meterDenominator: 4,
            subdivision: 'sixteenth',
            accents: [2, 1, 1, 0, 1],
          ),
        ),
      ],
    );
    final created = await host.create(
      title: '합주',
      displayName: 'Hansoo',
      sharedSetlist: shared,
    );
    final joined = await guest.join(code: '7428', displayName: 'Bass');
    expect(joined.session.sharedSetlist?.title, '공연');
    expect(
      joined.session.music,
      const JamMusicState(
        bpm: 120,
        meterNumerator: 5,
        meterDenominator: 4,
        subdivision: 'sixteenth',
        accents: [2, 1, 1, 0, 1],
      ),
    );

    await guest.updateReady(
      sessionId: joined.session.id,
      participantId: joined.participantId,
      ready: true,
    );

    await host.shareSetlist(
      sessionId: created.session.id,
      participantId: created.participantId,
      setlist: const JamSharedSetlist(
        id: 'sl2',
        title: '연습',
        songs: [
          JamSharedSong(entryId: 'entry2', title: 'Song B'),
          JamSharedSong(entryId: 'entry3', title: 'Song C'),
        ],
      ),
    );

    final updated = await guest
        .watch(joined.session.id)
        .firstWhere((value) => value?.sharedSetlist?.title == '연습')
        .timeout(const Duration(seconds: 3));
    expect(updated?.currentEntryId, 'entry2');

    await host.selectSong(
      sessionId: created.session.id,
      participantId: created.participantId,
      entryId: 'entry3',
    );
    final songChanged = await guest
        .watch(joined.session.id)
        .firstWhere((value) => value?.currentEntryId == 'entry3')
        .timeout(const Duration(seconds: 3));
    expect(songChanged?.currentSong?.title, 'Song C');

    await host.updatePosition(
      sessionId: created.session.id,
      participantId: created.participantId,
      position: const JamScorePosition(page: 2, measure: 8),
    );
    final moved = await guest
        .watch(joined.session.id)
        .firstWhere(
          (value) =>
              value?.position == const JamScorePosition(page: 2, measure: 8),
        )
        .timeout(const Duration(seconds: 3));
    expect(jamPositionLabel(moved?.position), '8마디');

    await host.updateMusic(
      sessionId: created.session.id,
      participantId: created.participantId,
      music: const JamMusicState(
        bpm: 110,
        section: 'bridge',
        meterNumerator: 6,
        meterDenominator: 8,
        subdivision: 'sixteenth',
        accents: [2, 1, 1, 0, 1, 1],
      ),
    );
    final music = await guest
        .watch(joined.session.id)
        .firstWhere(
          (value) =>
              value?.music ==
              const JamMusicState(
                bpm: 110,
                section: 'BRIDGE',
                meterNumerator: 6,
                meterDenominator: 8,
                subdivision: 'sixteenth',
                accents: [2, 1, 1, 0, 1, 1],
              ),
        )
        .timeout(const Duration(seconds: 3));
    expect(jamMusicLabel(music?.music), '110 BPM · 6/8 · ♬ · BRIDGE');

    await host.updatePlaying(
      sessionId: created.session.id,
      participantId: created.participantId,
      playing: true,
    );
    final started = await guest
        .watch(joined.session.id)
        .firstWhere((value) => value?.playing == true)
        .timeout(const Duration(seconds: 3));
    expect(started?.playing, isTrue);
    expect(started?.startAt, isNotNull);

    await host.updateCountInBars(
      sessionId: created.session.id,
      participantId: created.participantId,
      countInBars: 4,
    );
    final countIn = await guest
        .watch(joined.session.id)
        .firstWhere((value) => value?.countInBars == 4)
        .timeout(const Duration(seconds: 3));
    expect(countIn?.countInBars, 4);

    await host.updateClickMode(
      sessionId: created.session.id,
      participantId: created.participantId,
      clickMode: JamClickMode.individual,
    );
    final mode = await guest
        .watch(joined.session.id)
        .firstWhere((value) => value?.clickMode == JamClickMode.individual)
        .timeout(const Duration(seconds: 3));
    expect(mode?.clickMode, JamClickMode.individual);

    await host.updateLoop(
      sessionId: created.session.id,
      participantId: created.participantId,
      loop: const JamLoopState(enabled: true, startMeasure: 4, endMeasure: 12),
    );
    final looped = await guest
        .watch(joined.session.id)
        .firstWhere((value) => value?.loop?.isActive == true)
        .timeout(const Duration(seconds: 3));
    expect(jamLoopLabel(looped?.loop), 'Loop 4–12마디');
  });

  test('게스트가 필요한 호스트 PDF만 요청한다', () async {
    final host = LanJamSessionStore(
      tcpPort: 47940,
      udpPort: 47941,
      codeGenerator: () => '7428',
      joinTimeout: const Duration(seconds: 3),
    );
    final guest = LanJamSessionStore(
      tcpPort: 47942,
      udpPort: 47941,
      joinTimeout: const Duration(seconds: 3),
    );
    addTearDown(() async {
      await guest.dispose();
      await host.dispose();
    });

    final created = await host.create(title: '합주', displayName: 'Hansoo');
    host.setHostScoreProvider(
      (_) async => JamHostScore(
        entryId: 'entry1',
        title: 'Song A',
        bpm: 120,
        bytes: Uint8List.fromList('%PDF-1.7\n'.codeUnits),
      ),
    );
    final joined = await guest.join(
      code: created.session.code,
      displayName: 'Bass',
    );

    final score = await guest.requestHostScore(
      sessionId: joined.session.id,
      participantId: joined.participantId,
      entryId: 'entry1',
    );
    expect(score?.title, 'Song A');
    expect(score?.bpm, 120);
    expect(String.fromCharCodes(score!.bytes), startsWith('%PDF-'));
  });
}
