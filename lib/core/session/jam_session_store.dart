import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:page_a_diddle/core/session/jam_session.dart';

class ActiveJam {
  const ActiveJam({required this.sessionId, required this.participantId});

  final String sessionId;
  final String participantId;
}

class JamNearbyRoom {
  const JamNearbyRoom({required this.code, this.title, this.participantCount});

  final String code;
  final String? title;
  final int? participantCount;
}

class JamHostScore {
  const JamHostScore({
    required this.entryId,
    required this.title,
    required this.bytes,
    this.artist,
    this.bpm,
  });

  static const maxBytes = 24 * 1024 * 1024;

  final String entryId;
  final String title;
  final String? artist;
  final int? bpm;
  final Uint8List bytes;

  Map<String, Object?> toJson() => {
    'entryId': entryId,
    'title': title,
    'artist': artist,
    'bpm': bpm,
    'bytes': base64Encode(bytes),
  };

  static JamHostScore? fromJson(Object? value) {
    if (value is! Map) return null;
    final entryId = value['entryId'];
    final title = value['title'];
    final encoded = value['bytes'];
    if (entryId is! String ||
        entryId.isEmpty ||
        entryId.length > 256 ||
        title is! String ||
        title.length > 512 ||
        encoded is! String) {
      return null;
    }
    try {
      final bytes = Uint8List.fromList(base64Decode(encoded));
      if (bytes.isEmpty || bytes.length > maxBytes) return null;
      return JamHostScore(
        entryId: entryId,
        title: title,
        artist: value['artist'] is String ? value['artist'] as String : null,
        bpm: value['bpm'] is int ? value['bpm'] as int : null,
        bytes: bytes,
      );
    } on FormatException {
      return null;
    }
  }
}

typedef JamHostScoreProvider = Future<JamHostScore?> Function(String entryId);

abstract class JamSessionStore {
  Future<({JamSession session, String participantId})> create({
    required String title,
    required String displayName,
    JamInstrument instrument = JamInstrument.drums,
    String? customInstrument,
    String? setlistId,
    JamSharedSetlist? sharedSetlist,
  });

  Future<({JamSession session, String participantId})> join({
    required String code,
    required String displayName,
    JamInstrument instrument = JamInstrument.drums,
    String? customInstrument,
  });

  Stream<JamSession?> watch(String sessionId);

  Future<List<JamNearbyRoom>> discoverRooms({
    Duration timeout = const Duration(seconds: 2),
  });

  Future<void> shareSetlist({
    required String sessionId,
    required String participantId,
    required JamSharedSetlist setlist,
  });

  Future<void> selectSong({
    required String sessionId,
    required String participantId,
    required String entryId,
  });

  Future<void> updatePosition({
    required String sessionId,
    required String participantId,
    required JamScorePosition position,
  });

  Future<void> updateMusic({
    required String sessionId,
    required String participantId,
    required JamMusicState music,
  });

  Future<DateTime?> updatePlaying({
    required String sessionId,
    required String participantId,
    required bool playing,
  });

  Future<void> updateReady({
    required String sessionId,
    required String participantId,
    required bool ready,
  });

  Future<void> updateCountInBars({
    required String sessionId,
    required String participantId,
    required int countInBars,
  });

  Future<void> updateClickMode({
    required String sessionId,
    required String participantId,
    required JamClickMode clickMode,
  });

  Future<void> updateLoop({
    required String sessionId,
    required String participantId,
    required JamLoopState loop,
  });

  void setHostScoreProvider(JamHostScoreProvider? provider);

  Future<JamHostScore?> requestHostScore({
    required String sessionId,
    required String participantId,
    required String entryId,
  });

  Future<void> leave({
    required String sessionId,
    required String participantId,
  });

  /// 현재 clock offset. 양수면 로컬 시계가 Conductor보다 앞서 있음.
  Duration get clockOffset;

  /// clock offset이 갱신될 때마다 발행하는 스트림.
  Stream<Duration> get clockOffsetStream;
}

class MemoryJamSessionStore implements JamSessionStore {
  MemoryJamSessionStore({
    String Function()? idGenerator,
    String Function()? codeGenerator,
    DateTime Function()? clock,
  }) : _idGenerator = idGenerator ?? _defaultId,
       _codeGenerator = codeGenerator ?? _defaultCode,
       _clock = clock ?? DateTime.now;

