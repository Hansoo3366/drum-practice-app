enum CloudKind {
  googleDrive,
  dropbox,
}

extension CloudKindX on CloudKind {
  String get id => switch (this) {
    CloudKind.googleDrive => 'google_drive',
    CloudKind.dropbox => 'dropbox',
  };
}

class CloudEntry {
  const CloudEntry({
    required this.id,
    required this.name,
    required this.isFolder,
    this.path,
    this.size,
  });

  final String id;
  final String name;
  final bool isFolder;

  /// Provider-specific path (Dropbox path_display, etc.).
  final String? path;
  final int? size;

  bool get isPdf {
    final lower = name.toLowerCase();
    return lower.endsWith('.pdf');
  }
}

class CloudAuthException implements Exception {
  const CloudAuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

class CloudNotConfiguredException implements Exception {
  const CloudNotConfiguredException(this.kind);
  final CloudKind kind;

  @override
  String toString() => 'Cloud OAuth not configured: ${kind.id}';
}
