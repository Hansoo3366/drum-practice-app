import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/library/data/image_pdf.dart';
import 'package:page_a_diddle/features/library/domain/picked_local_file.dart';

/// A 2×3 white PNG.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x03,
  0x08, 0x02, 0x00, 0x00, 0x00, 0x36, 0x88, 0x49, 0xD6, 0x00, 0x00, 0x00,
  0x0E, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0x0F, 0x06, 0x0C,
  0x28, 0x14, 0x00, 0xBC, 0x58, 0x11, 0xEF, 0x53, 0xC9, 0xFE, 0xB8, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

int _pageCount(Uint8List pdf) =>
    RegExp(r'/Type\s*/Page(?!s)').allMatches(String.fromCharCodes(pdf)).length;

void main() {
  test('combines images into one PDF, a page per image', () async {
    final pdf = await imagesToPdf([
      (name: 'song_01.png', bytes: _png),
      (name: 'song.png', bytes: _png),
    ]);

    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    expect(_pageCount(pdf), 2);
    // Page height follows the 2:3 image instead of an A4 letterbox.
    expect(String.fromCharCodes(pdf), contains('/MediaBox[0 0 595 892.5]'));
  });

  test('keeps a single PDF and names combined images after page one', () async {
    const pdf = PickedLocalFile(name: 'a.pdf', path: '/tmp/a.pdf');
    expect(await combinePickedScore([pdf], read: (_) async => _png), pdf);

    final combined = await combinePickedScore([
      PickedLocalFile(name: 'Song_02.PNG', bytes: _png),
      PickedLocalFile(name: 'Song.png', bytes: _png),
      PickedLocalFile(name: 'Song_01.png', bytes: _png),
    ], read: (file) async => file.bytes!);
    expect(combined.name, 'Song.pdf');
    expect(_pageCount(combined.bytes!), 3);
  });

  test('refuses PDFs mixed with images or several PDFs', () {
    expect(
      combinePickedScore([
        const PickedLocalFile(name: 'a.pdf', path: '/tmp/a.pdf'),
        PickedLocalFile(name: 'b.png', bytes: _png),
      ], read: (_) async => _png),
      throwsFormatException,
    );
    expect(
      combinePickedScore(const [
        PickedLocalFile(name: 'a.pdf', path: '/tmp/a.pdf'),
        PickedLocalFile(name: 'b.pdf', path: '/tmp/b.pdf'),
      ], read: (_) async => _png),
      throwsFormatException,
    );
  });

  final sample = Directory('score_sample');
  test(
    'converts the sample phone photos',
    () async {
      final photos = sample
          .listSync()
          .whereType<File>()
          .where((file) => file.path.contains('20260927_203558861'))
          .toList();
      final pdf = await imagesToPdf([
        for (final photo in photos)
          (name: photo.uri.pathSegments.last, bytes: photo.readAsBytesSync()),
      ]);
      expect(_pageCount(pdf), photos.length);
      final out = Platform.environment['IMAGE_PDF_OUT'];
      if (out != null) File(out).writeAsBytesSync(pdf);
    },
    skip: sample.existsSync() ? false : 'score_sample is not checked in',
  );
}
