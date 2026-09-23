/// App-level metadata that must not be embedded in the notation engine model.
class PianoScoreSidecar {
  PianoScoreSidecar({
    required this.scoreId,
    required this.sourceRevision,
    List<PianoScoreSection> sections = const [],
    List<PianoArrangementItem> arrangement = const [],
    this.schemaVersion = 1,
  }) : sections = List.unmodifiable(sections),
       arrangement = List.unmodifiable(arrangement) {
    if (schemaVersion <= 0) {
      throw const FormatException('Sidecar schema version must be positive.');
    }
    if (scoreId.trim().isEmpty) {
      throw const FormatException('A score id is required.');
    }
    if (sourceRevision.trim().isEmpty) {
      throw const FormatException('A source revision is required.');
    }
    final ids = <String>{};
    for (final section in this.sections) {
      if (!ids.add(section.id)) {
        throw FormatException('Duplicate section id: ${section.id}');
      }
    }
    for (final item in this.arrangement) {
      if (!ids.contains(item.sectionId)) {
        throw FormatException(
          'Arrangement references an unknown section: ${item.sectionId}',
        );
      }
    }
  }

  factory PianoScoreSidecar.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('Piano score sidecar is invalid.');
    }
    final sections = _listFromJson(raw['sections'], PianoScoreSection.fromJson);
    final arrangement = _listFromJson(
      raw['arrangement'],
      PianoArrangementItem.fromJson,
    );
    return PianoScoreSidecar(
      schemaVersion: _intOr(raw['schemaVersion'], 1),
      scoreId: _stringOrThrow(raw['scoreId'], 'Score id'),
      sourceRevision: _stringOrThrow(raw['sourceRevision'], 'Source revision'),
      sections: sections,
      arrangement: arrangement,
    );
  }

  final int schemaVersion;
  final String scoreId;
  final String sourceRevision;
  final List<PianoScoreSection> sections;
  final List<PianoArrangementItem> arrangement;

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'scoreId': scoreId,
    'sourceRevision': sourceRevision,
    'sections': [for (final section in sections) section.toJson()],
    'arrangement': [for (final item in arrangement) item.toJson()],
  };

  PianoScoreSidecar copyWith({
    int? schemaVersion,
    String? scoreId,
    String? sourceRevision,
    List<PianoScoreSection>? sections,
    List<PianoArrangementItem>? arrangement,
  }) {
    return PianoScoreSidecar(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      scoreId: scoreId ?? this.scoreId,
      sourceRevision: sourceRevision ?? this.sourceRevision,
      sections: sections ?? this.sections,
      arrangement: arrangement ?? this.arrangement,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PianoScoreSidecar &&
        other.schemaVersion == schemaVersion &&
        other.scoreId == scoreId &&
        other.sourceRevision == sourceRevision &&
        _sameList(other.sections, sections) &&
        _sameList(other.arrangement, arrangement);
  }

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    scoreId,
    sourceRevision,
    Object.hashAll(sections),
    Object.hashAll(arrangement),
  );
}

class PianoScoreSection {
  const PianoScoreSection({
    required this.id,
    required this.label,
    required this.startMeasureUid,
    required this.endMeasureUid,
  });

  factory PianoScoreSection.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('Piano score section is invalid.');
    }
    return PianoScoreSection(
      id: _stringOrThrow(raw['id'], 'Section id'),
      label: _stringOrThrow(raw['label'], 'Section label'),
      startMeasureUid: _stringOrThrow(
        raw['startMeasureUid'],
        'Section start measure uid',
      ),
      endMeasureUid: _stringOrThrow(
        raw['endMeasureUid'],
        'Section end measure uid',
      ),
    );
  }

  final String id;
  final String label;
  final String startMeasureUid;
  final String endMeasureUid;

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'startMeasureUid': startMeasureUid,
    'endMeasureUid': endMeasureUid,
  };

  @override
  bool operator ==(Object other) {
    return other is PianoScoreSection &&
        other.id == id &&
        other.label == label &&
        other.startMeasureUid == startMeasureUid &&
        other.endMeasureUid == endMeasureUid;
  }

  @override
  int get hashCode => Object.hash(id, label, startMeasureUid, endMeasureUid);
}

class PianoArrangementItem {
  PianoArrangementItem({required this.sectionId, this.playCount = 1}) {
    if (sectionId.trim().isEmpty) {
      throw const FormatException('An arrangement section id is required.');
    }
    if (playCount <= 0) {
      throw const FormatException('Arrangement play count must be positive.');
    }
  }

  factory PianoArrangementItem.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('Piano arrangement item is invalid.');
    }
    return PianoArrangementItem(
      sectionId: _stringOrThrow(raw['sectionId'], 'Arrangement section id'),
      playCount: _intOr(raw['playCount'], 1),
    );
  }

  final String sectionId;
  final int playCount;

  Map<String, Object?> toJson() => {
    'sectionId': sectionId,
    'playCount': playCount,
  };

  @override
  bool operator ==(Object other) {
    return other is PianoArrangementItem &&
        other.sectionId == sectionId &&
        other.playCount == playCount;
  }

  @override
  int get hashCode => Object.hash(sectionId, playCount);
}

List<T> _listFromJson<T>(Object? raw, T Function(Object? value) decode) {
  if (raw == null) return const [];
  if (raw is! List) {
    throw const FormatException('Sidecar list is invalid.');
  }
  return [for (final item in raw) decode(item)];
}

String _stringOrThrow(Object? raw, String label) {
  if (raw is! String || raw.trim().isEmpty) {
    throw FormatException('$label is required.');
  }
  return raw;
}

int _intOr(Object? raw, int fallback) {
  if (raw == null) return fallback;
  if (raw is int) return raw;
  if (raw is num && raw == raw.roundToDouble()) return raw.toInt();
  throw const FormatException('Sidecar integer is invalid.');
}

bool _sameList<T>(List<T> left, List<T> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
