enum JamRole { conductor, member }

/// Musical part a participant is playing in the session.
enum JamInstrument { vocal, guitar, bass, drums, keyboard, other }

JamInstrument jamInstrumentFromName(String? raw) {
  for (final instrument in JamInstrument.values) {
    if (instrument.name == raw) {
      return instrument;
    }
  }
  // Older session payloads did not contain a part. The app is drum-first, so
  // keep those participants useful instead of showing an unknown role.
  return JamInstrument.drums;
}

String? normalizeJamCustomInstrument(String? raw) {
  final value = raw?.trim();
  return value == null || value.isEmpty ? null : value;
}

/// Conductor는 세션을 리드하고, Member는 Follow/Return to Live로 따른다.
class JamPermissions {
  const JamPermissions(this.role);

  final JamRole role;

  bool get isConductor => role == JamRole.conductor;

  bool get isMember => role == JamRole.member;

  /// 초대 코드·QR 표시
  bool get canInvite => isConductor;

  /// 곡·세트리스트·BPM·위치·Start/Stop 등 합주 리드
  bool get canLead => isConductor;

  /// Member가 Follow Conductor / Return to Live를 쓸 수 있는지
  bool get canFollow => isMember;

  String get roleLabel => isConductor ? 'Conductor' : 'Member';

  String get leaveLabel => isConductor ? '끝내기' : '나가기';
}

class JamParticipant {
  const JamParticipant({
    required this.id,
    required this.displayName,
    required this.role,
    this.instrument = JamInstrument.drums,
    this.customInstrument,
    this.connected = true,
    this.ready = true,
  });

  factory JamParticipant.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final displayName = json['displayName'];
    final role = json['role'];
    if (id is! String || displayName is! String || role is! String) {
      throw const FormatException('참가자');
    }
    final instrument = json['instrument'] ?? json['part'];
    final customInstrument = json['customInstrument'];
    final connected = json['connected'];
    final ready = json['ready'];
    return JamParticipant(
      id: id,
      displayName: displayName,
      role: JamRole.values.byName(role),
      instrument: jamInstrumentFromName(
        instrument is String ? instrument : null,
      ),
      customInstrument: customInstrument is String
          ? customInstrument.trim().isEmpty
                ? null
                : customInstrument.trim()
          : null,
      connected: connected is bool ? connected : true,
      ready: ready is bool ? ready : true,
    );
  }

  final String id;
  final String displayName;
  final JamRole role;
  final JamInstrument instrument;
  final String? customInstrument;
  final bool connected;
  final bool ready;

  JamParticipant copyWith({bool? connected, bool? ready}) {
    return JamParticipant(
      id: id,
      displayName: displayName,
      role: role,
      instrument: instrument,
      customInstrument: customInstrument,
      connected: connected ?? this.connected,
      ready: ready ?? this.ready,
    );
  }

  Map<String, Object> toJson() {
    final json = <String, Object>{
      'id': id,
      'displayName': displayName,
      'role': role.name,
      'instrument': instrument.name,
      'connected': connected,
      'ready': ready,
    };
    if (customInstrument case final value?) {
      json['customInstrument'] = value;
    }
    return json;
  }
}

class JamPresence {
  const JamPresence({required this.connectedCount, required this.total});

  final int connectedCount;
  final int total;
}

JamPresence jamPresence(Iterable<JamParticipant> participants) {
  final list = participants.toList();
  return JamPresence(
    connectedCount: list.where((item) => item.connected).length,
    total: list.length,
  );
}

String jamPresenceLabel(JamPresence presence) => '${presence.connectedCount}명';

class JamSharedSong {
  const JamSharedSong({
    required this.entryId,
    required this.title,
    this.artist,
    this.bpm,
    this.music,
  });

  factory JamSharedSong.fromJson(Map<String, dynamic> json) {
    // Accept the old key while sessions created by this version only emit
    // entryId. A setlist entry is stable across devices; Song.id is not.
    final entryId = json['entryId'] ?? json['songId'];
    final title = json['title'];
    if (entryId is! String || title is! String) {
      throw const FormatException('곡');
    }
    final artist = json['artist'];
    final bpm = json['bpm'];
    final rawMusic = musicStateFromMessage(json['music']);
    final music = rawMusic == null ? null : jamMusicProfile(rawMusic);
    return JamSharedSong(
      entryId: entryId,
      title: title,
      artist: artist is String ? artist : null,
      bpm: bpm is int ? bpm : null,
      music: music == null || music.isEmpty ? null : music,
    );
  }

