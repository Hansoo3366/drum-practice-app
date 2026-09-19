import 'dart:typed_data';

class PickedLocalFile {
  const PickedLocalFile({required this.name, this.path, this.bytes})
    : assert(path != null || bytes != null, '파일 경로나 데이터가 필요합니다.');

  final String name;
  final String? path;
  final Uint8List? bytes;
}
