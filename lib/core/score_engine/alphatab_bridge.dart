import 'dart:convert';

sealed class AlphaTabCommand {
  const AlphaTabCommand();

  String get name;
  Map<String, Object?> get params;
}

class LoadScoreCommand extends AlphaTabCommand {
  const LoadScoreCommand({required this.xmlContent});

  final String xmlContent;

  @override
  String get name => 'loadScore';

  @override
  Map<String, Object?> get params => {'xmlContent': xmlContent};

  String toJsCall() => 'bridgeLoadScore(${jsonEncode(xmlContent)})';
}

class GoToMeasureCommand extends AlphaTabCommand {
  const GoToMeasureCommand({required this.measureNumber});

  final int measureNumber;

  @override
  String get name => 'goToMeasure';

  @override
  Map<String, Object?> get params => {'measureNumber': measureNumber};

  String toJsCall() => 'bridgeGoToMeasure($measureNumber)';
}

class SetCursorCommand extends AlphaTabCommand {
  const SetCursorCommand({required this.measureNumber, this.beatIndex = 0});

  final int measureNumber;
  final int beatIndex;

  @override
  String get name => 'setCursor';

  @override
  Map<String, Object?> get params => {
    'measureNumber': measureNumber,
    'beatIndex': beatIndex,
  };

  String toJsCall() => 'bridgeSetCursor($measureNumber, $beatIndex)';
}

class SetZoomCommand extends AlphaTabCommand {
  const SetZoomCommand({required this.scale});

  final double scale;

  @override
  String get name => 'setZoom';

  @override
  Map<String, Object?> get params => {'scale': scale};

  String toJsCall() => 'bridgeSetZoom($scale)';
}

class SetLoopRangeCommand extends AlphaTabCommand {
  const SetLoopRangeCommand({
    required this.startMeasure,
    required this.endMeasure,
  });

  final int startMeasure;
  final int endMeasure;

  @override
  String get name => 'setLoopRange';

  @override
  Map<String, Object?> get params => {
    'startMeasure': startMeasure,
    'endMeasure': endMeasure,
  };

  String toJsCall() => 'bridgeSetLoopRange($startMeasure, $endMeasure)';
}

class LoadScoreWithFilterCommand extends AlphaTabCommand {
  const LoadScoreWithFilterCommand({
    required this.xmlContent,
    this.drumOnly = true,
  });

  final String xmlContent;
  final bool drumOnly;

  @override
  String get name => 'loadScoreWithFilter';

  @override
  Map<String, Object?> get params => {
    'xmlContent': xmlContent,
    'drumOnly': drumOnly,
  };

  String toJsCall() =>
      'bridgeLoadScoreWithFilter(${jsonEncode(xmlContent)}, $drumOnly)';
}

class ClearCursorCommand extends AlphaTabCommand {
  const ClearCursorCommand();

  @override
  String get name => 'clearCursor';

  @override
  Map<String, Object?> get params => const {};

  String toJsCall() => 'bridgeClearCursor()';
}

class AutoScaleCommand extends AlphaTabCommand {
  const AutoScaleCommand({required this.containerWidth});

  final double containerWidth;

  @override
  String get name => 'autoScale';

  @override
  Map<String, Object?> get params => {'containerWidth': containerWidth};

  String toJsCall() => 'bridgeAutoScale($containerWidth)';
}

class SetViewportWidthCommand extends AlphaTabCommand {
  const SetViewportWidthCommand({required this.width, this.height});

  final double width;
  final double? height;

  @override
  String get name => 'setViewportWidth';

  @override
  Map<String, Object?> get params => {
    'width': width,
    if (height != null) 'height': height,
  };

  String toJsCall() => height == null
      ? 'bridgeSetViewportWidth($width)'
      : 'bridgeSetViewport($width, $height)';
}

class PlayPauseScoreCommand extends AlphaTabCommand {
  const PlayPauseScoreCommand();

