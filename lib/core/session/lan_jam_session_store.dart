import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:page_a_diddle/core/session/jam_clock_sync.dart';
import 'package:page_a_diddle/core/session/jam_lan_codec.dart';
import 'package:page_a_diddle/core/session/jam_session.dart';
import 'package:page_a_diddle/core/session/jam_session_store.dart';

class LanJamSessionStore implements JamSessionStore {
  LanJamSessionStore({
    this.tcpPort = 47828,
    this.udpPort = 47829,
    this.joinTimeout = const Duration(seconds: 4),
    this.heartbeat = const Duration(seconds: 2),
    this.staleAfter = const Duration(seconds: 6),
    String Function()? idGenerator,
    String Function()? codeGenerator,
    DateTime Function()? clock,
  }) : _idGenerator = idGenerator ?? _defaultId,
       _codeGenerator = codeGenerator ?? _defaultCode,
       _clock = clock ?? DateTime.now;

  final int tcpPort;
  final int udpPort;
  final Duration joinTimeout;
  final Duration heartbeat;
  final Duration staleAfter;
  final String Function() _idGenerator;
  final String Function() _codeGenerator;
  final DateTime Function() _clock;

  ServerSocket? _server;
  RawDatagramSocket? _udp;
  StreamSubscription<RawSocketEvent>? _udpSubscription;
  Timer? _heartbeatTimer;
  Socket? _client;
  JamSession? _session;
  final Map<Socket, String> _clientIds = {};
  final Map<String, DateTime> _lastSeen = {};
  final Map<String, Set<StreamController<JamSession?>>> _listeners = {};
  final StreamController<Duration> _clockOffsetController =
      StreamController<Duration>.broadcast();
  final List<Duration> _clockSamples = [];
  Duration _clockOffset = Duration.zero;
  final Map<String, DateTime> _clockPingSent = {};
  final Map<String, Completer<JamHostScore?>> _hostScoreRequests = {};
  JamHostScoreProvider? _hostScoreProvider;
  List<InternetAddress> _broadcastTargets = [
    InternetAddress('255.255.255.255'),
    InternetAddress.loopbackIPv4,
  ];
  bool _hasUsableNetwork = false;

  @override
  Duration get clockOffset => _clockOffset;