  final String entryId;
  final String title;
  final String? artist;
  final int? bpm;
  final JamMusicState? music;

  JamSharedSong copyWith({JamMusicState? music, bool clearMusic = false}) {
    return JamSharedSong(
      entryId: entryId,
      title: title,
      artist: artist,
      bpm: music?.bpm ?? bpm,
      music: clearMusic ? null : (music ?? this.music),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'entryId': entryId,
      'title': title,
      'artist': artist,
      // Keep BPM in the legacy field so older clients can still follow the
      // song even though they ignore the newer profile object.
      'bpm': bpm ?? music?.bpm,
      if (music != null) 'music': music!.toJson(),
    };
  }
}

class JamSharedSetlist {
  const JamSharedSetlist({
    required this.id,
    required this.title,
    required this.songs,
  });

  factory JamSharedSetlist.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final songs = json['songs'];
    if (id is! String || title is! String || songs is! List) {
      throw const FormatException('세트리스트');
    }
    return JamSharedSetlist(
      id: id,
      title: title,
      songs: [
        for (final item in List<Object?>.from(songs))
          if (item is Map)
            JamSharedSong.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }

  final String id;
  final String title;
  final List<JamSharedSong> songs;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'songs': [for (final song in songs) song.toJson()],
    };
  }

  JamSharedSetlist withSongMusic(String entryId, JamMusicState music) {
    final profile = jamMusicProfile(music);
    return JamSharedSetlist(
      id: id,
      title: title,
      songs: [
        for (final song in songs)
          song.entryId == entryId ? song.copyWith(music: profile) : song,
      ],
    );
  }

  JamSharedSong? songByEntryId(String entryId) {
    return songs.where((item) => item.entryId == entryId).firstOrNull;
  }
}

JamSharedSetlist? sharedSetlistFromMessage(Object? value) {
  if (value is! Map) {
    return null;
  }
  try {
    return JamSharedSetlist.fromJson(Map<String, dynamic>.from(value));
  } on Object {
    return null;
  }
}

class JamScorePosition {
  const JamScorePosition({this.page, this.measure});

  factory JamScorePosition.fromJson(Map<String, dynamic> json) {
    final page = json['page'];
    final measure = json['measure'];
    return JamScorePosition(
      page: page is int ? page : null,
      measure: measure is int ? measure : null,
    );
  }

  final int? page;
  final int? measure;

  bool get isEmpty => page == null && measure == null;

  Map<String, Object?> toJson() {
    return {'page': page, 'measure': measure};
  }

  @override
  bool operator ==(Object other) {
    return other is JamScorePosition &&
        other.page == page &&
        other.measure == measure;
  }

  @override
  int get hashCode => Object.hash(page, measure);
}

JamScorePosition? scorePositionFromMessage(Object? value) {
  if (value is! Map) {
    return null;
  }
  try {
    final position = JamScorePosition.fromJson(
      Map<String, dynamic>.from(value),
    );
    return position.isEmpty ? null : position;
  } on Object {
    return null;
  }
}

String? jamPositionLabel(JamScorePosition? position) {
  if (position == null) {
    return null;
  }
  if (position.measure != null) {
    return '${position.measure}마디';
  }
  if (position.page != null) {
    return '${position.page}페이지';
  }
  return null;
}

class JamMusicState {
  const JamMusicState({
    this.bpm,
    this.section,
    this.meterNumerator,
    this.meterDenominator,
    this.subdivision,
    this.accents,
  });

  factory JamMusicState.fromJson(Map<String, dynamic> json) {
    final bpm = json['bpm'];
    final section = json['section'];
    final meterNumerator = json['meterNumerator'];
    final meterDenominator = json['meterDenominator'];
    final subdivision = json['subdivision'];
    final accents = json['accents'];
    return normalizeJamMusic(
      JamMusicState(
        bpm: bpm is int ? bpm : null,
        section: section is String ? normalizeJamSection(section) : null,
        meterNumerator: meterNumerator is int ? meterNumerator : null,
        meterDenominator: meterDenominator is int ? meterDenominator : null,
        subdivision: subdivision is String
            ? normalizeJamSubdivision(subdivision)
            : null,
        accents: accents is List ? normalizeJamAccents(accents) : null,
      ),
    );
  }