  @override
  String get name => 'playPauseScore';

  @override
  Map<String, Object?> get params => const {};

  String toJsCall() => 'bridgePlayPause()';
}

class PauseScorePlaybackCommand extends AlphaTabCommand {
  const PauseScorePlaybackCommand();

  @override
  String get name => 'pauseScorePlayback';

  @override
  Map<String, Object?> get params => const {};

  String toJsCall() => 'bridgePausePlayback()';
}

class StopScorePlaybackCommand extends AlphaTabCommand {
  const StopScorePlaybackCommand();

  @override
  String get name => 'stopScorePlayback';

  @override
  Map<String, Object?> get params => const {};

  String toJsCall() => 'bridgeStopPlayback()';
}

class SeekScorePlaybackCommand extends AlphaTabCommand {
  const SeekScorePlaybackCommand({required this.positionMs});

  final double positionMs;

  @override
  String get name => 'seekScorePlayback';

  @override
  Map<String, Object?> get params => {'positionMs': positionMs};

  String toJsCall() => 'bridgeSeekPlayback($positionMs)';
}

class RefreshPlaybackCommand extends AlphaTabCommand {
  const RefreshPlaybackCommand();

  @override
  String get name => 'refreshPlayback';

  @override
  Map<String, Object?> get params => const {};

  String toJsCall() => 'bridgeRefreshPlayback()';
}

class SetPlaybackVisibleCommand extends AlphaTabCommand {
  const SetPlaybackVisibleCommand({required this.visible});

  final bool visible;

  @override
  String get name => 'setPlaybackVisible';

  @override
  Map<String, Object?> get params => {'visible': visible};

  String toJsCall() => 'bridgeSetPlaybackVisible($visible)';
}

class SetScorePlaybackSpeedCommand extends AlphaTabCommand {
  const SetScorePlaybackSpeedCommand({required this.speed});

  final double speed;

  @override
  String get name => 'setScorePlaybackSpeed';

  @override
  Map<String, Object?> get params => {'speed': speed};

  String toJsCall() => 'bridgeSetPlaybackSpeed($speed)';
}

class HighlightMeasureCommand extends AlphaTabCommand {
  const HighlightMeasureCommand({this.measureIndex});

  final int? measureIndex;

  @override
  String get name => 'highlightMeasure';

  @override
  Map<String, Object?> get params => {'measureIndex': measureIndex};

  String toJsCall() => 'bridgeHighlightMeasure(${measureIndex ?? -1})';
}

class SetMeasureKeysCommand extends AlphaTabCommand {
  const SetMeasureKeysCommand({required this.fifths});

  final List<int> fifths;

  @override
  String get name => 'setMeasureKeys';

  @override
  Map<String, Object?> get params => {'fifths': fifths};

  String toJsCall() => 'bridgeSetMeasureKeys(${jsonEncode(fifths)})';
}

class SetMeasureSectionsCommand extends AlphaTabCommand {
  const SetMeasureSectionsCommand({required this.labels});

  final List<String> labels;

  @override
  String get name => 'setMeasureSections';

  @override
  Map<String, Object?> get params => {'labels': labels};

  String toJsCall() => 'bridgeSetMeasureSections(${jsonEncode(labels)})';
}

sealed class AlphaTabEvent {
  const AlphaTabEvent();

