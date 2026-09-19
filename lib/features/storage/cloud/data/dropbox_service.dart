import 'dart:convert';

import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:http/http.dart' as http;
import 'package:page_a_diddle/features/library/domain/picked_local_file.dart';
import 'package:page_a_diddle/features/library/domain/score_file_filter.dart';
import 'package:page_a_diddle/features/storage/cloud/data/cloud_oauth_config.dart';
import 'package:page_a_diddle/features/storage/cloud/data/cloud_token_store.dart';
import 'package:page_a_diddle/features/storage/cloud/domain/cloud_models.dart';

class DropboxService {
  DropboxService(this._tokens, {FlutterAppAuth? appAuth, http.Client? httpClient})
    : _appAuth = appAuth ?? const FlutterAppAuth(),
      _http = httpClient ?? http.Client();

  final CloudTokenStore _tokens;
  final FlutterAppAuth _appAuth;
  final http.Client _http;

  static const _kind = CloudKind.dropbox;

  static const _authEndpoint = 'https://www.dropbox.com/oauth2/authorize';
  static const _tokenEndpoint = 'https://api.dropboxapi.com/oauth2/token';

  Future<bool> isConnected() => _tokens.hasSession(_kind);

  Future<void> connect() async {
    if (!CloudOAuthConfig.canAttempt(_kind)) {
      throw const CloudNotConfiguredException(_kind);
    }
    final result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        CloudOAuthConfig.dropboxClientId,
        CloudOAuthConfig.dropboxRedirectUri,
        serviceConfiguration: const AuthorizationServiceConfiguration(
          authorizationEndpoint: _authEndpoint,
          tokenEndpoint: _tokenEndpoint,
        ),
        additionalParameters: const {'token_access_type': 'offline'},
      ),
    );
    final access = result.accessToken;
    if (access == null || access.isEmpty) {
      throw const CloudAuthException('Dropbox sign-in failed');
    }
    await _tokens.writeSession(
      kind: _kind,
      accessToken: access,
      refreshToken: result.refreshToken,
      expiresAt: result.accessTokenExpirationDateTime,
    );
  }

  Future<void> disconnect() => _tokens.clear(_kind);

  Future<String> _accessToken() async {
    final existing = await _tokens.readAccessToken(_kind);
    final expiry = await _tokens.readExpiry(_kind);
    final refresh = await _tokens.readRefreshToken(_kind);
    final stillValid =
        existing != null &&
        existing.isNotEmpty &&
        (expiry == null ||
            expiry.isAfter(DateTime.now().add(const Duration(minutes: 2))));
    if (stillValid) return existing;

    if (refresh == null || refresh.isEmpty) {
      throw const CloudAuthException('Dropbox session expired');
    }
    final result = await _appAuth.token(
      TokenRequest(
        CloudOAuthConfig.dropboxClientId,
        CloudOAuthConfig.dropboxRedirectUri,
        refreshToken: refresh,
        serviceConfiguration: const AuthorizationServiceConfiguration(
          authorizationEndpoint: _authEndpoint,
          tokenEndpoint: _tokenEndpoint,
        ),
      ),
    );
    final access = result.accessToken;
    if (access == null || access.isEmpty) {
      throw const CloudAuthException('Could not refresh Dropbox token');
    }
    await _tokens.writeSession(
      kind: _kind,
      accessToken: access,
      refreshToken: result.refreshToken ?? refresh,
      expiresAt: result.accessTokenExpirationDateTime,
    );
    return access;
  }

  Future<List<CloudEntry>> list({
    String? folderPath,
    ScoreFileFilter filter = ScoreFileFilter.pdf,
  }) async {
    final token = await _accessToken();
    final path = folderPath ?? '';
    final response = await _http.post(
      Uri.parse('https://api.dropboxapi.com/2/files/list_folder'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'path': path,
        'recursive': false,
        'include_media_info': false,
        'include_deleted': false,
      }),
    );
    if (response.statusCode >= 400) {
      throw CloudAuthException('Dropbox list failed (${response.statusCode})');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final entriesJson = (json['entries'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final entries = <CloudEntry>[];
    for (final item in entriesJson) {
      final tag = item['.tag'] as String?;
      final name = item['name'] as String?;
      final id = item['id'] as String?;
      final pathDisplay = item['path_display'] as String?;
      if (name == null || id == null) continue;
      final isFolder = tag == 'folder';
      if (!isFolder && !matchesScoreFileName(name, filter)) continue;
      entries.add(
        CloudEntry(
          id: id,
          name: name,
          isFolder: isFolder,
          path: pathDisplay,
          size: (item['size'] as num?)?.toInt(),
        ),
      );
    }
    entries.sort((a, b) {
      if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  Future<PickedLocalFile> download(CloudEntry entry) async {
    if (entry.isFolder) {
      throw const CloudAuthException('Cannot download a folder');
    }
    final token = await _accessToken();
    // Prefer id:… so Dropbox-API-Arg stays ASCII (path_display can break headers).
    final apiPath = entry.id.startsWith('id:')
        ? entry.id
        : (entry.path ?? entry.id);
    final response = await _http.post(
      Uri.parse('https://content.dropboxapi.com/2/files/download'),
      headers: {
        'Authorization': 'Bearer $token',
        'Dropbox-API-Arg': jsonEncode({'path': apiPath}),
      },
    );
    if (response.statusCode >= 400) {
      throw CloudAuthException(
        'Dropbox download failed (${response.statusCode})',
      );
    }
    if (response.bodyBytes.isEmpty) {
      throw const CloudAuthException('Dropbox download returned empty file');
    }
    return PickedLocalFile(name: entry.name, bytes: response.bodyBytes);
  }
}
