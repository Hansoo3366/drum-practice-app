import 'package:page_a_diddle/features/storage/cloud/domain/cloud_models.dart';

/// Mobile OAuth client IDs. Product defaults always apply; a non-empty
/// `--dart-define` can replace one value. Empty defines do not disable OAuth.
///
/// `dart_defines.json` keeps the same defaults for IDE/CI `--dart-define-from-file`.
abstract final class CloudOAuthConfig {
  static const googleDefaultServerClientId =
      '51772780399-i9jhsojurmmf7k1aht2ih4ggmudjj4b5.apps.googleusercontent.com';
  static const dropboxDefaultClientId = 'usuggo1fabglt8p';

  static const _googleOverride = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
  static const _dropboxOverride = String.fromEnvironment('DROPBOX_CLIENT_ID');

  /// Optional iOS Google client ID if different from Android default.
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );

  static String get googleServerClientId => _googleOverride.isNotEmpty
      ? _googleOverride
      : googleDefaultServerClientId;

  static String get dropboxClientId =>
      _dropboxOverride.isNotEmpty ? _dropboxOverride : dropboxDefaultClientId;

  /// AppAuth redirect scheme/URI for Dropbox (`db-<APP_KEY>://oauth`).
  static String get dropboxRedirectScheme => 'db-$dropboxClientId';
  static String get dropboxRedirectUri => '$dropboxRedirectScheme://oauth';

  static bool canAttempt(CloudKind kind) => switch (kind) {
    CloudKind.googleDrive => googleServerClientId.isNotEmpty,
    CloudKind.dropbox => dropboxClientId.isNotEmpty,
  };

  static bool isConfigured(CloudKind kind) => canAttempt(kind);
}
