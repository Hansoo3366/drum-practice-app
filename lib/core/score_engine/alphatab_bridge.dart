import 'dart:convert';

/// Flutter → alphaTab 메시지.
sealed class AlphaTabCommand {
  const AlphaTabCommand();

  String get name;
  Map<String, Object?> get params;
}

/// MusicXML을 alphaTab에 로드.
class LoadScoreCommand extends AlphaTabCommand {
  const LoadScoreCommand({required this.xmlContent});

  final String xmlContent;

  @override
  String get name => 'loadScore';

  @override
  Map<String, Object?> get params => {'xmlContent': xmlContent};

  /// JavaScript 호출 문자열.
  String toJsCall() => 'bridgeLoadScore(${jsonEncode(xmlContent)})';
}

/// 특정 마디로 이동.
class GoToMeasureCommand extends AlphaTabCommand {
  const GoToMeasureCommand({required this.measureNumber});

  final int measureNumber;

  @override
  String get name => 'goToMeasure';

  @override
  Map<String, Object?> get params => {'measureNumber': measureNumber};

  String toJsCall() => 'bridgeGoToMeasure($measureNumber)';
}

/// Bar/Beat 커서 위치 설정.
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

/// 악보 확대/축소 배율 변경.
class SetZoomCommand extends AlphaTabCommand {
  const SetZoomCommand({required this.scale});

  /// 0.5~2.0 범위 권장.
  final double scale;

  @override
  String get name => 'setZoom';

  @override
  Map<String, Object?> get params => {'scale': scale};

  String toJsCall() => 'bridgeSetZoom($scale)';
}

/// A-B Loop 구간 설정.
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

/// 드럼 파트 필터 옵션과 함께 악보 로드.
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

/// 커서(하이라이트) 제거.
class ClearCursorCommand extends AlphaTabCommand {
  const ClearCursorCommand();

  @override
  String get name => 'clearCursor';

  @override
  Map<String, Object?> get params => const {};

  String toJsCall() => 'bridgeClearCursor()';
}

/// 컨테이너 너비에 맞춰 자동 스케일.
class AutoScaleCommand extends AlphaTabCommand {
  const AutoScaleCommand({required this.containerWidth});

  final double containerWidth;

  @override
  String get name => 'autoScale';

  @override
  Map<String, Object?> get params => {'containerWidth': containerWidth};

  String toJsCall() => 'bridgeAutoScale($containerWidth)';
}

/// alphaTab → Flutter 이벤트.
sealed class AlphaTabEvent {
  const AlphaTabEvent();

  factory AlphaTabEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    final rawData = json['data'];
    final data = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};
    return switch (type) {
      'ready' => const AlphaTabReadyEvent(),
      'scoreLoaded' => ScoreLoadedEvent.fromJson(data),
      'currentBarChanged' => CurrentBarChangedEvent.fromJson(data),
      'currentBeatChanged' => CurrentBeatChangedEvent.fromJson(data),
      'scoreTapped' => ScoreTappedEvent.fromJson(data),
      'loopRangeSet' => LoopRangeSetEvent.fromJson(data),
      'error' => AlphaTabErrorEvent.fromJson(data),
      _ => UnknownAlphaTabEvent(type: type ?? 'unknown'),
    };
  }
}

/// alphaTab WebView가 준비 완료.
class AlphaTabReadyEvent extends AlphaTabEvent {
  const AlphaTabReadyEvent();
}

/// 악보 로드 완료.
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
      tempo: json['tempo'] as int? ?? 120,
      partCount: json['partCount'] as int? ?? 0,
      measureCount: json['measureCount'] as int? ?? 0,
    );
  }

  final String title;
  final String artist;
  final int tempo;
  final int partCount;
  final int measureCount;
}

/// 현재 마디 변경.
class CurrentBarChangedEvent extends AlphaTabEvent {
  const CurrentBarChangedEvent({required this.measureNumber});

  factory CurrentBarChangedEvent.fromJson(Map<String, dynamic> json) {
    return CurrentBarChangedEvent(measureNumber: json['measure'] as int? ?? 0);
  }

  final int measureNumber;
}

/// 현재 Beat 변경.
class CurrentBeatChangedEvent extends AlphaTabEvent {
  const CurrentBeatChangedEvent({
    required this.measureNumber,
    required this.beatIndex,
  });

  factory CurrentBeatChangedEvent.fromJson(Map<String, dynamic> json) {
    return CurrentBeatChangedEvent(
      measureNumber: json['measure'] as int? ?? 0,
      beatIndex: json['beatIndex'] as int? ?? 0,
    );
  }

  final int measureNumber;
  final int beatIndex;
}

/// 사용자가 악보를 탭.
class ScoreTappedEvent extends AlphaTabEvent {
  const ScoreTappedEvent({required this.measure});

  factory ScoreTappedEvent.fromJson(Map<String, dynamic> json) {
    return ScoreTappedEvent(measure: json['measure'] as int? ?? 0);
  }

  final int measure;
}

/// Loop 구간 설정 완료.
class LoopRangeSetEvent extends AlphaTabEvent {
  const LoopRangeSetEvent({
    required this.startMeasure,
    required this.endMeasure,
  });

  factory LoopRangeSetEvent.fromJson(Map<String, dynamic> json) {
    return LoopRangeSetEvent(
      startMeasure: json['startMeasure'] as int? ?? 0,
      endMeasure: json['endMeasure'] as int? ?? 0,
    );
  }

  final int startMeasure;
  final int endMeasure;
}

/// alphaTab 오류.
class AlphaTabErrorEvent extends AlphaTabEvent {
  const AlphaTabErrorEvent({required this.message});

  factory AlphaTabErrorEvent.fromJson(Map<String, dynamic> json) {
    return AlphaTabErrorEvent(
      message: json['message'] as String? ?? 'Unknown error',
    );
  }

  final String message;
}

/// 알 수 없는 이벤트.
class UnknownAlphaTabEvent extends AlphaTabEvent {
  const UnknownAlphaTabEvent({required this.type});

  final String type;
}
