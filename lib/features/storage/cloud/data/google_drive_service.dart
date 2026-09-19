import 'dart:typed_data';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:page_a_diddle/features/library/domain/picked_local_file.dart';
import 'package:page_a_diddle/features/library/domain/score_file_filter.dart';
import 'package:page_a_diddle/features/storage/cloud/data/cloud_oauth_config.dart';
import 'package:page_a_diddle/features/storage/cloud/data/cloud_token_store.dart';
import 'package:page_a_diddle/features/storage/cloud/domain/cloud_models.dart';

class GoogleDriveService {
  GoogleDriveService(this._tokens);

  final CloudTokenStore _tokens;

  static const _scopes = <String>[drive.DriveApi.driveReadonlyScope];
  static Future<void>? _initFuture;

  drive.DriveApi? _cachedApi;
  Future<drive.DriveApi>? _apiInFlight;

  Future<void> _ensureInitialized() {
    return _initFuture ??= GoogleSignIn.instance.initialize(
      serverClientId: CloudOAuthConfig.googleServerClientId.isEmpty
          ? null
          : CloudOAuthConfig.googleServerClientId,
      clientId: CloudOAuthConfig.googleIosClientId.isEmpty
          ? null
          : CloudOAuthConfig.googleIosClientId,
    );
  }

  void _clearApiCache() {
    _cachedApi = null;
    _apiInFlight = null;
  }

  Future<bool> isConnected() => _tokens.hasSession(CloudKind.googleDrive);

  Future<void> connect() async {
    _clearApiCache();
    await _ensureInitialized();
    try {
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: _scopes,
      );
      final authz =
          await account.authorizationClient.authorizationForScopes(_scopes) ??
          await account.authorizationClient.authorizeScopes(_scopes);
      await _tokens.writeSession(
        kind: CloudKind.googleDrive,
        accessToken: authz.accessToken,
        extra: account.email,
      );
      _cachedApi = drive.DriveApi(authz.authClient(scopes: _scopes));
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const CloudAuthException('Google sign-in cancelled');
      }
      throw CloudAuthException(error.description ?? error.code.name);
    }
  }

  Future<void> disconnect() async {
    _clearApiCache();
    await _ensureInitialized();
    try {
      await GoogleSignIn.instance.disconnect();
    } on Object {
      await GoogleSignIn.instance.signOut();
    }
    await _tokens.clear(CloudKind.googleDrive);
  }

  /// Reuses the Drive client after the first sign-in so folder navigation
  /// does not re-trigger Google Sign-In UI.
  Future<drive.DriveApi> _api() {
    if (_cachedApi != null) {
      return Future<drive.DriveApi>.value(_cachedApi!);
    }
    if (_apiInFlight != null) return _apiInFlight!;

    final future = _createApi();
    _apiInFlight = future;
    return future.then((api) {
      _cachedApi = api;
      if (identical(_apiInFlight, future)) _apiInFlight = null;
      return api;
    }).catchError((Object error, StackTrace stack) {
      if (identical(_apiInFlight, future)) _apiInFlight = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<drive.DriveApi> _createApi() async {
    await _ensureInitialized();

    GoogleSignInAccount? account;
    final lightweight =
        GoogleSignIn.instance.attemptLightweightAuthentication();
    if (lightweight != null) {
      try {
        account = await lightweight;
      } on Object {
        account = null;
      }
    }

    // Interactive sign-in only when there is no silent session.
    account ??= await GoogleSignIn.instance.authenticate(scopeHint: _scopes);

    // Prefer silent scope grant; UI only if Drive was never authorized.
    var authz =
        await account.authorizationClient.authorizationForScopes(_scopes);
    authz ??= await account.authorizationClient.authorizeScopes(_scopes);

    await _tokens.writeSession(
      kind: CloudKind.googleDrive,
      accessToken: authz.accessToken,
      extra: account.email,
    );
    return drive.DriveApi(authz.authClient(scopes: _scopes));
  }

  Future<List<CloudEntry>> list({
    String? folderId,
    ScoreFileFilter filter = ScoreFileFilter.pdf,
  }) async {
    final api = await _api();
    final parent = folderId ?? 'root';
    final fileQuery = switch (filter) {
      ScoreFileFilter.pdf =>
        "mimeType = 'application/pdf' or name contains '.pdf'",
      ScoreFileFilter.musicXml =>
        "name contains '.musicxml' or name contains '.mxl' or "
            "name contains '.xml'",
    };
    final query =
        "'$parent' in parents and trashed = false and "
        "(mimeType = 'application/vnd.google-apps.folder' or $fileQuery)";
    final result = await api.files.list(
      q: query,
      spaces: 'drive',
      corpora: 'user',
      $fields: 'files(id, name, mimeType, size)',
      orderBy: 'folder,name',
      pageSize: 200,
    );
    final files = result.files ?? const <drive.File>[];
    return [
      for (final file in files)
        if (file.id != null && file.name != null)
          CloudEntry(
            id: file.id!,
            name: file.name!,
            isFolder: file.mimeType == 'application/vnd.google-apps.folder',
            size: int.tryParse(file.size ?? ''),
          ),
    ];
  }

  Future<PickedLocalFile> download(CloudEntry entry) async {
    if (entry.isFolder) {
      throw const CloudAuthException('Cannot download a folder');
    }
    final api = await _api();
    final media =
        await api.files.get(
              entry.id,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;
    final builder = BytesBuilder(copy: false);
    await for (final chunk in media.stream) {
      builder.add(chunk);
    }
    return PickedLocalFile(name: entry.name, bytes: builder.takeBytes());
  }
}