  factory AlphaTabEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    final rawData = json['data'];
    final data = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};
    return switch (type) {
      'ready' => AlphaTabReadyEvent.fromJson(data),
      'scoreLoaded' => ScoreLoadedEvent.fromJson(data),
      'renderStarted' => const AlphaTabRenderStartedEvent(),
      'renderFinished' => AlphaTabRenderedEvent.fromJson(data),
      'currentBarChanged' => CurrentBarChangedEvent.fromJson(data),
      'currentBeatChanged' => CurrentBeatChangedEvent.fromJson(data),
      'scoreTapped' => ScoreTappedEvent.fromJson(data),
      'scoreSystems' => ScoreSystemsEvent.fromJson(data),
      'noteTapped' => AlphaTabNoteTappedEvent.fromJson(data),
      'staffTapped' => AlphaTabStaffTappedEvent.fromJson(data),
      'noteDragged' => AlphaTabNoteDraggedEvent.fromJson(data),
      'playerReady' => AlphaTabPlayerReadyEvent.fromJson(data),
      'playerIssue' => AlphaTabPlayerIssueEvent.fromJson(data),
      'playerStateChanged' => AlphaTabPlayerStateEvent.fromJson(data),
      'playerPositionChanged' => AlphaTabPlayerPositionEvent.fromJson(data),
      'playedBeatChanged' => AlphaTabPlayedBeatEvent.fromJson(data),
      'playerFinished' => const AlphaTabPlayerFinishedEvent(),
      'loopRangeSet' => LoopRangeSetEvent.fromJson(data),
      'error' => AlphaTabErrorEvent.fromJson(data),
      _ => UnknownAlphaTabEvent(type: type ?? 'unknown'),
    };
  }
}

class AlphaTabReadyEvent extends AlphaTabEvent {
  const AlphaTabReadyEvent({this.version});

  factory AlphaTabReadyEvent.fromJson(Map<String, dynamic> json) {
    return AlphaTabReadyEvent(version: json['version'] as String?);
  }

  final String? version;
}

class ScoreLoadedEvent extends AlphaTabEvent {
  const ScoreLoadedEvent({
    required this.title,
    required this.artist,
    required this.tempo,
    required this.partCount,
    required this.measureCount,
  });

  factory ScoreLoadedEvent.fromJson(Map<String, dynamic> json) {
    return ScoreLoadedEvent(
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      tempo: _readInt(json['tempo'], fallback: 120),
      partCount: _readInt(json['partCount']),
      measureCount: _readInt(json['measureCount']),
    );
  }

  final String title;
  final String artist;
  final int tempo;
  final int partCount;
  final int measureCount;
}

class AlphaTabRenderStartedEvent extends AlphaTabEvent {
  const AlphaTabRenderStartedEvent();
}

class AlphaTabRenderedEvent extends AlphaTabEvent {
  const AlphaTabRenderedEvent({
    required this.contentHeight,
    required this.scale,
  });

  factory AlphaTabRenderedEvent.fromJson(Map<String, dynamic> json) {
    return AlphaTabRenderedEvent(
      contentHeight: _readDouble(json['contentHeight']),
      scale: _readDouble(json['scale'], fallback: 1),
    );
  }

  final double contentHeight;
  final double scale;
}

class CurrentBarChangedEvent extends AlphaTabEvent {
  const CurrentBarChangedEvent({required this.measureNumber});

  factory CurrentBarChangedEvent.fromJson(Map<String, dynamic> json) {
    return CurrentBarChangedEvent(measureNumber: _readInt(json['measure']));
  }

  final int measureNumber;
}

class CurrentBeatChangedEvent extends AlphaTabEvent {
  const CurrentBeatChangedEvent({
    required this.measureNumber,
    required this.beatIndex,
  });

  factory CurrentBeatChangedEvent.fromJson(Map<String, dynamic> json) {
    return CurrentBeatChangedEvent(
      measureNumber: _readInt(json['measure']),
      beatIndex: _readInt(json['beatIndex']),
    );
  }

  final int measureNumber;
  final int beatIndex;
}

class ScoreSystemsEvent extends AlphaTabEvent {
  const ScoreSystemsEvent({required this.systems});

  factory ScoreSystemsEvent.fromJson(Map<String, dynamic> json) {
    final raw = json['systems'];
    if (raw is! List) return const ScoreSystemsEvent(systems: []);
    return ScoreSystemsEvent(
      systems: [
        for (final item in raw)
          if (item is Map)
            (
              start: _readInt(item['start']),
              end: _readInt(item['end']),
            ),
      ],
    );
  }

