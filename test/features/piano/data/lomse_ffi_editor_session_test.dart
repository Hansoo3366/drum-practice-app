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

    // The checked-in Flutter build does not package Lomse yet. Once the piano
    // flavor links it, this assertion remains valid because the session may
    // be created successfully instead.
    expect(session == null || session.revision == 0, isTrue);
    session?.dispose();
  });
}
