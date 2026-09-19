import 'package:page_a_diddle/features/storage/cloud/domain/cloud_models.dart';

/// Mobile OAuth client IDs (public). Build defines can override the defaults.
///
/// Examples:
/// ```
/// flutter run \
///   --dart-define=GOOGLE_SERVER_CLIENT_ID=xxx.apps.googleusercontent.com \
///   --dart-define=DROPBOX_CLIENT_ID=xxxxxxxxxxxx
/// ```
abstract final class CloudOAuthConfig {
  /// Google Cloud Console → OAuth 2.0 Web client ID (used as serverClientId).
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '51772780399-i9jhsojurmmf7k1aht2ih4ggmudjj4b5.apps.googleusercontent.com',
  );

  /// Optional iOS Google client ID if different from Android default.
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );

  /// Dropbox app key (client id).
  static const dropboxClientId = String.fromEnvironment(
    'DROPBOX_CLIENT_ID',
    defaultValue: 'usuggo1fabglt8p',
  );

  /// AppAuth redirect scheme/URI for Dropbox (`db-<APP_KEY>://oauth`).
  static String get dropboxRedirectScheme => 'db-$dropboxClientId';
  static String get dropboxRedirectUri => '$dropboxRedirectScheme://oauth';

  /// Google: platform clients (SHA-1 / bundle) must be registered in Console.
  static bool canAttempt(CloudKind kind) => switch (kind) {
    CloudKind.googleDrive => googleServerClientId.isNotEmpty,
    CloudKind.dropbox => dropboxClientId.isNotEmpty,
  };

  static bool isConfigured(CloudKind kind) => canAttempt(kind);
}