  final String Function() _idGenerator;
  final String Function() _codeGenerator;
  final DateTime Function() _clock;
  final Map<String, JamSession> _byId = {};
  final Map<String, String> _idByCode = {};
  final Map<String, Set<StreamController<JamSession?>>> _listeners = {};
  final StreamController<Duration> _clockOffsetController =
      StreamController<Duration>.broadcast();
  JamHostScoreProvider? _hostScoreProvider;

  @override
  Duration get clockOffset => Duration.zero;

  @override
  Stream<Duration> get clockOffsetStream => _clockOffsetController.stream;

  @override
  Future<List<JamNearbyRoom>> discoverRooms({
    Duration timeout = const Duration(seconds: 2),
  }) async => const [];

  @override
  void setHostScoreProvider(JamHostScoreProvider? provider) {
    _hostScoreProvider = provider;
  }

  @override
  Future<JamHostScore?> requestHostScore({
    required String sessionId,
    required String participantId,
    required String entryId,
  }) async {
    final session = _byId[sessionId];
    if (session == null || session.permissionsFor(participantId) == null) {
      throw const JamSessionException('세션 없음');
    }
    return _hostScoreProvider?.call(entryId);
  }

  @override
  Future<({JamSession session, String participantId})> create({
    required String title,
    required String displayName,
    JamInstrument instrument = JamInstrument.drums,
    String? customInstrument,
    String? setlistId,
    JamSharedSetlist? sharedSetlist,
  }) async {
    final name = normalizeDisplayName(displayName);
    final sessionTitle = title.trim().isEmpty
        ? defaultJamTitle(_clock())
        : title.trim();
    final conductor = JamParticipant(
      id: _idGenerator(),
      displayName: name,
      role: JamRole.conductor,
      instrument: instrument,
      customInstrument: normalizeJamCustomInstrument(customInstrument),
    );
    final currentEntryId = sharedSetlist == null
        ? null
        : jamEntryIdForSharedSetlist(sharedSetlist);
    final session = JamSession(
      id: _idGenerator(),
      code: _uniqueCode(),
      title: sessionTitle,
      setlistId: setlistId ?? sharedSetlist?.id,
      sharedSetlist: sharedSetlist,
      currentEntryId: currentEntryId,
      music: jamMusicForSong(
        currentEntryId == null
            ? null
            : sharedSetlist?.songByEntryId(currentEntryId),
      ),
      participants: [conductor],
      createdAt: _clock(),
    );
    _byId[session.id] = session;
    _idByCode[session.code] = session.id;
    _emit(session.id, session);
    return (session: session, participantId: conductor.id);
  }

  @override
  Future<({JamSession session, String participantId})> join({
    required String code,
    required String displayName,
    JamInstrument instrument = JamInstrument.drums,
    String? customInstrument,
  }) async {
    final parsed = parseJoinCode(code);
    if (parsed == null) {
      throw const JamSessionException('코드 4자리');
    }
    final sessionId = _idByCode[parsed];
    final session = sessionId == null ? null : _byId[sessionId];
    if (session == null) {
      throw const JamSessionException('세션 없음');
    }
    final name = normalizeDisplayName(displayName);
    final member = JamParticipant(
      id: _idGenerator(),
      displayName: name,
      role: JamRole.member,
      instrument: instrument,
      customInstrument: normalizeJamCustomInstrument(customInstrument),
      ready: false,
    );
    final next = session.copyWith(
      participants: [...session.participants, member],
    );
    _byId[session.id] = next;
    _emit(session.id, next);
    return (session: next, participantId: member.id);
  }

  @override
  Stream<JamSession?> watch(String sessionId) {
    final controller = StreamController<JamSession?>();
    _listeners.putIfAbsent(sessionId, () => {}).add(controller);
    controller
      ..add(_byId[sessionId])
      ..onCancel = () {
        _listeners[sessionId]?.remove(controller);
      };
    return controller.stream;
  }

