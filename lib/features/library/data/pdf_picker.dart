import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/features/library/data/image_pdf.dart';
import 'package:page_a_diddle/features/library/domain/picked_local_file.dart';

abstract interface class PdfPicker {
  Future<PickedLocalFile?> pick();
}

/// Picks one PDF, or one or more score images (JPG/PNG) that are combined
/// into a PDF, a page per image.
class FilePickerPdfPicker implements PdfPicker {
  const FilePickerPdfPicker();

  @override
  Future<PickedLocalFile?> pick() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: true,
      withData: false,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }
    return combinePickedScore([
      for (final file in result.files) await pickedLocalFile(file),
    ], read: readPickedFile);
  }
}

Future<PickedLocalFile> pickedLocalFile(PlatformFile file) async {
  if (file.path case final filePath?) {
    return PickedLocalFile(name: file.name, path: filePath, bytes: file.bytes);
  }
  return PickedLocalFile(
    name: file.name,
    bytes: file.bytes ?? await file.xFile.readAsBytes(),
  );
}

Future<Uint8List> readPickedFile(PickedLocalFile file) async {
  if (file.bytes case final bytes?) return bytes;
  return File(file.path!).readAsBytes();
}

final pdfPickerProvider = Provider<PdfPicker>((ref) {
  return const FilePickerPdfPicker();
});
