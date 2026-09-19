import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/features/library/domain/picked_local_file.dart';

abstract interface class MusicXmlPicker {
  Future<PickedLocalFile?> pick();
}

class FilePickerMusicXmlPicker implements MusicXmlPicker {
  const FilePickerMusicXmlPicker();

  @override
  Future<PickedLocalFile?> pick() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['musicxml', 'mxl', 'xml'],
      allowMultiple: false,
      withData: false,
    );
    if (result == null) return null;

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

final musicXmlPickerProvider = Provider<MusicXmlPicker>((ref) {
  return const FilePickerMusicXmlPicker();
});