  final int? bpm;
  final String? section;
  final int? meterNumerator;
  final int? meterDenominator;
  final String? subdivision;
  final List<int>? accents;

  bool get isEmpty =>
      bpm == null &&
      section == null &&
      meterNumerator == null &&
      meterDenominator == null &&
      subdivision == null &&
      accents == null;

  Map<String, Object?> toJson() {
    return {
      'bpm': bpm,
      'section': section,
      'meterNumerator': meterNumerator,
      'meterDenominator': meterDenominator,
      'subdivision': subdivision,
      'accents': accents,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is JamMusicState &&
        other.bpm == bpm &&
        other.section == section &&
        other.meterNumerator == meterNumerator &&
        other.meterDenominator == meterDenominator &&
        other.subdivision == subdivision &&
        _sameIntList(other.accents, accents);
  }

  @override
  int get hashCode => Object.hash(
    bpm,
    section,
    meterNumerator,
    meterDenominator,
    subdivision,
    accents == null ? null : Object.hashAll(accents!),
  );
}

JamMusicState? musicStateFromMessage(Object? value) {
  if (value is! Map) {
    return null;
  }
  try {
    final music = JamMusicState.fromJson(Map<String, dynamic>.from(value));
    return music.isEmpty ? null : music;
  } on Object {
    return null;
  }
}

String? normalizeJamSection(String? raw) {
  final value = raw?.trim().toUpperCase();
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

int? normalizeJamBpm(int? bpm) {
  if (bpm == null) {
    return null;
  }
  if (bpm < 40 || bpm > 240) {
    return null;
  }
  return bpm;
}

int? normalizeJamMeterValue(int? value, {required int max}) {
  if (value == null || value < 1 || value > max) {
    return null;
  }
  return value;
}

String? normalizeJamSubdivision(String? raw) {
  return switch (raw?.trim().toLowerCase()) {
    'quarter' => 'quarter',
    'eighth' => 'eighth',
    'sixteenth' => 'sixteenth',
    'triplet' => 'triplet',
    'sextuplet' => 'sextuplet',
    _ => null,
  };
}

List<int>? normalizeJamAccents(Iterable<Object?> raw) {
  final values = [
    for (final value in raw)
      if (value is num) value.toInt().clamp(0, 2).toInt(),
  ];
  return values.isEmpty ? null : List.unmodifiable(values);
}

JamMusicState normalizeJamMusic(JamMusicState music) {
  final numerator = normalizeJamMeterValue(music.meterNumerator, max: 12);
  final denominator = normalizeJamMeterValue(music.meterDenominator, max: 16);
  return JamMusicState(
    bpm: normalizeJamBpm(music.bpm),
    section: normalizeJamSection(music.section),
    meterNumerator: numerator == null || denominator == null ? null : numerator,
    meterDenominator: numerator == null || denominator == null
        ? null
        : denominator,
    subdivision: normalizeJamSubdivision(music.subdivision),
    accents: music.accents == null ? null : normalizeJamAccents(music.accents!),
  );
}

/// Persistent setlist profile: rhythmic settings are per song, while the
/// active section remains a live Jam/session value.
JamMusicState jamMusicProfile(JamMusicState music) {
  return normalizeJamMusic(
    JamMusicState(
      bpm: music.bpm,
      meterNumerator: music.meterNumerator,
      meterDenominator: music.meterDenominator,
      subdivision: music.subdivision,
      accents: music.accents,
    ),
  );
}

bool _sameIntList(List<int>? first, List<int>? second) {
  if (identical(first, second)) {
    return true;
  }
  if (first == null || second == null || first.length != second.length) {
    return false;
  }
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) {
      return false;
    }
  }
  return true;
}

JamMusicState? jamMusicForSong(JamSharedSong? song) {
  final configured = song?.music;
  final bpm = normalizeJamBpm(configured?.bpm ?? song?.bpm);
  if (configured == null && bpm == null) {
    return null;
  }
  final music = normalizeJamMusic(
    JamMusicState(
      bpm: bpm,
      section: configured?.section,
      meterNumerator: configured?.meterNumerator,
      meterDenominator: configured?.meterDenominator,
      subdivision: configured?.subdivision,
      accents: configured?.accents,
    ),
  );
  return music.isEmpty ? null : music;
}

