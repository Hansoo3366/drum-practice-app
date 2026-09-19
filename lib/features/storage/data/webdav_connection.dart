import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:xml/xml.dart';

class WebDavCredentials {
  const WebDavCredentials({
    required this.url,
    required this.username,
    required this.password,
  });

  final String url;
  final String username;
  final String password;
}

class WebDavConnectionException implements Exception {
  const WebDavConnectionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WebDavResponse {
  const WebDavResponse(this.statusCode, [this.body = '']);

  final int statusCode;
  final String body;
}

class WebDavEntry {
  const WebDavEntry({
    required this.name,
    required this.uri,
    required this.isDirectory,
    this.size,
    this.modifiedAt,
  });

  final String name;
  final Uri uri;
  final bool isDirectory;
  final int? size;
  final DateTime? modifiedAt;
}

class WebDavDownloadResult {
  const WebDavDownloadResult({required this.bytes, this.modifiedAt});

  final Uint8List bytes;
  final DateTime? modifiedAt;
}

typedef WebDavRequest =
    Future<WebDavResponse> Function(
      Uri uri,
      String username,
      String password,
      int depth,
    );

typedef WebDavDownload =
    Future<WebDavDownloadResult> Function(
      Uri uri,
      String username,
      String password,
    );

class WebDavConnection {
  WebDavConnection({WebDavRequest? request, WebDavDownload? download})
    : _request = request ?? _requestServer,
      _download = download ?? _downloadFile;

  final WebDavRequest _request;
  final WebDavDownload _download;

  Future<void> test(WebDavCredentials credentials) async {
    final uri = Uri.tryParse(credentials.url.trim());
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        uri.scheme != 'https') {
      throw const WebDavConnectionException('주소를 확인하세요.');
    }

    final response = await _request(
      uri,
      credentials.username.trim(),
      credentials.password,
      0,
    );
    _throwForStatus(response.statusCode);
  }

