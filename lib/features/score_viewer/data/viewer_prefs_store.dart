import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted score-viewer chrome prefs (layout, status bar, overlays).
class ViewerPrefs {
  const ViewerPrefs({
    this.viewMode = 'fit',
    this.statusBarVisible = true,
    this.annotationsVisible = true,
  });

  final String viewMode;
  final bool statusBarVisible;
  final bool annotationsVisible;

  ViewerPrefs copyWith({
    String? viewMode,
    bool? statusBarVisible,
    bool? annotationsVisible,
  }) {
    return ViewerPrefs(
      viewMode: viewMode ?? this.viewMode,
      statusBarVisible: statusBarVisible ?? this.statusBarVisible,
      annotationsVisible: annotationsVisible ?? this.annotationsVisible,
    );
  }
}

class ViewerPrefsStore {
  static const _viewModeKey = 'viewer.view_mode';
  static const _statusBarKey = 'viewer.status_bar_visible';
  static const _annotationsKey = 'viewer.annotations_visible';

  Future<ViewerPrefs> read() async {
    final prefs = await SharedPreferences.getInstance();
    return ViewerPrefs(
      viewMode: prefs.getString(_viewModeKey) ?? 'fit',
      statusBarVisible: prefs.getBool(_statusBarKey) ?? true,
      annotationsVisible: prefs.getBool(_annotationsKey) ?? true,
    );
  }

  Future<void> write(ViewerPrefs value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_viewModeKey, value.viewMode);
    await prefs.setBool(_statusBarKey, value.statusBarVisible);
    await prefs.setBool(_annotationsKey, value.annotationsVisible);
  }
}

final viewerPrefsStoreProvider = Provider<ViewerPrefsStore>((ref) {
  return ViewerPrefsStore();
});
