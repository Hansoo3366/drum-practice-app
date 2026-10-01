import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/features/library/data/image_pdf.dart';
import 'package:page_a_diddle/features/library/data/pdf_picker.dart';
import 'package:page_a_diddle/features/library/domain/picked_local_file.dart';

abstract interface class OmrSourcePicker {
  Future<PickedLocalFile?> pick();
}

/// Picks a PDF or score images for conversion. Images become one PDF so a
/// song photographed over several pages converts as one score and the
/// source comparison screen can crop it like any PDF.
class FilePickerOmrSourcePicker implements OmrSourcePicker {
  const FilePickerOmrSourcePicker();

  @override
  Future<PickedLocalFile?> pick() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = await combinePickedScore([
      for (final file in result.files) await pickedLocalFile(file),
    ], read: readPickedFile);
    return PickedLocalFile(
      name: picked.name,
      path: picked.path,
      bytes: picked.bytes ?? await readPickedFile(picked),
    );
  }
}

final omrSourcePickerProvider = Provider<OmrSourcePicker>((ref) {
  return const FilePickerOmrSourcePicker();
});
