import 'dart:typed_data';

import 'package:page_a_diddle/features/library/domain/picked_local_file.dart';
import 'package:path/path.dart' as path;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const scoreImageExtensions = {'.jpg', '.jpeg', '.png'};

bool isScoreImage(String name) =>
    scoreImageExtensions.contains(path.extension(name).toLowerCase());

/// Width of each generated page in points (A4 width). The height follows
/// the photo so a page is never letterboxed.
const _pageWidth = 595.0;

/// Combines photographed or scanned score pages into one PDF, a page per
/// image, so the viewer, conversion and source comparison all read a PDF.
///
/// Images are ordered by file name (`page.jpg`, `page_01.jpg`, ...), the way
/// messengers and scanners number multi-page exports. Phone photos keep the
/// rotation stored in their EXIF data.
Future<Uint8List> imagesToPdf(List<({String name, Uint8List bytes})> images) {
  if (images.isEmpty) {
    throw const FormatException('악보 이미지를 선택하세요.');
  }
  final ordered = images.toList()
    ..sort((a, b) => _pageSortKey(a.name).compareTo(_pageSortKey(b.name)));
  final document = pw.Document(compress: true);
  for (final image in ordered) {
    final pw.MemoryImage picture;
    try {
      picture = pw.MemoryImage(image.bytes);
    } on Object {
      throw FormatException('${image.name} 이미지를 읽을 수 없습니다.');
    }
    final width = picture.width;
    final height = picture.height;
    if (width == null || height == null || width <= 0 || height <= 0) {
      throw FormatException('${image.name} 이미지를 읽을 수 없습니다.');
    }
    // EXIF orientations 5-8 turn the photo a quarter turn.
    final turned = picture.orientation.index >= 4;
    final aspect = turned ? width / height : height / width;
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(_pageWidth, _pageWidth * aspect),
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(picture, fit: pw.BoxFit.fill),
      ),
    );
  }
  return document.save();
}

/// "song.jpg" sorts before "song_01.jpg", and "_2" before "_10".
String _pageSortKey(String name) {
  final base = path.basenameWithoutExtension(name).toLowerCase();
  return base
      .replaceAllMapped(
        RegExp(r'\d+'),
        (match) => match.group(0)!.padLeft(8, '0'),
      )
      .replaceAll('_', '~');
}

/// Turns picked files into one file for import: a single PDF as-is, or
/// images combined into a PDF named after the first image.
Future<PickedLocalFile> combinePickedScore(
  List<PickedLocalFile> files, {
  required Future<Uint8List> Function(PickedLocalFile file) read,
}) async {
  if (files.isEmpty) throw const FormatException('악보 파일을 선택하세요.');
  final images = files.where((file) => isScoreImage(file.name)).toList();
  if (images.isEmpty) {
    if (files.length > 1) {
      throw const FormatException('PDF는 한 번에 하나만 가져올 수 있습니다.');
    }
    return files.single;
  }
  if (images.length != files.length) {
    throw const FormatException('PDF와 이미지는 함께 가져올 수 없습니다.');
  }
  final pages = [
    for (final image in images) (name: image.name, bytes: await read(image)),
  ];
  final first =
      (pages.toList()..sort(
            (a, b) => _pageSortKey(a.name).compareTo(_pageSortKey(b.name)),
          ))
          .first;
  return PickedLocalFile(
    name: '${path.basenameWithoutExtension(first.name)}.pdf',
    bytes: await imagesToPdf(pages),
  );
}
