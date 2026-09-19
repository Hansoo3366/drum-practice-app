import 'dart:io';

import 'package:flutter/services.dart';

class AlphaTabAssetServer {
  HttpServer? _server;

  int? get port => _server?.port;

  Future<Uri> ensureStarted() async {
    final existing = _server;
    if (existing != null) {
      return Uri.parse('http://127.0.0.1:${existing.port}/index.html');
    }
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(_handle);
    return Uri.parse('http://127.0.0.1:${server.port}/index.html');
  }

  Future<void> close() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      if (request.method == 'OPTIONS') {
        _cors(response);
        response.statusCode = HttpStatus.noContent;
        return;
      }
      final asset = alphatabAssetKey(request.uri.path);
      if (asset == null) {
        response.statusCode = HttpStatus.forbidden;
        return;
      }
      final data = await rootBundle.load(asset);
      final bytes = data.buffer.asUint8List();
      _cors(response);
      response.statusCode = HttpStatus.ok;
      response.headers.contentType = ContentType.parse(alphatabMimeType(asset));
      response.headers.contentLength = bytes.length;
      response.add(bytes);
    } on Object {
      response.statusCode = HttpStatus.notFound;
    } finally {
      await response.close();
    }
  }
}

void _cors(HttpResponse response) {
  response.headers.set('Access-Control-Allow-Origin', '*');
  response.headers.set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
}

String? alphatabAssetKey(String requestPath) {
  var path = Uri.decodeComponent(requestPath);
  if (path.startsWith('/')) path = path.substring(1);
  if (path.isEmpty) path = 'index.html';
  final segments = path
      .split('/')
      .where((segment) => segment.isNotEmpty && segment != '.')
      .toList();
  if (segments.isEmpty || segments.contains('..')) return null;
  return 'assets/alphatab/${segments.join('/')}';
}

String alphatabMimeType(String assetKey) {
  final name = assetKey.toLowerCase();
  if (name.endsWith('.html')) return 'text/html; charset=utf-8';
  if (name.endsWith('.js')) return 'text/javascript; charset=utf-8';
  if (name.endsWith('.css')) return 'text/css; charset=utf-8';
  if (name.endsWith('.json')) return 'application/json; charset=utf-8';
  if (name.endsWith('.svg')) return 'image/svg+xml';
  if (name.endsWith('.woff2')) return 'font/woff2';
  if (name.endsWith('.woff')) return 'font/woff';
  if (name.endsWith('.otf')) return 'font/otf';
  if (name.endsWith('.ttf')) return 'font/ttf';
  if (name.endsWith('.sf2')) return 'application/octet-stream';
  return 'application/octet-stream';
}
