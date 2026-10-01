import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The General MIDI SoundFont scores are played with.
const scoreSoundFontAsset = 'assets/soundfont/GeneralUser-GS.sf2';

/// The file is named by its version: a new SoundFont is copied out again.
const _fileName = 'GeneralUser-GS-2.0.3.sf2';

Future<String>? _path;

/// Path of the SoundFont on disk, where the native synthesizer can read it,
/// or an empty string when the app has none (the drum flavor, a test).
///
/// The first call copies the bundled file out of the assets.
Future<String> scoreSoundFontPath() => _path ??= _copyOut();

Future<String> _copyOut() async {
  try {
    final directory = Directory(
      p.join((await getApplicationSupportDirectory()).path, 'soundfont'),
    );
    final file = File(p.join(directory.path, _fileName));
    if (file.existsSync() && file.lengthSync() > 0) return file.path;
    final data = await rootBundle.load(scoreSoundFontAsset);
    await directory.create(recursive: true);
    // Written under another name first: a copy cut short is never read.
    final partial = File('${file.path}.part');
    await partial.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    await partial.rename(file.path);
    // Earlier versions are no longer needed.
    for (final other in directory.listSync().whereType<File>()) {
      if (other.path != file.path) other.deleteSync();
    }
    return file.path;
  } on Object {
    // No bundled SoundFont, or no place to copy it to: plain waveforms.
    _path = null;
    return '';
  }
}
