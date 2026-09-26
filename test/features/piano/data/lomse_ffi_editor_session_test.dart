import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/piano/data/lomse_ffi_editor_session.dart';

void main() {
  test('maps native bridge status codes', () {
    expect(LomseBridgeStatus.fromCode(0), LomseBridgeStatus.ok);
    expect(LomseBridgeStatus.fromCode(7), LomseBridgeStatus.unsupportedCommand);
    expect(LomseBridgeStatus.fromCode(999), LomseBridgeStatus.unknown);
  });

  test('formats native bridge failures with status and message', () {
    const error = LomseBridgeException(
      LomseBridgeStatus.parseError,
      'MusicXML is invalid.',
    );

    expect(error.toString(), contains('parseError'));
    expect(error.toString(), contains('MusicXML is invalid.'));
  });

  test('does not require the optional bridge library in fallback builds', () {
    final session = FfiLomseEditorSession.tryCreate();

    // Host-side Flutter tests do not load the Android piano JNI artifact.
    // The Android piano flavor links it and is covered by the emulator smoke.
    expect(session == null || session.revision == 0, isTrue);
    session?.dispose();
  });
}