  final List<({int start, int end})> systems;
}

class ScoreTappedEvent extends AlphaTabEvent {
  const ScoreTappedEvent({required this.measure});

  factory ScoreTappedEvent.fromJson(Map<String, dynamic> json) {
    return ScoreTappedEvent(measure: _readInt(json['measure']));
  }

  final int measure;
}

class AlphaTabNoteTappedEvent extends AlphaTabEvent {
  const AlphaTabNoteTappedEvent({
    required this.partIndex,
    required this.measureIndex,
    required this.staff,
    required this.voiceIndex,
    required this.onsetTicks,
    required this.midi,
    required this.noteIndex,
  });

  factory AlphaTabNoteTappedEvent.fromJson(Map<String, dynamic> json) {
    return AlphaTabNoteTappedEvent(
      partIndex: _readInt(json['partIndex']),
      measureIndex: _readInt(json['measureIndex']),
      staff: _readInt(json['staff'], fallback: 1),
      voiceIndex: _readInt(json['voiceIndex']),
      onsetTicks: _readInt(json['onsetTicks']),
      midi: _readInt(json['midi']),
      noteIndex: _readInt(json['noteIndex']),
    );
  }

  final int partIndex;
  final int measureIndex;
  final int staff;
  final int voiceIndex;
  final int onsetTicks;
  final int midi;
  final int noteIndex;
}

class AlphaTabStaffTappedEvent extends AlphaTabEvent {
  const AlphaTabStaffTappedEvent({
    required this.partIndex,
    required this.measureIndex,
    required this.staff,
    required this.onsetTicks,
    required this.midi,
  });

  factory AlphaTabStaffTappedEvent.fromJson(Map<String, dynamic> json) {
    return AlphaTabStaffTappedEvent(
      partIndex: _readInt(json['partIndex']),
      measureIndex: _readInt(json['measureIndex']),
      staff: _readInt(json['staff'], fallback: 1),
      onsetTicks: _readInt(json['onsetTicks']),
      midi: _readInt(json['midi'], fallback: 67),
    );
  }

  final int partIndex;
  final int measureIndex;
  final int staff;
  final int onsetTicks;
  final int midi;
}

class AlphaTabNoteDraggedEvent extends AlphaTabEvent {
  const AlphaTabNoteDraggedEvent({
    required this.partIndex,
    required this.measureIndex,
    required this.staff,
    required this.onsetTicks,
    required this.originalMidi,
    required this.midi,
  });

  factory AlphaTabNoteDraggedEvent.fromJson(Map<String, dynamic> json) {
    return AlphaTabNoteDraggedEvent(
      partIndex: _readInt(json['partIndex']),
      measureIndex: _readInt(json['measureIndex']),
      staff: _readInt(json['staff'], fallback: 1),
      onsetTicks: _readInt(json['onsetTicks']),
      originalMidi: _readInt(json['originalMidi']),
      midi: _readInt(json['midi']),
    );
  }

  final int partIndex;
  final int measureIndex;
  final int staff;
  final int onsetTicks;
  final int originalMidi;
  final int midi;
}

class AlphaTabPlayerReadyEvent extends AlphaTabEvent {
  const AlphaTabPlayerReadyEvent({
    required this.durationMs,
    required this.endTick,
    this.readyForPlayback = false,
  });

  factory AlphaTabPlayerReadyEvent.fromJson(Map<String, dynamic> json) {
    return AlphaTabPlayerReadyEvent(
      durationMs: _readDouble(json['durationMs']),
      endTick: _readInt(json['endTick']),
      readyForPlayback: _readBool(json['readyForPlayback']),
    );
  }

  final double durationMs;
  final int endTick;
  final bool readyForPlayback;
}

class AlphaTabPlayerStateEvent extends AlphaTabEvent {
  const AlphaTabPlayerStateEvent({
    required this.playing,
    required this.stopped,
  });