String? jamMusicLabel(JamMusicState? music) {
  if (music == null) {
    return null;
  }
  final parts = <String>[
    if (music.bpm != null) '${music.bpm} BPM',
    if (music.meterNumerator != null && music.meterDenominator != null)
      '${music.meterNumerator}/${music.meterDenominator}',
    if (music.subdivision != null) _jamSubdivisionLabel(music.subdivision!),
    if (music.section != null) music.section!,
  ];
  if (parts.isEmpty) {
    return null;
  }
  return parts.join(' · ');
}

String _jamSubdivisionLabel(String value) => switch (value) {
  'quarter' => '♩',
  'eighth' => '♪',
  'sixteenth' => '♬',
  'triplet' => '♪♪♪',
  'sextuplet' => '♪♪♪♪♪♪',
  _ => value,
};

class JamLoopState {
  const JamLoopState({
    required this.enabled,
    this.startMeasure,
    this.endMeasure,
    this.section,
  });

  factory JamLoopState.fromJson(Map<String, dynamic> json) {
    final enabled = json['enabled'];
    final startMeasure = json['startMeasure'];
    final endMeasure = json['endMeasure'];
    final section = json['section'];
    return JamLoopState(
      enabled: enabled is bool ? enabled : false,
      startMeasure: startMeasure is int ? startMeasure : null,
      endMeasure: endMeasure is int ? endMeasure : null,
      section: section is String ? normalizeJamSection(section) : null,
    );
  }

  final bool enabled;
  final int? startMeasure;
  final int? endMeasure;
  final String? section;

  bool get isActive =>
      enabled &&
      startMeasure != null &&
      endMeasure != null &&
      startMeasure! < endMeasure!;

  Map<String, Object?> toJson() {
    return {
      'enabled': enabled,
      'startMeasure': startMeasure,
      'endMeasure': endMeasure,
      'section': section,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is JamLoopState &&
        other.enabled == enabled &&
        other.startMeasure == startMeasure &&
        other.endMeasure == endMeasure &&
        other.section == section;
  }

  @override
  int get hashCode => Object.hash(enabled, startMeasure, endMeasure, section);
}

JamLoopState? loopStateFromMessage(Object? value) {
  if (value is! Map) {
    return null;
  }
  try {
    return JamLoopState.fromJson(Map<String, dynamic>.from(value));
  } on Object {
    return null;
  }
}

JamLoopState? normalizeJamLoop({
  required bool enabled,
  int? startMeasure,
  int? endMeasure,
  String? section,
}) {
  if (!enabled) {
    return const JamLoopState(enabled: false);
  }
  if (startMeasure == null ||
      endMeasure == null ||
      startMeasure < 1 ||
      endMeasure < 1 ||
      startMeasure >= endMeasure) {
    return null;
  }
  return JamLoopState(
    enabled: true,
    startMeasure: startMeasure,
    endMeasure: endMeasure,
    section: normalizeJamSection(section),
  );
}

String? jamLoopLabel(JamLoopState? loop) {
  if (loop == null || !loop.isActive) {
    return null;
  }
  final range = '${loop.startMeasure}–${loop.endMeasure}마디';
  if (loop.section case final section?) {
    return 'Loop $section · $range';
  }
  return 'Loop $range';
}

/// Count-In 마디. 0·1·2·4만 허용. 기본 1마디.
int normalizeJamCountInBars(int? bars) {
  if (bars == null) {
    return 1;
  }
  if (bars <= 0) {
    return 0;
  }
  if (bars >= 4) {
    return 4;
  }
  if (bars >= 2) {
    return 2;
  }
  return 1;
}

String jamCountInLabel(int bars) {
  final normalized = normalizeJamCountInBars(bars);
  if (normalized == 0) {
    return 'Count-In 없음';
  }
  return 'Count-In $normalized마디';
}

/// Start 직후 멤버가 상태를 받을 여유. 클릭 예약은 이 시각 기준.
const jamStartLead = Duration(milliseconds: 750);

DateTime jamScheduleStartAt(DateTime now, {Duration lead = jamStartLead}) {
  return now.toUtc().add(lead);
}

Duration jamWaitUntilStart(DateTime startAt, DateTime now) {
  final delay = startAt.toUtc().difference(now.toUtc());
  return delay.isNegative ? Duration.zero : delay;
}

/// Legacy wire flag retained for older sessions.
///
/// Jam now always renders the shared metronome locally on every device. The
/// value is kept only so sessions created by older builds remain decodable.
enum JamClickMode { host, individual }

JamClickMode jamClickModeFromName(String? raw) {
  return JamClickMode.values.asNameMap()[raw] ?? JamClickMode.individual;
}

String jamClickModeLabel(JamClickMode mode) => '공통 메트로놈';

bool jamShouldPlayClick({
  required bool isConductor,
  JamClickMode mode = JamClickMode.individual,
}) {
  // The conductor distributes the clock/settings; each device plays its own
  // local click so everyone can use headphones without sending audio over LAN.
  return true;
}

String? jamEntryIdForSharedSetlist(
  JamSharedSetlist setlist, {
  String? previousEntryId,
}) {
  if (setlist.songs.isEmpty) {
    return null;
  }
  if (previousEntryId != null &&
      setlist.songByEntryId(previousEntryId) != null) {
    return previousEntryId;
  }
  return setlist.songs.first.entryId;
}

String? jamAdjacentEntryId(
  JamSharedSetlist setlist, {
  required String? currentEntryId,
  required int delta,
}) {
  if (setlist.songs.isEmpty) {
    return null;
  }
  final index = currentEntryId == null
      ? -1
      : setlist.songs.indexWhere((item) => item.entryId == currentEntryId);
  final next = index + delta;
  if (next < 0 || next >= setlist.songs.length) {
    return null;
  }
  return setlist.songs[next].entryId;
}

class JamSession {
  const JamSession({
    required this.id,
    required this.code,
    required this.title,
    required this.participants,
    required this.createdAt,
    this.setlistId,
    this.sharedSetlist,
    this.currentEntryId,
    this.position,
    this.music,
    this.playing = false,
    this.countInBars = 1,
    this.startAt,
    this.clickMode = JamClickMode.individual,
    this.loop,
  });