  Future<List<WebDavEntry>> list(
    WebDavCredentials credentials,
    Uri directory,
  ) async {
    final base = directory.path.endsWith('/')
        ? directory
        : directory.replace(path: '${directory.path}/');
    final response = await _request(
      base,
      credentials.username.trim(),
      credentials.password,
      1,
    );
    _throwForStatus(response.statusCode);

    try {
      final document = XmlDocument.parse(response.body);
      final entries = <WebDavEntry>[];
      for (final node in _elementsNamed(document, 'response')) {
        final href = _elementText(node, 'href');
        if (href == null) continue;

        final uri = base.resolve(href);
        if (!_sameOrigin(base, uri) ||
            _normalizedPath(uri) == _normalizedPath(base)) {
          continue;
        }

        final isDirectory = _elementsNamed(node, 'collection').isNotEmpty;
        final name =
            _elementText(node, 'displayname') ??
            (uri.pathSegments.where((part) => part.isNotEmpty).lastOrNull ??
                uri.host);
        if (!isDirectory && !name.toLowerCase().endsWith('.pdf')) continue;

        entries.add(
          WebDavEntry(
            name: name,
            uri: uri,
            isDirectory: isDirectory,
            size: int.tryParse(_elementText(node, 'getcontentlength') ?? ''),
            modifiedAt: _parseHttpDate(_elementText(node, 'getlastmodified')),
          ),
        );
      }
      entries.sort((a, b) {
        if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return entries;
    } on XmlParserException {
      throw const WebDavConnectionException('서버 응답을 읽을 수 없습니다.');
    }
  }

  Future<WebDavDownloadResult> downloadPdf(
    WebDavCredentials credentials,
    Uri uri,
  ) async {
    final root = Uri.tryParse(credentials.url.trim());
    if (root == null ||
        uri.scheme != 'https' ||
        !_sameOrigin(root, uri) ||
        !uri.path.toLowerCase().endsWith('.pdf')) {
      throw const WebDavConnectionException('파일 주소를 확인하세요.');
    }
    return _download(uri, credentials.username.trim(), credentials.password);
  }

  static void _throwForStatus(int status) {
    switch (status) {
      case 200:
      case 207:
        return;
      case 401:
        throw const WebDavConnectionException('계정 정보를 확인하세요.');
      case 403:
        throw const WebDavConnectionException('접근 권한이 없습니다.');
      case 404:
        throw const WebDavConnectionException('주소를 확인하세요.');
      default:
        throw WebDavConnectionException('연결 실패 ($status)');
    }
  }

  static String? _elementText(XmlElement node, String name) {
    for (final element in _elementsNamed(node, name)) {
      final value = element.innerText.trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  static Iterable<XmlElement> _elementsNamed(XmlNode node, String name) {
    return node.descendants.whereType<XmlElement>().where(
      (element) => element.name.local == name,
    );
  }

  static bool _sameOrigin(Uri a, Uri b) {
    return a.scheme == b.scheme && a.host == b.host && a.port == b.port;
  }

  static String _normalizedPath(Uri uri) {
    final path = uri.path.endsWith('/') && uri.path.length > 1
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;
    return path;
  }

  static DateTime? _parseHttpDate(String? value) {
    if (value == null) return null;
    try {
      return HttpDate.parse(value);
    } on FormatException {
      return null;
    }
  }

  static Future<WebDavResponse> _requestServer(
    Uri uri,
    String username,
    String password,
    int depth,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client
          .openUrl('PROPFIND', uri)
          .timeout(const Duration(seconds: 10));
      request.headers.set('Depth', '$depth');
      if (username.isNotEmpty) {
        final token = base64Encode(utf8.encode('$username:$password'));
        request.headers.set(HttpHeaders.authorizationHeader, 'Basic $token');
      }
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      final body = await response.transform(utf8.decoder).join();
      return WebDavResponse(response.statusCode, body);
    } on TimeoutException {
      throw const WebDavConnectionException('서버 응답이 없습니다.');
    } on HandshakeException {
      throw const WebDavConnectionException('보안 연결을 확인하세요.');
    } on SocketException {
      throw const WebDavConnectionException('서버에 연결할 수 없습니다.');
    } finally {
      client.close(force: true);
    }
  }

  static Future<WebDavDownloadResult> _downloadFile(
    Uri uri,
    String username,
    String password,
  ) async {
    const maxBytes = 100 * 1024 * 1024;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 10));
      request.followRedirects = false;
      if (username.isNotEmpty) {
        final token = base64Encode(utf8.encode('$username:$password'));
        request.headers.set(HttpHeaders.authorizationHeader, 'Basic $token');
      }
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode != 200) {
        switch (response.statusCode) {
          case 401:
            throw const WebDavConnectionException('계정 정보를 확인하세요.');
          case 403:
            throw const WebDavConnectionException('접근 권한이 없습니다.');
          case 404:
            throw const WebDavConnectionException('파일이 없습니다.');
          default:
            throw WebDavConnectionException('다운로드 실패 (${response.statusCode})');
        }
      }
      if (response.contentLength > maxBytes) {
        throw const WebDavConnectionException('PDF가 너무 큽니다.');
      }

      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        bytes.add(chunk);
        if (bytes.length > maxBytes) {
          throw const WebDavConnectionException('PDF가 너무 큽니다.');
        }
      }
      return WebDavDownloadResult(
        bytes: bytes.takeBytes(),
        modifiedAt: _parseHttpDate(
          response.headers.value(HttpHeaders.lastModifiedHeader),
        ),
      );
    } on TimeoutException {
      throw const WebDavConnectionException('서버 응답이 없습니다.');
    } on HandshakeException {
      throw const WebDavConnectionException('보안 연결을 확인하세요.');
    } on SocketException {
      throw const WebDavConnectionException('서버에 연결할 수 없습니다.');
    } finally {
      client.close(force: true);
    }
  }
}

class WebDavSettingsStore {
  const WebDavSettingsStore(this._storage);

  static const _urlKey = 'webdav.url';
  static const _usernameKey = 'webdav.username';
  static const _passwordKey = 'webdav.password';

  final FlutterSecureStorage _storage;

  Future<WebDavCredentials?> read() async {
    final url = await _storage.read(key: _urlKey);
    if (url == null) return null;

    return WebDavCredentials(
      url: url,
      username: await _storage.read(key: _usernameKey) ?? '',
      password: await _storage.read(key: _passwordKey) ?? '',
    );
  }

  Future<void> write(WebDavCredentials credentials) async {
    await _storage.write(key: _urlKey, value: credentials.url.trim());
    await _storage.write(key: _usernameKey, value: credentials.username.trim());
    await _storage.write(key: _passwordKey, value: credentials.password);
  }

  Future<void> clear() async {
    await _storage.delete(key: _urlKey);
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _passwordKey);
  }
}

final webDavConnectionProvider = Provider<WebDavConnection>((ref) {
  return WebDavConnection();
});

final webDavSettingsStoreProvider = Provider<WebDavSettingsStore>((ref) {
  return const WebDavSettingsStore(FlutterSecureStorage());
});