  factory AlphaTabPlayerStateEvent.fromJson(Map<String, dynamic> json) {
    return AlphaTabPlayerStateEvent(
      playing: _readBool(json['playing']),
      stopped: _readBool(json['stopped']),
    );
  }

  final bool playing;
  final bool stopped;
}

class AlphaTabPlayerPositionEvent extends AlphaTabEvent {
  const AlphaTabPlayerPositionEvent({
    required this.currentTimeMs,
    required this.durationMs,
    required this.currentTick,
    required this.endTick,
  });

  factory AlphaTabPlayerPositionEvent.fromJson(Map<String, dynamic> json) {
    return AlphaTabPlayerPositionEvent(
      currentTimeMs: _readDouble(json['currentTimeMs']),
      durationMs: _readDouble(json['durationMs']),
      currentTick: _readInt(json['currentTick']),
      endTick: _readInt(json['endTick']),
    );
  }

  final double currentTimeMs;
  final double durationMs;
  final int currentTick;
  final int endTick;
}

class AlphaTabPlayedBeatEvent extends AlphaTabEvent {
  const AlphaTabPlayedBeatEvent({
    required this.partIndex,
    required this.measureIndex,
    required this.beatIndex,
  });

  factory AlphaTabPlayedBeatEvent.fromJson(Map<String, dynamic> json) {
    return AlphaTabPlayedBeatEvent(
      partIndex: _readInt(json['partIndex']),
      measureIndex: _readInt(json['measureIndex']),
      beatIndex: _readInt(json['beatIndex']),
    );
  }

  final int partIndex;
  final int measureIndex;
  final int beatIndex;
}

class AlphaTabPlayerFinishedEvent extends AlphaTabEvent {
  const AlphaTabPlayerFinishedEvent();
}

class AlphaTabPlayerIssueEvent extends AlphaTabEvent {
  const AlphaTabPlayerIssueEvent({required this.message});

  factory AlphaTabPlayerIssueEvent.fromJson(Map<String, dynamic> json) {
    return AlphaTabPlayerIssueEvent(message: json['message'] as String? ?? '');
  }

  final String message;
}

class LoopRangeSetEvent extends AlphaTabEvent {
  const LoopRangeSetEvent({
    required this.startMeasure,
    required this.endMeasure,
  });

  factory LoopRangeSetEvent.fromJson(Map<String, dynamic> json) {
    return LoopRangeSetEvent(
      startMeasure: _readInt(json['startMeasure']),
      endMeasure: _readInt(json['endMeasure']),
    );
  }

  final int startMeasure;
  final int endMeasure;
}

class AlphaTabErrorEvent extends AlphaTabEvent {
  const AlphaTabErrorEvent({required this.message});

  factory AlphaTabErrorEvent.fromJson(Map<String, dynamic> json) {
    return AlphaTabErrorEvent(
      message: json['message'] as String? ?? 'Unknown error',
    );
  }

  final String message;
}

class UnknownAlphaTabEvent extends AlphaTabEvent {
  const UnknownAlphaTabEvent({required this.type});

  final String type;
}

int _readInt(Object? value, {int fallback = 0}) {
  return switch (value) {
    final num number => number.round(),
    final String text => num.tryParse(text)?.round() ?? fallback,
    _ => fallback,
  };
}

double _readDouble(Object? value, {double fallback = 0}) {
  return switch (value) {
    final num number => number.toDouble(),
    final String text => double.tryParse(text) ?? fallback,
    _ => fallback,
  };
}

bool _readBool(Object? value, {bool fallback = false}) {
  return switch (value) {
    final bool boolean => boolean,
    final num number => number != 0,
    final String text => switch (text.toLowerCase()) {
      'true' || '1' => true,
      'false' || '0' => false,
      _ => fallback,
    },
    _ => fallback,
  };
}