  factory JamSession.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final code = json['code'];
    final title = json['title'];
    final createdAt = json['createdAt'];
    final participants = json['participants'];
    if (id is! String ||
        code is! String ||
        title is! String ||
        createdAt is! String ||
        participants is! List) {
      throw const FormatException('세션');
    }
    final setlistId = json['setlistId'];
    final currentEntryId = json['currentEntryId'] ?? json['currentSongId'];
    final playing = json['playing'];
    final countInBars = json['countInBars'];
    final startAt = json['startAt'];
    final clickMode = json['clickMode'];
    return JamSession(
      id: id,
      code: code,
      title: title,
      setlistId: setlistId is String ? setlistId : null,
      sharedSetlist: sharedSetlistFromMessage(json['sharedSetlist']),
      currentEntryId: currentEntryId is String ? currentEntryId : null,
      position: scorePositionFromMessage(json['position']),
      music: musicStateFromMessage(json['music']),
      playing: playing is bool ? playing : false,
      countInBars: normalizeJamCountInBars(
        countInBars is int ? countInBars : null,
      ),
      startAt: startAt is String ? DateTime.tryParse(startAt)?.toUtc() : null,
      clickMode: jamClickModeFromName(clickMode is String ? clickMode : null),
      loop: loopStateFromMessage(json['loop']),
      createdAt: DateTime.parse(createdAt),
      participants: [
        for (final item in List<Object?>.from(participants))
          if (item is Map)
            JamParticipant.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }

  final String id;
  final String code;
  final String title;
  final String? setlistId;
  final JamSharedSetlist? sharedSetlist;
  final String? currentEntryId;
  final JamScorePosition? position;
  final JamMusicState? music;
  final bool playing;
  final int countInBars;
  final DateTime? startAt;
  final JamClickMode clickMode;
  final JamLoopState? loop;
  final List<JamParticipant> participants;
  final DateTime createdAt;

  JamParticipant get conductor =>
      participants.firstWhere((item) => item.role == JamRole.conductor);

  List<JamParticipant> get members => participants
      .where((item) => item.role == JamRole.member)
      .toList(growable: false);

  List<JamParticipant> get connectedMembers =>
      members.where((item) => item.connected).toList(growable: false);

  int get readyMemberCount =>
      connectedMembers.where((item) => item.ready).length;

  bool get allMembersReady => connectedMembers.every((item) => item.ready);

  JamSharedSong? get currentSong {
    final entryId = currentEntryId;
    final setlist = sharedSetlist;
    if (entryId == null || setlist == null) {
      return null;
    }
    return setlist.songByEntryId(entryId);
  }

  JamParticipant? participantById(String participantId) {
    return participants.where((item) => item.id == participantId).firstOrNull;
  }

  JamPermissions? permissionsFor(String participantId) {
    final participant = participantById(participantId);
    if (participant == null) {
      return null;
    }
    return JamPermissions(participant.role);
  }

  JamSession copyWith({
    List<JamParticipant>? participants,
    String? setlistId,
    JamSharedSetlist? sharedSetlist,
    bool clearSharedSetlist = false,
    String? currentEntryId,
    bool clearCurrentEntryId = false,
    JamScorePosition? position,
    bool clearPosition = false,
    JamMusicState? music,
    bool clearMusic = false,
    bool? playing,
    int? countInBars,
    DateTime? startAt,
    bool clearStartAt = false,
    JamClickMode? clickMode,
    JamLoopState? loop,
    bool clearLoop = false,
  }) {
    return JamSession(
      id: id,
      code: code,
      title: title,
      setlistId: setlistId ?? this.setlistId,
      sharedSetlist: clearSharedSetlist
          ? null
          : (sharedSetlist ?? this.sharedSetlist),
      currentEntryId: clearCurrentEntryId
          ? null
          : (currentEntryId ?? this.currentEntryId),
      position: clearPosition ? null : (position ?? this.position),
      music: clearMusic ? null : (music ?? this.music),
      playing: playing ?? this.playing,
      countInBars: countInBars == null
          ? this.countInBars
          : normalizeJamCountInBars(countInBars),
      startAt: clearStartAt ? null : (startAt ?? this.startAt),
      clickMode: clickMode ?? this.clickMode,
      loop: clearLoop ? null : (loop ?? this.loop),
      participants: participants ?? this.participants,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'code': code,
      'title': title,
      'setlistId': setlistId,
      'sharedSetlist': sharedSetlist?.toJson(),
      'currentEntryId': currentEntryId,
      'position': position?.toJson(),
      'music': music?.toJson(),
      'playing': playing,
      'countInBars': countInBars,
      'startAt': startAt?.toUtc().toIso8601String(),
      'clickMode': clickMode.name,
      'loop': loop?.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'participants': [for (final item in participants) item.toJson()],
    };
  }
}

class JamSessionException implements Exception {
  const JamSessionException(this.message);

