import 'app_score_element.dart';

/// JSON-safe edit request that will cross the future Lomse FFI boundary.
///
/// The native implementation is intentionally not coupled to this contract
/// yet. Keeping the command surface small lets the Flutter UI and tests move
/// ahead without exposing Lomse's internal C++ types.
class LomseEditRequest {
  const LomseEditRequest({
    required this.action,
    this.target,
    this.values = const <String, Object?>{},
  });

  factory LomseEditRequest.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('Lomse edit request is invalid.');
    }
    final action = raw['action'];
    if (action is! String || action.trim().isEmpty) {
      throw const FormatException('A Lomse edit action is required.');
    }
    final rawValues = raw['values'];
    if (rawValues != null && rawValues is! Map) {
      throw const FormatException('Lomse edit values are invalid.');
    }
    return LomseEditRequest(
      action: action,
      target: raw['target'] == null
          ? null
          : AppScoreElementKey.fromJson(raw['target']),
      values: rawValues == null
          ? const <String, Object?>{}
          : Map<String, Object?>.from(rawValues as Map),
    );
  }

  final String action;
  final AppScoreElementKey? target;
  final Map<String, Object?> values;

  Map<String, Object?> toJson() => {
    'action': action,
    if (target != null) 'target': target!.toJson(),
    'values': values,
  };
}

/// Session boundary for the native Lomse editor.
///
/// The eventual Android implementation will keep the native pointer private
/// and expose only MusicXML, JSON-safe commands, and monotonically increasing
/// revisions to Flutter.
abstract interface class LomseEditorSession {
  int get revision;

  Future<void> loadMusicXml(String musicXml);

  Future<void> execute(LomseEditRequest request);

  Future<void> undo();

  Future<void> redo();

  Future<String> exportMusicXml();

  Future<void> dispose();
}
