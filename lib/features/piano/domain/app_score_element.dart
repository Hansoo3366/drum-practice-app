/// Stable application identity for notation elements.
///
/// Engine identifiers (Verovio xml:id and Lomse ImoId) are deliberately kept
/// outside this model. They are valid only for the current native session.
class AppScoreElementKey {
  const AppScoreElementKey({required this.id, required this.locator});

  factory AppScoreElementKey.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('App score element key is invalid.');
    }
    final id = _requiredString(raw['id'], 'App element id');
    return AppScoreElementKey(
      id: id,
      locator: ScoreEventLocator.fromJson(raw['locator']),
    );
  }

  final String id;
  final ScoreEventLocator locator;

  Map<String, Object?> toJson() => {'id': id, 'locator': locator.toJson()};

  AppScoreElementKey copyWith({String? id, ScoreEventLocator? locator}) {
    return AppScoreElementKey(
      id: id ?? this.id,
      locator: locator ?? this.locator,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppScoreElementKey &&
        other.id == id &&
        other.locator == locator;
  }

  @override
  int get hashCode => Object.hash(id, locator);
}

/// A semantic address used to find an element again after an engine reload.
///
/// This is a locator, not a permanent identity. In particular, `onsetTicks`
/// uses the app's common PPQ and does not depend on a measure's local
/// MusicXML divisions value.
class ScoreEventLocator {
  ScoreEventLocator({
    required this.partId,
    required this.measureUid,
    required this.staff,
    required this.voice,
    required this.onsetTicks,
    required this.elementKind,
    this.chordIndex,
  }) {
    if (partId.trim().isEmpty) {
      throw const FormatException('A part id is required.');
    }
    if (measureUid.trim().isEmpty) {
      throw const FormatException('A measure uid is required.');
    }
    if (staff <= 0) {
      throw const FormatException('A staff must be positive.');
    }
    if (voice.trim().isEmpty) {
      throw const FormatException('A voice is required.');
    }
    if (onsetTicks < 0) {
      throw const FormatException('An onset cannot be negative.');
    }
    if (elementKind.trim().isEmpty) {
      throw const FormatException('An element kind is required.');
    }
    if (chordIndex != null && chordIndex! < 0) {
      throw const FormatException('A chord index cannot be negative.');
    }
  }

  factory ScoreEventLocator.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('Score event locator is invalid.');
    }
    return ScoreEventLocator(
      partId: _requiredString(raw['partId'], 'Part id'),
      measureUid: _requiredString(raw['measureUid'], 'Measure uid'),
      staff: _requiredInt(raw['staff'], 'Staff'),
      voice: _requiredString(raw['voice'], 'Voice'),
      onsetTicks: _requiredInt(raw['onsetTicks'], 'Onset ticks'),
      elementKind: _requiredString(raw['elementKind'], 'Element kind'),
      chordIndex: _optionalInt(raw['chordIndex'], 'Chord index'),
    );
  }

  final String partId;
  final String measureUid;
  final int staff;
  final String voice;
  final int onsetTicks;
  final String elementKind;
  final int? chordIndex;

  Map<String, Object?> toJson() => {
    'partId': partId,
    'measureUid': measureUid,
    'staff': staff,
    'voice': voice,
    'onsetTicks': onsetTicks,
    'elementKind': elementKind,
    if (chordIndex != null) 'chordIndex': chordIndex,
  };

  ScoreEventLocator copyWith({
    String? partId,
    String? measureUid,
    int? staff,
    String? voice,
    int? onsetTicks,
    String? elementKind,
    Object? chordIndex = _notProvided,
  }) {
    return ScoreEventLocator(
      partId: partId ?? this.partId,
      measureUid: measureUid ?? this.measureUid,
      staff: staff ?? this.staff,
      voice: voice ?? this.voice,
      onsetTicks: onsetTicks ?? this.onsetTicks,
      elementKind: elementKind ?? this.elementKind,
      chordIndex: identical(chordIndex, _notProvided)
          ? this.chordIndex
          : chordIndex as int?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ScoreEventLocator &&
        other.partId == partId &&
        other.measureUid == measureUid &&
        other.staff == staff &&
        other.voice == voice &&
        other.onsetTicks == onsetTicks &&
        other.elementKind == elementKind &&
        other.chordIndex == chordIndex;
  }

  @override
  int get hashCode => Object.hash(
    partId,
    measureUid,
    staff,
    voice,
    onsetTicks,
    elementKind,
    chordIndex,
  );
}

const Object _notProvided = Object();

String _requiredString(Object? raw, String label) {
  if (raw is! String || raw.trim().isEmpty) {
    throw FormatException('$label is required.');
  }
  return raw;
}

int _requiredInt(Object? raw, String label) {
  if (raw is int) return raw;
  if (raw is num && raw == raw.roundToDouble()) return raw.toInt();
  throw FormatException('$label must be an integer.');
}

int? _optionalInt(Object? raw, String label) {
  if (raw == null) return null;
  return _requiredInt(raw, label);
}