  static const notReady = 'jamNotReady';
  static const networkUnavailable = 'jamNetworkUnavailable';
  static const joinTimedOut = 'jamJoinTimedOut';
  static const hostUnavailable = 'jamHostUnavailable';

  final String message;

  @override
  String toString() => message;
}

String defaultJamTitle(DateTime now) => '${now.month}월 ${now.day}일 합주';

String? parseJoinCode(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 4) {
    return null;
  }
  return digits;
}

const jamInvitePrefix = 'pageadiddle:jam:';

String jamInvitePayload(String code) => '$jamInvitePrefix$code';

String? parseJamInvite(String raw) {
  final trimmed = raw.trim();
  if (trimmed.startsWith(jamInvitePrefix)) {
    return parseJoinCode(trimmed.substring(jamInvitePrefix.length));
  }
  return parseJoinCode(trimmed);
}

String normalizeDisplayName(String raw) {
  final name = raw.trim();
  if (name.isEmpty) {
    throw const JamSessionException('이름 필요');
  }
  return name;
}

enum JamPresenceTick { stay, away, drop }

JamPresenceTick jamPresenceTick({
  required bool connected,
  required DateTime now,
  required DateTime? lastSeen,
  required Duration staleAfter,
}) {
  final stale = lastSeen == null || now.difference(lastSeen) >= staleAfter;
  if (!stale) {
    return JamPresenceTick.stay;
  }
  return connected ? JamPresenceTick.away : JamPresenceTick.drop;
}