  @override
  Future<void> shareSetlist({
    required String sessionId,
    required String participantId,
    required JamSharedSetlist setlist,
  }) async {
    final session = _byId[sessionId];
    if (session == null) {
      throw const JamSessionException('세션 없음');
    }
    final permissions = session.permissionsFor(participantId);
    if (permissions == null || !permissions.canLead) {
      throw const JamSessionException('권한 없음');
    }
    final entryId = jamEntryIdForSharedSetlist(
      setlist,
      previousEntryId: session.currentEntryId,
    );
    final music = jamMusicForSong(
      entryId == null ? null : setlist.songByEntryId(entryId),
    );
    final next = session.copyWith(
      setlistId: setlist.id,
      sharedSetlist: setlist,
      currentEntryId: entryId,
      clearCurrentEntryId: entryId == null,
      music: music,
      clearMusic: music == null,
      clearPosition: true,
      playing: false,
      clearStartAt: true,
      clearLoop: true,
    );
    _byId[sessionId] = next;
    _emit(sessionId, next);
  }

  @override
  Future<void> selectSong({
    required String sessionId,
    required String participantId,
    required String entryId,
  }) async {
    final session = _byId[sessionId];
    if (session == null) {
      throw const JamSessionException('세션 없음');
    }
    final permissions = session.permissionsFor(participantId);
    if (permissions == null || !permissions.canLead) {
      throw const JamSessionException('권한 없음');
    }
    final setlist = session.sharedSetlist;
    final song = setlist?.songByEntryId(entryId);
    if (setlist == null || song == null) {
      throw const JamSessionException('곡 없음');
    }
    final music = jamMusicForSong(song);
    final next = session.copyWith(
      currentEntryId: entryId,
      clearPosition: true,
      music: music,
      clearMusic: music == null,
      playing: false,
      clearStartAt: true,
      clearLoop: true,
    );
    _byId[sessionId] = next;
    _emit(sessionId, next);
  }

  @override
  Future<void> updatePosition({
    required String sessionId,
    required String participantId,
    required JamScorePosition position,
  }) async {
    final session = _byId[sessionId];
    if (session == null) {
      throw const JamSessionException('세션 없음');
    }
    final permissions = session.permissionsFor(participantId);
    if (permissions == null || !permissions.canLead) {
      throw const JamSessionException('권한 없음');
    }
    if (position.isEmpty) {
      throw const JamSessionException('위치 없음');
    }
    if (session.position == position) {
      return;
    }
    final next = session.copyWith(position: position);
    _byId[sessionId] = next;
    _emit(sessionId, next);
  }

  @override
  Future<void> updateMusic({
    required String sessionId,
    required String participantId,
    required JamMusicState music,
  }) async {
    final session = _byId[sessionId];
    if (session == null) {
      throw const JamSessionException('세션 없음');
    }
    final permissions = session.permissionsFor(participantId);
    if (permissions == null || !permissions.canLead) {
      throw const JamSessionException('권한 없음');
    }
    final normalized = normalizeJamMusic(music);
    if (normalized.isEmpty) {
      throw const JamSessionException('음악 정보 없음');
    }
    if (session.music == normalized) {
      return;
    }
    final setlist = session.sharedSetlist;
    final entryId = session.currentEntryId;
    final profile = jamMusicProfile(normalized);
    final nextSetlist = setlist == null || entryId == null || profile.isEmpty
        ? null
        : setlist.withSongMusic(entryId, profile);
    final next = session.copyWith(
      music: normalized,
      sharedSetlist: nextSetlist,
    );
    _byId[sessionId] = next;
    _emit(sessionId, next);
  }

  @override
  Future<DateTime?> updatePlaying({
    required String sessionId,
    required String participantId,
    required bool playing,
  }) async {
    final session = _byId[sessionId];
    if (session == null) {
      throw const JamSessionException('세션 없음');
    }
    final permissions = session.permissionsFor(participantId);
    if (permissions == null || !permissions.canLead) {
      throw const JamSessionException('권한 없음');
    }
    if (playing && !session.allMembersReady) {
      throw const JamSessionException(JamSessionException.notReady);
    }
    if (session.playing == playing) {
      return session.startAt;
    }
    final next = playing
        ? session.copyWith(playing: true, startAt: jamScheduleStartAt(_clock()))
        : session.copyWith(playing: false, clearStartAt: true);
    _byId[sessionId] = next;
    _emit(sessionId, next);
    return next.startAt;
  }

