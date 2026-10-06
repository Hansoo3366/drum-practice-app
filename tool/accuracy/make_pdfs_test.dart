// Builds each sample song's PDF exactly as the app does when pictures are picked for
// conversion (`imagesToPdf`), into score_sample/_accuracy/pdf/.
//
//   flutter test tool/accuracy/make_pdfs_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/library/data/image_pdf.dart';

void main() {
  test('make the sample PDFs as the app does', () async {
    final songs =
        jsonDecode(File('tool/accuracy/songs.json').readAsStringSync())
            as Map<String, dynamic>;
    final out = Directory('score_sample/_accuracy/pdf')
      ..createSync(recursive: true);
    for (final entry in songs.entries) {
      final pages = [
        for (final name in (entry.value as List).cast<String>())
          (name: name, bytes: File('score_sample/$name').readAsBytesSync()),
      ];
      File('${out.path}/${entry.key}.pdf').writeAsBytesSync(
        await imagesToPdf(pages),
      );
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
