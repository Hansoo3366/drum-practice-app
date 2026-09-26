import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/features/library/domain/picked_local_file.dart';

abstract interface class OmrSourcePicker {
  Future<PickedLocalFile?> pick();
}

class FilePickerOmrSourcePicker implements OmrSourcePicker {
  const FilePickerOmrSourcePicker();

  @override
  Future<PickedLocalFile?> pick() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null) return null;
    final file = result.files.single;
    if (file.path case final filePath?) {
      return PickedLocalFile(
        name: file.name,
        path: filePath,
        bytes: file.bytes,
      );
    }
    return PickedLocalFile(
      name: file.name,
      bytes: file.bytes ?? await file.xFile.readAsBytes(),
    );
  }
}

final omrSourcePickerProvider = Provider<OmrSourcePicker>((ref) {
  return const FilePickerOmrSourcePicker();
});