  @override
  Future<void> updateReady({
    required String sessionId,
    required String participantId,
    required bool ready,
  }) async {
    final session = _byId[sessionId];
    if (session == null) {
      throw const JamSessionException('세션 없음');
    }
    final participant = session.participantById(participantId);
    if (participant == null || participant.role != JamRole.member) {
      throw const JamSessionException('권한 없음');
    }
    if (participant.ready == ready) {
      return;
    }
    final next = session.copyWith(
      participants: [
        for (final item in session.participants)
          item.id == participantId ? item.copyWith(ready: ready) : item,
      ],
    );
    _byId[sessionId] = next;
    _emit(sessionId, next);
  }

  @override
  Future<void> updateCountInBars({
    required String sessionId,
    required String participantId,
    required int countInBars,
  }) async {
    final session = _byId[sessionId];
    if (session == null) {
      throw const JamSessionException('세션 없음');
    }
    final permissions = session.permissionsFor(participantId);
    if (permissions == null || !permissions.canLead) {
      throw const JamSessionException('권한 없음');
    }
    final bars = normalizeJamCountInBars(countInBars);
    if (session.countInBars == bars) {
      return;
    }
    final next = session.copyWith(countInBars: bars);
    _byId[sessionId] = next;
    _emit(sessionId, next);
  }

  @override
  Future<void> updateClickMode({
    required String sessionId,
    required String participantId,
    required JamClickMode clickMode,
  }) async {
    final session = _byId[sessionId];
    if (session == null) {
      throw const JamSessionException('세션 없음');
    }
    final permissions = session.permissionsFor(participantId);
    if (permissions == null || !permissions.canLead) {
      throw const JamSessionException('권한 없음');
    }
    if (session.clickMode == clickMode) {
      return;
    }
    final next = session.copyWith(clickMode: clickMode);
    _byId[sessionId] = next;
    _emit(sessionId, next);
  }

  @override
  Future<void> updateLoop({
    required String sessionId,
    required String participantId,
    required JamLoopState loop,
  }) async {
    final session = _byId[sessionId];
    if (session == null) {
      throw const JamSessionException('세션 없음');
    }
    final permissions = session.permissionsFor(participantId);
    if (permissions == null || !permissions.canLead) {
      throw const JamSessionException('권한 없음');
    }
    final normalized = loop.enabled
        ? normalizeJamLoop(
            enabled: true,
            startMeasure: loop.startMeasure,
            endMeasure: loop.endMeasure,
            section: loop.section,
          )
        : const JamLoopState(enabled: false);
    if (normalized == null) {
      throw const JamSessionException('Loop 없음');
    }
    if (session.loop == normalized) {
      return;
    }
    final next = session.copyWith(loop: normalized);
    _byId[sessionId] = next;
    _emit(sessionId, next);
  }

  @override
  Future<void> leave({
    required String sessionId,
    required String participantId,
  }) async {
    final session = _byId[sessionId];
    if (session == null) {
      return;
    }
    final leaving = session.participants
        .where((item) => item.id == participantId)
        .firstOrNull;
    if (leaving == null) {
      return;
    }
    if (leaving.role == JamRole.conductor) {
      _byId.remove(sessionId);
      _idByCode.remove(session.code);
      _emit(sessionId, null);
      return;
    }
    final next = session.copyWith(
      participants: session.participants
          .where((item) => item.id != participantId)
          .toList(),
    );
    _byId[sessionId] = next;
    _emit(sessionId, next);
  }

  String _uniqueCode() {
    for (var attempt = 0; attempt < 20; attempt++) {
      final code = _codeGenerator();
      if (!_idByCode.containsKey(code)) {
        return code;
      }
    }
    throw const JamSessionException('코드 생성 실패');
  }

  void _emit(String sessionId, JamSession? session) {
    for (final controller in [...?_listeners[sessionId]]) {
      if (!controller.isClosed) {
        controller.add(session);
      }
    }
  }

  static String _defaultId() =>
      DateTime.now().microsecondsSinceEpoch.toString();

  static String _defaultCode() {
    final value = Random().nextInt(9000) + 1000;
    return value.toString();
  }
}
