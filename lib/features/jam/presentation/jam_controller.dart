import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/core/session/jam_session.dart';
import 'package:page_a_diddle/core/session/jam_session_store.dart';
import 'package:page_a_diddle/core/session/lan_jam_session_store.dart';
import 'package:page_a_diddle/features/jam/domain/jam_shared_setlist_mapper.dart';
import 'package:page_a_diddle/features/jam/presentation/jam_session_error_l10n.dart';
import 'package:page_a_diddle/features/setlists/data/setlist_repository.dart';

class ActiveJamNotifier extends Notifier<ActiveJam?> {
  @override
  ActiveJam? build() => null;

  void clear() => state = null;

  Future<JamSharedSetlist?> _loadSharedSetlist(String setlistId) async {
    final repository = ref.read(setlistRepositoryProvider);
    final setlist = await repository.getSetlist(setlistId);
    if (setlist == null) {
      return null;
    }
    final songs = await repository.getItems(setlistId);
    return jamSharedSetlistFromLibrary(setlist: setlist, songs: songs);
  }

  Future<ActiveJam> create({
    required String title,
    required String displayName,
    JamInstrument instrument = JamInstrument.drums,
    String? customInstrument,
    String? setlistId,
    JamSharedSetlist? sharedSetlist,
  }) async {
    final shared =
        sharedSetlist ??
        (setlistId == null ? null : await _loadSharedSetlist(setlistId));
    final result = await ref
        .read(jamSessionStoreProvider)
        .create(
          title: title,
          displayName: displayName,
          instrument: instrument,
          customInstrument: customInstrument,
          setlistId: setlistId ?? shared?.id,
          sharedSetlist: shared,
        );
    final active = ActiveJam(
      sessionId: result.session.id,
      participantId: result.participantId,
    );
    state = active;
    return active;
  }

  Future<ActiveJam> join({
    required String code,
    required String displayName,
    JamInstrument instrument = JamInstrument.drums,
    String? customInstrument,
  }) async {
    final result = await ref
        .read(jamSessionStoreProvider)
        .join(
          code: code,
          displayName: displayName,
          instrument: instrument,
          customInstrument: customInstrument,
        );
    final active = ActiveJam(
      sessionId: result.session.id,
      participantId: result.participantId,
    );
    state = active;
    return active;
  }

  Future<void> shareSetlist(String setlistId) async {
    final active = state;
    if (active == null) {
      throw const JamSessionException(JamSessionErrorKeys.noSession);
    }
    final shared = await _loadSharedSetlist(setlistId);
    if (shared == null) {
      throw const JamSessionException(JamSessionErrorKeys.setlistNotFound);
    }
    await ref
        .read(jamSessionStoreProvider)
        .shareSetlist(
          sessionId: active.sessionId,
          participantId: active.participantId,
          setlist: shared,
        );
  }

  Future<void> selectSong(String entryId) async {
    final active = state;
    if (active == null) {
      throw const JamSessionException(JamSessionErrorKeys.noSession);
    }
    await ref
        .read(jamSessionStoreProvider)
        .selectSong(
          sessionId: active.sessionId,
          participantId: active.participantId,
          entryId: entryId,
        );
  }

  Future<void> updatePosition({int? page, int? measure}) async {
    final active = state;
    if (active == null) {
      return;
    }
    final position = JamScorePosition(page: page, measure: measure);
    if (position.isEmpty) {
      return;
    }
    try {
      await ref
          .read(jamSessionStoreProvider)
          .updatePosition(
            sessionId: active.sessionId,
            participantId: active.participantId,
            position: position,
          );
    } on JamSessionException {
      // Member나 세션 없음이면 무시
    }
  }

  Future<void> updateMusic({
    int? bpm,
    String? section,
    int? meterNumerator,
    int? meterDenominator,
    String? subdivision,
    List<int>? accents,
  }) async {
    final active = state;
    if (active == null) {
      return;
    }
    final music = JamMusicState(
      bpm: normalizeJamBpm(bpm),
      section: normalizeJamSection(section),
      meterNumerator: meterNumerator,
      meterDenominator: meterDenominator,
      subdivision: subdivision,
      accents: accents,
    );
    if (music.isEmpty) {
      return;
    }
    try {
      await ref
          .read(jamSessionStoreProvider)
          .updateMusic(
            sessionId: active.sessionId,
            participantId: active.participantId,
            music: music,
          );
    } on JamSessionException {
      // Member나 세션 없음이면 무시
    }
  }

  Future<DateTime?> updatePlaying(bool playing) async {
    final active = state;
    if (active == null) {
      return null;
    }
    try {
      return await ref
          .read(jamSessionStoreProvider)
          .updatePlaying(
            sessionId: active.sessionId,
            participantId: active.participantId,
            playing: playing,
          );
    } on JamSessionException catch (error) {
      if (error.message == JamSessionException.notReady) {
        rethrow;
      }
      // Member나 세션 없음이면 무시
      return null;
    }
  }

  Future<void> updateReady(bool ready) async {
    final active = state;
    if (active == null) {
      return;
    }
    try {
      await ref
          .read(jamSessionStoreProvider)
          .updateReady(
            sessionId: active.sessionId,
            participantId: active.participantId,
            ready: ready,
          );
    } on JamSessionException {
      // 방이 닫히는 순간에는 화면에서 세션 종료를 안내한다.
    }
  }

  Future<void> updateCountInBars(int countInBars) async {
    final active = state;
    if (active == null) {
      return;
    }
    try {
      await ref
          .read(jamSessionStoreProvider)
          .updateCountInBars(
            sessionId: active.sessionId,
            participantId: active.participantId,
            countInBars: countInBars,
          );
    } on JamSessionException {
      // Member나 세션 없음이면 무시
    }
  }

  Future<void> updateClickMode(JamClickMode clickMode) async {
    final active = state;
    if (active == null) {
      return;
    }
    try {
      await ref
          .read(jamSessionStoreProvider)
          .updateClickMode(
            sessionId: active.sessionId,
            participantId: active.participantId,
            clickMode: clickMode,
          );
    } on JamSessionException {
      // Member나 세션 없음이면 무시
    }
  }

  Future<void> updateLoop(JamLoopState loop) async {
    final active = state;
    if (active == null) {
      return;
    }
    try {
      await ref
          .read(jamSessionStoreProvider)
          .updateLoop(
            sessionId: active.sessionId,
            participantId: active.participantId,
            loop: loop,
          );
    } on JamSessionException {
      // Member나 세션 없음이면 무시
    }
  }

  Future<void> leave() async {
    final active = state;
    if (active == null) {
      return;
    }
    await ref
        .read(jamSessionStoreProvider)
        .leave(
          sessionId: active.sessionId,
          participantId: active.participantId,
        );
    state = null;
  }
}

final jamSessionStoreProvider = Provider<JamSessionStore>((ref) {
  final store = LanJamSessionStore();
  ref.onDispose(() {
    unawaited(store.dispose());
  });
  return store;
});

final activeJamProvider = NotifierProvider<ActiveJamNotifier, ActiveJam?>(
  ActiveJamNotifier.new,
);

final jamSessionProvider = StreamProvider.family<JamSession?, String>((
  ref,
  sessionId,
) {
  return ref.watch(jamSessionStoreProvider).watch(sessionId);
});
