const String scoreVersionOriginalId = 'original';
const String scoreVersionLegacyPerformanceId = 'performance';

class ScoreVersionRef {
  const ScoreVersionRef({
    required this.id,
    required this.name,
  });

  factory ScoreVersionRef.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as String?)?.trim() ?? '';
    final name = (json['name'] as String?)?.trim() ?? '';
    if (id.isEmpty || name.isEmpty) {
      throw const FormatException('Score version id and name are required.');
    }
    return ScoreVersionRef(id: id, name: name);
  }

  final String id;
  final String name;

  bool get isOriginal => id == scoreVersionOriginalId;

  Map<String, Object?> toJson() => {'id': id, 'name': name};

  ScoreVersionRef copyWith({String? id, String? name}) {
    return ScoreVersionRef(id: id ?? this.id, name: name ?? this.name);
  }
}

class ScoreVersionCatalog {
  const ScoreVersionCatalog({
    this.activeId = scoreVersionOriginalId,
    this.versions = const [],
  });

  factory ScoreVersionCatalog.fromJson(Map<String, dynamic> json) {
    final rawVersions = json['versions'];
    final versions = <ScoreVersionRef>[];
    if (rawVersions is List) {
      for (final entry in rawVersions) {
        if (entry is! Map) continue;
        final version = ScoreVersionRef.fromJson(
          Map<String, dynamic>.from(entry),
        );
        if (version.isOriginal) continue;
        versions.add(version);
      }
    }
    final activeId = (json['activeId'] as String?)?.trim();
    final resolvedActive =
        activeId == null ||
            activeId.isEmpty ||
            (activeId != scoreVersionOriginalId &&
                versions.every((version) => version.id != activeId))
        ? scoreVersionOriginalId
        : activeId;
    return ScoreVersionCatalog(activeId: resolvedActive, versions: versions);
  }

  static const empty = ScoreVersionCatalog();

  final String activeId;
  final List<ScoreVersionRef> versions;

  List<ScoreVersionRef> get selectable {
    return [
      const ScoreVersionRef(id: scoreVersionOriginalId, name: 'Original'),
      ...versions,
    ];
  }

  ScoreVersionRef? find(String id) {
    if (id == scoreVersionOriginalId) {
      return const ScoreVersionRef(
        id: scoreVersionOriginalId,
        name: 'Original',
      );
    }
    for (final version in versions) {
      if (version.id == id) return version;
    }
    return null;
  }

  ScoreVersionCatalog copyWith({
    String? activeId,
    List<ScoreVersionRef>? versions,
  }) {
    return ScoreVersionCatalog(
      activeId: activeId ?? this.activeId,
      versions: versions ?? this.versions,
    );
  }

  Map<String, Object?> toJson() => {
    'activeId': activeId,
    'versions': [for (final version in versions) version.toJson()],
  };

  static int nextVersionNumber(List<ScoreVersionRef> versions) {
    var index = versions.length + 1;
    final used = {
      for (final version in versions) version.name,
    };
    while (used.contains('Version $index') || used.contains('버전 $index')) {
      index++;
    }
    return index;
  }
}
