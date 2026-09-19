import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/features/library/domain/picked_local_file.dart';

abstract interface class AudioPicker {
  Future<PickedLocalFile?> pick();
}

class FilePickerAudioPicker implements AudioPicker {
  const FilePickerAudioPicker();

  @override
  Future<PickedLocalFile?> pick() async {
    final result = await FilePicker.pickFiles(
      type: FileType.audio,
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

final audioPickerProvider = Provider<AudioPicker>((ref) {
  return const FilePickerAudioPicker();
});