  @override
  Stream<Duration> get clockOffsetStream => _clockOffsetController.stream;

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
    final session = _session;
    if (session == null || session.id != sessionId) {
      throw const JamSessionException('세션 없음');
    }
    if (session.permissionsFor(participantId) == null) {
      throw const JamSessionException('권한 없음');
    }
    if (_server != null) {
      return _hostScoreProvider?.call(entryId);
    }
    final client = _client;
    if (client == null) {
      throw const JamSessionException(JamSessionException.hostUnavailable);
    }
    final requestId = 'score-${_idGenerator()}';
    final completer = Completer<JamHostScore?>();
    _hostScoreRequests[requestId] = completer;
    _write(client, {
      'type': 'score-request',
      'requestId': requestId,
      'entryId': entryId,
    });
    try {
      return await completer.future.timeout(joinTimeout);
    } on TimeoutException {
      return null;
    } finally {
      _hostScoreRequests.remove(requestId);
    }
  }

  Future<void> dispose() async {
    await _resetSession();
    if (!_clockOffsetController.isClosed) {
      await _clockOffsetController.close();
    }
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
    await _resetSession();
    await _refreshBroadcastTargets();
    _ensureNetworkAvailable();
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
    try {
      try {
        _server = await ServerSocket.bind(InternetAddress.anyIPv4, tcpPort);
      } on SocketException {
        _server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      }
      _udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, udpPort);
      _udp!.broadcastEnabled = true;
    } on Object {
      await _stopHost();
      throw const JamSessionException('연결 실패');
    }
    final currentEntryId = sharedSetlist == null
        ? null
        : jamEntryIdForSharedSetlist(sharedSetlist);
    _session = JamSession(
      id: _idGenerator(),
      code: _codeGenerator(),
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
    _server!.listen(_onHostClient);
    _udpSubscription = _udp!.listen((event) {
      if (event != RawSocketEvent.read) {
        return;
      }
      Datagram? packet;
      while ((packet = _udp!.receive()) != null) {
        _onDiscovery(packet!);
      }
    }, onError: (_, _) {});
    // Let the datagram listener finish registration before a peer can query.
    await Future<void>.delayed(const Duration(milliseconds: 40));
    _startHostPrune();
    _emit(_session);
    return (session: _session!, participantId: conductor.id);
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
    final name = normalizeDisplayName(displayName);
    await _resetSession();
    await _refreshBroadcastTargets();
    _ensureNetworkAvailable();
    final endpoint = await _discover(parsed);
    late final Socket socket;
    try {
      socket = await Socket.connect(
        endpoint.address,
        endpoint.port,
        timeout: joinTimeout,
      );
    } on Object {
      throw const JamSessionException(JamSessionException.hostUnavailable);
    }
    final completer = Completer<({JamSession session, String participantId})>();
    _client = socket;
    _listenLines(socket, (message) {
      if (completer.isCompleted) {
        if (message['type'] == 'clock-pong') {
          _handleClockPong(message);
          return;
        }
        if (message['type'] == 'score-response') {
          _handleHostScoreResponse(message);
          return;
        }
        final session = sessionFromMessage(message['session']);
        if (session != null) {
          _session = session;
          _emit(session);
        }
        if (message['type'] == 'closed') {
          unawaited(_handleRemoteClosed());
        }
        return;
      }
      if (message['type'] != 'welcome') {
        return;
      }
      final participantId = message['participantId'];
      final session = sessionFromMessage(message['session']);
      if (participantId is! String || session == null) {
        if (!completer.isCompleted) {
          completer.completeError(
            const JamSessionException(JamSessionException.hostUnavailable),
          );
        }
        return;
      }
      _session = session;
      _emit(session);
      _startClientHeartbeat();
      completer.complete((session: session, participantId: participantId));
    }, onDone: () => unawaited(_handleRemoteClosed()));
    _write(socket, {
      'type': 'join',
      'name': name,
      'instrument': instrument.name,
      'customInstrument': normalizeJamCustomInstrument(customInstrument),
    });
    try {
      return await completer.future.timeout(joinTimeout);
    } on JamSessionException {
      await _disconnectClient();
      rethrow;
    } on Object {
      await _disconnectClient();
      throw const JamSessionException(JamSessionException.hostUnavailable);
    }
  }

  @override
  Stream<JamSession?> watch(String sessionId) {
    final controller = StreamController<JamSession?>();
    _listeners.putIfAbsent(sessionId, () => {}).add(controller);
    final current = _session;
    controller
      ..add(current?.id == sessionId ? current : null)
      ..onCancel = () {
        _listeners[sessionId]?.remove(controller);
      };
    return controller.stream;
  }

  @override
  Future<List<JamNearbyRoom>> discoverRooms({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    await _refreshBroadcastTargets();
    _ensureNetworkAvailable();
    late final RawDatagramSocket udp;
    try {
      udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    } on SocketException {
      throw const JamSessionException(JamSessionException.networkUnavailable);
    }
    udp.broadcastEnabled = true;
    final rooms = <String, JamNearbyRoom>{};
    final query = utf8.encode(jsonEncode(const JamLanQuery().toJson()));

    void sendQuery() {
      for (final target in _broadcastTargets) {
        try {
          udp.send(query, target, udpPort);
        } on SocketException {
          // One interface may be unavailable while another is usable.
        }
      }
    }

    late final StreamSubscription<RawSocketEvent> subscription;
    subscription = udp.listen((event) {
      if (event != RawSocketEvent.read) {
        return;
      }
      Datagram? packet;
      while ((packet = udp.receive()) != null) {
        final json = decodeJamLanMessage(
          utf8.decode(packet!.data, allowMalformed: true),
        );
        if (json == null) {
          continue;
        }
        final announce = announceFromMessage(json);
        if (announce == null) {
          continue;
        }
        rooms[announce.code] = JamNearbyRoom(
          code: announce.code,
          title: announce.title,
          participantCount: announce.participantCount,
        );
      }
    }, onError: (_, _) {});

    final scanFor = timeout < const Duration(milliseconds: 200)
        ? const Duration(milliseconds: 200)
        : timeout;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    sendQuery();
    final retryTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      sendQuery();
    });
    try {
      await Future<void>.delayed(scanFor);
      return rooms.values.toList(growable: false);
    } finally {
      retryTimer.cancel();
      await subscription.cancel();
      udp.close();
    }
  }

  @override
  Future<void> shareSetlist({
    required String sessionId,
    required String participantId,
    required JamSharedSetlist setlist,
  }) async {
    final session = _session;
    if (session == null || session.id != sessionId) {
      throw const JamSessionException('세션 없음');
    }
    final permissions = session.permissionsFor(participantId);
    if (permissions == null || !permissions.canLead || _server == null) {
      throw const JamSessionException('권한 없음');
    }
    final entryId = jamEntryIdForSharedSetlist(
      setlist,
      previousEntryId: session.currentEntryId,
    );
    final music = jamMusicForSong(
      entryId == null ? null : setlist.songByEntryId(entryId),
    );
    _session = session.copyWith(
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
    _emit(_session);
    _broadcastState();
  }

  @override
  Future<void> selectSong({
    required String sessionId,
    required String participantId,
    required String entryId,
  }) async {
    final session = _session;
    if (session == null || session.id != sessionId) {
      throw const JamSessionException('세션 없음');
    }
    final permissions = session.permissionsFor(participantId);
    if (permissions == null || !permissions.canLead || _server == null) {
      throw const JamSessionException('권한 없음');
    }
    final setlist = session.sharedSetlist;
    final song = setlist?.songByEntryId(entryId);
    if (setlist == null || song == null) {
      throw const JamSessionException('곡 없음');
    }
    final music = jamMusicForSong(song);
    _session = session.copyWith(
      currentEntryId: entryId,
      clearPosition: true,
      music: music,
      clearMusic: music == null,
      playing: false,
      clearStartAt: true,
      clearLoop: true,
    );
    _emit(_session);
    _broadcastState();
  }

  @override
  Future<void> updatePosition({
    required String sessionId,
    required String participantId,
    required JamScorePosition position,
  }) async {
    final session = _session;
    if (session == null || session.id != sessionId) {
      throw const JamSessionException('세션 없음');
    }
    final permissions = session.permissionsFor(participantId);
    if (permissions == null || !permissions.canLead || _server == null) {
      throw const JamSessionException('권한 없음');
    }
    if (position.isEmpty) {
      throw const JamSessionException('위치 없음');
    }
    if (session.position == position) {
      return;
    }
    _session = session.copyWith(position: position);
    _emit(_session);
    _broadcastState();
  }

  @override
  Future<void> updateMusic({
    required String sessionId,
    required String participantId,
    required JamMusicState music,
  }) async {
    final session = _session;
    if (session == null || session.id != sessionId) {
      throw const JamSessionException('세션 없음');
    }
    final permissions = session.permissionsFor(participantId);
    if (permissions == null || !permissions.canLead || _server == null) {
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
    _session = session.copyWith(music: normalized, sharedSetlist: nextSetlist);
    _emit(_session);
    _broadcastState();
  }

  @override
  Future<DateTime?> updatePlaying({
    required String sessionId,
    required String participantId,
    required bool playing,
  }) async {
    final session = _session;
    if (session == null || session.id != sessionId) {
      throw const JamSessionException('세션 없음');
    }
    final permissions = session.permissionsFor(participantId);
    if (permissions == null || !permissions.canLead || _server == null) {
      throw const JamSessionException('권한 없음');
    }
    if (playing && !session.allMembersReady) {
      throw const JamSessionException(JamSessionException.notReady);
    }
    if (session.playing == playing) {
      return session.startAt;
    }
    _session = playing
        ? session.copyWith(playing: true, startAt: jamScheduleStartAt(_clock()))
        : session.copyWith(playing: false, clearStartAt: true);
    _emit(_session);
    _broadcastState();
    return _session?.startAt;
  }

  @override
  Future<void> updateReady({
    required String sessionId,
    required String participantId,
    required bool ready,
  }) async {
    final session = _session;
    if (session == null || session.id != sessionId) {
      throw const JamSessionException('세션 없음');
    }
    final participant = session.participantById(participantId);
    if (participant == null || participant.role != JamRole.member) {
      throw const JamSessionException('권한 없음');
    }
    if (participant.ready == ready) {
      return;
    }
    if (_server != null) {
      _setReady(participantId, ready);
      return;
    }
    final client = _client;
    if (client == null) {
      throw const JamSessionException(JamSessionException.hostUnavailable);
    }
    _write(client, {
      'type': 'ready',
      'participantId': participantId,
      'ready': ready,
    });
  }

  @override
  Future<void> updateCountInBars({
    required String sessionId,
    required String participantId,
    required int countInBars,
  }) async {
    final session = _session;
    if (session == null || session.id != sessionId) {
      throw const JamSessionException('세션 없음');
    }
    final permissions = session.permissionsFor(participantId);
    if (permissions == null || !permissions.canLead || _server == null) {
      throw const JamSessionException('권한 없음');
    }
    final bars = normalizeJamCountInBars(countInBars);
    if (session.countInBars == bars) {
      return;
    }
    _session = session.copyWith(countInBars: bars);
    _emit(_session);
    _broadcastState();
  }

  @override
  Future<void> updateClickMode({
    required String sessionId,
    required String participantId,
    required JamClickMode clickMode,
  }) async {
    final session = _session;
    if (session == null || session.id != sessionId) {
      throw const JamSessionException('세션 없음');
    }
    final permissions = session.permissionsFor(participantId);
    if (permissions == null || !permissions.canLead || _server == null) {
      throw const JamSessionException('권한 없음');
    }
    if (session.clickMode == clickMode) {
      return;
    }
    _session = session.copyWith(clickMode: clickMode);
    _emit(_session);
    _broadcastState();
  }

  @override
  Future<void> updateLoop({
    required String sessionId,
    required String participantId,
    required JamLoopState loop,
  }) async {
    final session = _session;
    if (session == null || session.id != sessionId) {
      throw const JamSessionException('세션 없음');
    }
    final permissions = session.permissionsFor(participantId);
    if (permissions == null || !permissions.canLead || _server == null) {
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
    _session = session.copyWith(loop: normalized);
    _emit(_session);
    _broadcastState();
  }

  @override
  Future<void> leave({
    required String sessionId,
    required String participantId,
  }) async {
    final session = _session;
    if (session == null || session.id != sessionId) {
      return;
    }
    final leaving = session.participants
        .where((item) => item.id == participantId)
        .firstOrNull;
    if (leaving == null) {
      return;
    }
    if (leaving.role == JamRole.conductor) {
      await _stopHost(notifyClients: true);
      return;
    }
    if (_server != null) {
      _removeMember(participantId);
      return;
    }
    final client = _client;
    if (client != null) {
      _write(client, {'type': 'leave', 'participantId': participantId});
    }
    await _disconnectClient();
  }

  void _onHostClient(Socket socket) {
    _listenLines(
      socket,
      (message) {
        final type = message['type'];
        if (type == 'join') {
          final name = message['name'];
          if (name is! String || _session == null) {
            return;
          }
          try {
            final instrument = message['instrument'];
            final member = JamParticipant(
              id: _idGenerator(),
              displayName: normalizeDisplayName(name),
              role: JamRole.member,
              instrument: jamInstrumentFromName(
                instrument is String ? instrument : null,
              ),
              customInstrument: normalizeJamCustomInstrument(
                message['customInstrument'] is String
                    ? message['customInstrument'] as String
                    : null,
              ),
              ready: false,
            );
            _clientIds[socket] = member.id;
            _lastSeen[member.id] = _clock();
            _session = _session!.copyWith(
              participants: [..._session!.participants, member],
            );
            _write(socket, {
              'type': 'welcome',
              'participantId': member.id,
              'session': _session!.toJson(),
            });
            _emit(_session);
            _broadcastState();
          } on JamSessionException {
            socket.destroy();
          }
          return;
        }
        if (type == 'ping') {
          final id = _clientIds[socket];
          if (id != null) {
            _lastSeen[id] = _clock();
            final member = _session?.participants
                .where((item) => item.id == id)
                .firstOrNull;
            if (member != null && !member.connected) {
              _setConnected(id, true);
            }
          }
          return;
        }
        if (type == 'ready') {
          final id = _clientIds[socket];
          final participantId = message['participantId'];
          final ready = message['ready'];
          if (id != null && participantId == id && ready is bool) {
            _setReady(id, ready);
          }
          return;
        }
        if (type == 'clock-ping') {
          _write(socket, {
            'type': 'clock-pong',
            'conductorT': _clock().toUtc().toIso8601String(),
          });
          return;
        }
        if (type == 'score-request') {
          final requestId = message['requestId'];
          final entryId = message['entryId'];
          if (requestId is String &&
              requestId.length <= 128 &&
              entryId is String &&
              entryId.length <= 256 &&
              _clientIds[socket] != null) {
            unawaited(_handleHostScoreRequest(socket, requestId, entryId));
          }
          return;
        }
        if (type == 'leave') {
          final participantId = message['participantId'];
          if (participantId is String) {
            _removeMember(participantId);
          }
        }
      },
      onDone: () {
        final id = _clientIds.remove(socket);
        socket.destroy();
        if (id != null) {
          _removeMember(id);
        }
      },
    );
  }

  void _removeMember(String participantId) {
    final session = _session;
    if (session == null) {
      return;
    }
    _lastSeen.remove(participantId);
    _session = session.copyWith(
      participants: session.participants
          .where((item) => item.id != participantId)
          .toList(),
    );
    _emit(_session);
    _broadcastState();
  }

  void _setConnected(String participantId, bool connected) {
    final session = _session;
    if (session == null) {
      return;
    }
    final current = session.participants
        .where((item) => item.id == participantId)
        .firstOrNull;
    if (current == null || current.connected == connected) {
      return;
    }
    _session = session.copyWith(
      participants: [
        for (final item in session.participants)
          if (item.id == participantId)
            item.copyWith(connected: connected)
          else
            item,
      ],
    );
    _emit(_session);
    _broadcastState();
  }

  void _setReady(String participantId, bool ready) {
    final session = _session;
    if (session == null) {
      return;
    }
    final current = session.participantById(participantId);
    if (current == null || current.ready == ready) {
      return;
    }
    _session = session.copyWith(
      participants: [
        for (final item in session.participants)
          if (item.id == participantId) item.copyWith(ready: ready) else item,
      ],
    );
    _emit(_session);
    _broadcastState();
  }

  void _startHostPrune() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeat, (_) => _pruneStale());
  }

  Future<void> _handleHostScoreRequest(
    Socket socket,
    String requestId,
    String entryId,
  ) async {
    JamHostScore? score;
    try {
      score = await _hostScoreProvider?.call(entryId);
      if (score != null && score.bytes.length > JamHostScore.maxBytes) {
        score = null;
      }
    } on Object {
      score = null;
    }
    if (_clientIds[socket] == null) return;
    _write(socket, {
      'type': 'score-response',
      'requestId': requestId,
      'score': score?.toJson(),
    });
  }

  void _handleHostScoreResponse(Map<String, dynamic> message) {
    final requestId = message['requestId'];
    if (requestId is! String) return;
    final completer = _hostScoreRequests[requestId];
    if (completer == null || completer.isCompleted) return;
    completer.complete(JamHostScore.fromJson(message['score']));
  }

  void _startClientHeartbeat() {
    _heartbeatTimer?.cancel();
    var tickCount = 0;
    void ping() {
      final client = _client;
      if (client == null) {
        return;
      }
      _write(client, const {'type': 'ping'});
      tickCount++;
      if (tickCount % 3 == 1) {
        final id = _clock().toUtc().toIso8601String();
        _clockPingSent[id] = _clock();
        _write(client, {'type': 'clock-ping', 't': id});
      }
    }

    ping();
    _heartbeatTimer = Timer.periodic(heartbeat, (_) => ping());
  }

  void _pruneStale() {
    final session = _session;
    if (session == null || _server == null) {
      return;
    }
    final now = _clock();
    for (final member in session.members) {
      switch (jamPresenceTick(
        connected: member.connected,
        now: now,
        lastSeen: _lastSeen[member.id],
        staleAfter: staleAfter,
      )) {
        case JamPresenceTick.stay:
          break;
        case JamPresenceTick.away:
          _setConnected(member.id, false);
        case JamPresenceTick.drop:
          _removeMember(member.id);
      }
    }
  }

  void _onDiscovery(Datagram packet) {
    final session = _session;
    if (session == null) {
      return;
    }
    final json = decodeJamLanMessage(
      utf8.decode(packet.data, allowMalformed: true),
    );
    final queryCode = json?['code'];
    if (json == null ||
        json['type'] != 'query' ||
        (queryCode != null && queryCode != '*' && queryCode != session.code)) {
      return;
    }
    _sendAnnounce(packet.address, packet.port);
  }

  void _sendAnnounce(InternetAddress address, int port) {
    final udp = _udp;
    final session = _session;
    final server = _server;
    if (udp == null || session == null || server == null) {
      return;
    }
    try {
      udp.send(
        utf8.encode(
          jsonEncode(
            JamLanAnnounce(
              code: session.code,
              port: server.port,
              title: session.title,
              participantCount: session.participants.length,
            ).toJson(),
          ),
        ),
        address,
        port,
      );
    } on SocketException {
      // The query source can disappear while discovery is in flight.
    }
  }

  Future<({InternetAddress address, int port})> _discover(String code) async {
    late final RawDatagramSocket udp;
    try {
      udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    } on SocketException {
      throw const JamSessionException(JamSessionException.networkUnavailable);
    }
    udp.broadcastEnabled = true;
    final completer = Completer<({InternetAddress address, int port})>();
    final query = utf8.encode(jsonEncode(JamLanQuery(code: code).toJson()));

    void sendQuery() {
      for (final target in _broadcastTargets) {
        try {
          udp.send(query, target, udpPort);
        } on SocketException {
          // Keep trying the remaining interfaces when one route is unavailable.
        }
      }
    }

    late final StreamSubscription<RawSocketEvent> subscription;
    subscription = udp.listen((event) {
      if (event != RawSocketEvent.read) {
        return;
      }
      Datagram? packet;
      while ((packet = udp.receive()) != null) {
        final json = decodeJamLanMessage(
          utf8.decode(packet!.data, allowMalformed: true),
        );
        if (json == null) {
          continue;
        }
        final announce = announceFromMessage(json);
        if (announce == null ||
            announce.code != code ||
            completer.isCompleted) {
          continue;
        }
        completer.complete((address: packet.address, port: announce.port));
      }
    }, onError: (_, _) {});

    await Future<void>.delayed(const Duration(milliseconds: 10));
    sendQuery();
    final retryTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!completer.isCompleted) {
        sendQuery();
      }
    });
    try {
      return await completer.future.timeout(joinTimeout);
    } on TimeoutException {
      throw const JamSessionException(JamSessionException.joinTimedOut);
    } finally {
      retryTimer.cancel();
      await subscription.cancel();
      udp.close();
    }
  }

  Future<void> _refreshBroadcastTargets() async {
    // Loopback first keeps same-device and emulator discovery deterministic;
    // LAN broadcast/direct targets still follow for physical peers.
    final rawTargets = <String>{'127.0.0.1', '255.255.255.255'};
    var hasUsableNetwork = false;
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );
      for (final networkInterface in interfaces) {
        for (final address in networkInterface.addresses) {
          final raw = address.rawAddress;
          if (raw.length != 4) {
            continue;
          }
          if (!address.isLoopback && !address.isLinkLocal) {
            hasUsableNetwork = true;
          }
          // Direct unicast also makes same-host discovery reliable when the
          // network drops the limited broadcast packet.
          rawTargets.add(address.address);
        }
      }
    } on Object {
      // Limited broadcast remains available if interface inspection fails.
    }
    _broadcastTargets = [for (final raw in rawTargets) InternetAddress(raw)];
    _hasUsableNetwork = hasUsableNetwork;
  }

  void _ensureNetworkAvailable() {
    if (Platform.isAndroid && !_hasUsableNetwork) {
      throw const JamSessionException(JamSessionException.networkUnavailable);
    }
  }

  void _handleClockPong(Map<String, dynamic> message) {
    final id = message['t'];
    final conductorT = message['conductorT'];
    if (id is! String || conductorT is! String) {
      return;
    }
    final sendAt = _clockPingSent.remove(id);
    if (sendAt == null) {
      return;
    }
    final conductorNow = DateTime.tryParse(conductorT)?.toUtc();
    if (conductorNow == null) {
      return;
    }
    final recvAt = _clock();
    final sample = jamClockOffsetSample(
      memberSendAt: sendAt,
      conductorNow: conductorNow,
      memberRecvAt: recvAt,
    );
    _clockSamples.add(sample);
    if (_clockSamples.length > jamClockMaxSamples) {
      _clockSamples.removeAt(0);
    }
    final offset = jamClockOffsetFromSamples(_clockSamples);
    if (offset != null && offset != _clockOffset) {
      _clockOffset = offset;
      _clockOffsetController.add(offset);
    }
  }

  void _broadcastState() {
    final session = _session;
    if (session == null) {
      return;
    }
    _broadcast({'type': 'state', 'session': session.toJson()});
  }

  void _broadcast(Map<String, Object?> message) {
    for (final socket in [..._clientIds.keys]) {
      _write(socket, message);
    }
  }

  void _write(Socket socket, Map<String, Object?> message) {
    try {
      socket.add(utf8.encode(encodeJamLanLine(message)));
    } on Object {
      socket.destroy();
    }
  }

  void _listenLines(
    Socket socket,
    void Function(Map<String, dynamic> message) onMessage, {
    required void Function() onDone,
  }) {
    var pending = '';
    socket.listen(
      (data) {
        pending += utf8.decode(data, allowMalformed: true);
        var index = pending.indexOf('\n');
        while (index != -1) {
          final line = pending.substring(0, index).trim();
          pending = pending.substring(index + 1);
          if (line.isNotEmpty) {
            final message = decodeJamLanMessage(line);
            if (message != null) {
              onMessage(message);
            }
          }
          index = pending.indexOf('\n');
        }
      },
      onDone: onDone,
      onError: (_, _) => onDone(),
      cancelOnError: true,
    );
  }

  Future<void> _handleRemoteClosed() async {
    final session = _session;
    _session = null;
    await _disconnectClient(emitClosed: false);
    if (session != null) {
      _emitFor(session.id, null);
    }
  }

  Future<void> _stopHost({bool notifyClients = false}) async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    final session = _session;
    for (final socket in [..._clientIds.keys]) {
      if (notifyClients) {
        _write(socket, const {'type': 'closed'});
        try {
          await socket.flush();
        } on Object {
          // The client may already be gone.
        }
      }
      socket.destroy();
    }
    _clientIds.clear();
    _lastSeen.clear();
    final hadUdp = _udp != null;
    await _udpSubscription?.cancel();
    _udpSubscription = null;
    _udp?.close();
    _udp = null;
    if (hadUdp) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await _server?.close();
    _server = null;
    _session = null;
    if (session != null) {
      _emitFor(session.id, null);
    }
  }

  Future<void> _resetSession() async {
    await _stopHost();
    await _disconnectClient();
  }

  Future<void> _disconnectClient({bool emitClosed = true}) async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _clockSamples.clear();
    _clockPingSent.clear();
    _clockOffset = Duration.zero;
    for (final completer in _hostScoreRequests.values) {
      if (!completer.isCompleted) completer.complete(null);
    }
    _hostScoreRequests.clear();
    final session = _session;
    _client?.destroy();
    _client = null;
    _session = null;
    if (emitClosed && session != null) {
      _emitFor(session.id, null);
    }
  }

  void _emit(JamSession? session) {
    if (session == null) {
      return;
    }
    _emitFor(session.id, session);
  }

  void _emitFor(String sessionId, JamSession? session) {
    for (final controller in [...?_listeners[sessionId]]) {
      if (!controller.isClosed) {
        controller.add(session);
      }
    }
  }

  static String _defaultId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';

  static String _defaultCode() => '${Random().nextInt(9000) + 1000}';
}
