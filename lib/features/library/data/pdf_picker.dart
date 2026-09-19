import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/features/library/domain/picked_local_file.dart';

abstract interface class PdfPicker {
  Future<PickedLocalFile?> pick();
}

class FilePickerPdfPicker implements PdfPicker {
  const FilePickerPdfPicker();

  @override
  Future<PickedLocalFile?> pick() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: false,
      withData: false,
    );

    if (result == null) {
      return null;
    }

    final file = result.files.single;
    if (file.path case final filePath?) {
      return PickedLocalFile(name: file.name, path: filePath);
    }

    return PickedLocalFile(
      name: file.name,
      bytes: file.bytes ?? await file.xFile.readAsBytes(),
    );
  }
}

final pdfPickerProvider = Provider<PdfPicker>((ref) {
  return const FilePickerPdfPicker();
});
