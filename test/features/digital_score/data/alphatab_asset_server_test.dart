import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/alphatab_asset_server.dart';

void main() {
  test('maps renderer paths and rejects traversal', () {
    expect(alphatabAssetKey('/'), 'assets/alphatab/index.html');
    expect(
      alphatabAssetKey('/vendor/alphaTab.min.js'),
      'assets/alphatab/vendor/alphaTab.min.js',
    );
    expect(
      alphatabAssetKey('/vendor/soundfont/ydp-grand-piano.sf2'),
      'assets/alphatab/vendor/soundfont/ydp-grand-piano.sf2',
    );
    expect(alphatabAssetKey('/../pubspec.yaml'), isNull);
    expect(alphatabAssetKey('/vendor/../../secret'), isNull);
  });

  test('uses script and soundfont MIME types the WebView worker can fetch', () {
    expect(
      alphatabMimeType('assets/alphatab/vendor/alphaTab.min.js'),
      'text/javascript; charset=utf-8',
    );
    expect(
      alphatabMimeType('assets/alphatab/vendor/soundfont/ydp-grand-piano.sf2'),
      'application/octet-stream',
    );
    expect(
      alphatabMimeType('assets/alphatab/vendor/font/Bravura.woff2'),
      'font/woff2',
    );
  });
}
