import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:page_a_diddle/features/piano/domain/lomse_editor_contract.dart';

const int _expectedAbiVersion = 1;

/// Native status values from `page_lomse_bridge.h`.
enum LomseBridgeStatus {
  ok(0),
  invalidArgument(1),
  notLoaded(2),
  parseError(3),
  editError(4),
  noHistory(5),
  internalError(6),
  unsupportedCommand(7),
  unknown(-1);

  const LomseBridgeStatus(this.code);

  final int code;

  static LomseBridgeStatus fromCode(int code) {
    for (final status in values) {
      if (status.code == code) return status;
    }
    return unknown;
  }
}

class LomseBridgeException implements Exception {
  const LomseBridgeException(this.status, this.message);

  final LomseBridgeStatus status;
  final String message;

  @override
  String toString() => 'LomseBridgeException(${status.name}): $message';
}

/// Lazy loader for the piano-only native bridge.
///
/// The library is intentionally opened only when the piano editor asks for
/// the Lomse session. This keeps the drum flavor independent from the native
/// Lomse dependency while keeping the piano editor's native boundary small.
class LomseFfiBridge {
  LomseFfiBridge._(this.library)
    : _abiVersion = library.lookupFunction<_AbiVersionNative, _AbiVersionDart>(
        'page_lomse_bridge_abi_version',
      ),
      _create = library.lookupFunction<_CreateNative, _CreateDart>(
        'page_lomse_session_create',
      ),
      _loadMusicXml = library
          .lookupFunction<_LoadMusicXmlNative, _LoadMusicXmlDart>(
            'page_lomse_session_load_musicxml',
          ),
      _executeJson = library
          .lookupFunction<_ExecuteJsonNative, _ExecuteJsonDart>(
            'page_lomse_session_execute_json',
          ),
      _undo = library.lookupFunction<_HistoryNative, _HistoryDart>(
        'page_lomse_session_undo',
      ),
      _redo = library.lookupFunction<_HistoryNative, _HistoryDart>(
        'page_lomse_session_redo',
      ),
      _exportMusicXml = library
          .lookupFunction<_ExportMusicXmlNative, _ExportMusicXmlDart>(
            'page_lomse_session_export_musicxml',
          ),
      _lastError = library.lookupFunction<_LastErrorNative, _LastErrorDart>(
        'page_lomse_session_last_error',
      ),
      _bufferFree = library.lookupFunction<_BufferFreeNative, _BufferFreeDart>(
        'page_lomse_buffer_free',
      ),
      _dispose = library.lookupFunction<_DisposeNative, _DisposeDart>(
        'page_lomse_session_dispose',
      ) {
    final abiVersion = _abiVersion();
    if (abiVersion != _expectedAbiVersion) {
      throw StateError(
        'Unsupported Lomse bridge ABI version: $abiVersion '
        '(expected $_expectedAbiVersion).',
      );
    }
  }

  final DynamicLibrary library;

  final _AbiVersionDart _abiVersion;
  final _CreateDart _create;
  final _LoadMusicXmlDart _loadMusicXml;
  final _ExecuteJsonDart _executeJson;
  final _HistoryDart _undo;
  final _HistoryDart _redo;
  final _ExportMusicXmlDart _exportMusicXml;
  final _LastErrorDart _lastError;
  final _BufferFreeDart _bufferFree;
  final _DisposeDart _dispose;

  /// Names are ordered by the artifact produced by the Android/macOS CMake
  /// target. The optional bare name helps host-side smoke tools.
  static List<String> get candidateLibraryNames {
    if (Platform.isAndroid) return const ['libpage_lomse_bridge.so'];
    if (Platform.isMacOS) {
      return const [
        'libpage_lomse_bridge.dylib',
        'page_lomse_bridge.dylib',
        'libpage_lomse_bridge.so',
      ];
    }
    return const ['libpage_lomse_bridge.so', 'page_lomse_bridge'];
  }

  static LomseFfiBridge? tryOpen({DynamicLibrary? library}) {
    if (library != null) return LomseFfiBridge._(library);
    for (final name in candidateLibraryNames) {
      try {
        return LomseFfiBridge._(DynamicLibrary.open(name));
      } on Object {
        // The next candidate may be the platform-specific spelling.
      }
    }
    return null;
  }

  Pointer<Void> createSession() => _create();

  int loadMusicXml(
    Pointer<Void> session,
    Pointer<Uint8> musicXml,
    int musicXmlSize,
    Pointer<Uint64> outRevision,
  ) => _loadMusicXml(session, musicXml, musicXmlSize, outRevision);

  int executeJson(
    Pointer<Void> session,
    Pointer<Uint8> commandJson,
    int commandJsonSize,
    Pointer<Uint64> outRevision,
  ) => _executeJson(session, commandJson, commandJsonSize, outRevision);

  int undo(Pointer<Void> session, Pointer<Uint64> outRevision) =>
      _undo(session, outRevision);

  int redo(Pointer<Void> session, Pointer<Uint64> outRevision) =>
      _redo(session, outRevision);

  int exportMusicXml(
    Pointer<Void> session,
    Pointer<Pointer<Uint8>> outMusicXml,
    Pointer<IntPtr> outMusicXmlSize,
    Pointer<Uint64> outRevision,
  ) => _exportMusicXml(session, outMusicXml, outMusicXmlSize, outRevision);

  String lastError(Pointer<Void> session) {
    final error = _lastError(session);
    if (error == nullptr) return '';
    return error.toDartString();
  }

  void bufferFree(Pointer<Uint8> buffer) => _bufferFree(buffer.cast<Void>());

  void dispose(Pointer<Void> session) => _dispose(session);
}

/// Dart implementation of the piano Lomse editor session contract.
///
/// This class is usable only when `libpage_lomse_bridge` is packaged with the
/// piano flavor. `tryCreate` returns null when the piano artifact is missing
/// or cannot be opened, allowing the screen to show a recoverable error.
class FfiLomseEditorSession implements LomseEditorSession {
  FfiLomseEditorSession._(this._bridge, this._handle);

  static FfiLomseEditorSession? tryCreate({LomseFfiBridge? bridge}) {
    final resolvedBridge = bridge ?? LomseFfiBridge.tryOpen();
    if (resolvedBridge == null) return null;
    try {
      final handle = resolvedBridge.createSession();
      if (handle == nullptr) return null;
      return FfiLomseEditorSession._(resolvedBridge, handle);
    } on Object {
      return null;
    }
  }

  final LomseFfiBridge _bridge;
  Pointer<Void> _handle;
  int _revision = 0;

  @override
  int get revision => _revision;

  @override
  Future<void> loadMusicXml(String musicXml) => Future<void>.sync(() {
    _ensureOpen();
    _withUtf8(musicXml, (bytes, size) {
      final outRevision = calloc<Uint64>();
      try {
        final status = _bridge.loadMusicXml(_handle, bytes, size, outRevision);
        _complete(status, outRevision.value);
      } finally {
        calloc.free(outRevision);
      }
    });
  });

  @override
  Future<void> execute(LomseEditRequest request) => Future<void>.sync(() {
    _ensureOpen();
    final command = jsonEncode(request.toJson());
    _withUtf8(command, (bytes, size) {
      final outRevision = calloc<Uint64>();
      try {
        final status = _bridge.executeJson(_handle, bytes, size, outRevision);
        _complete(status, outRevision.value);
      } finally {
        calloc.free(outRevision);
      }
    });
  });

  @override
  Future<void> undo() => Future<void>.sync(() {
    _ensureOpen();
    _runHistory(_bridge.undo);
  });

  @override
  Future<void> redo() => Future<void>.sync(() {
    _ensureOpen();
    _runHistory(_bridge.redo);
  });

  @override
  Future<String> exportMusicXml() => Future<String>.sync(() {
    _ensureOpen();
    final outMusicXml = calloc<Pointer<Uint8>>();
    final outMusicXmlSize = calloc<IntPtr>();
    final outRevision = calloc<Uint64>();
    try {
      final status = _bridge.exportMusicXml(
        _handle,
        outMusicXml,
        outMusicXmlSize,
        outRevision,
      );
      _complete(status, outRevision.value);
      final buffer = outMusicXml.value;
      final size = outMusicXmlSize.value;
      if (buffer == nullptr || size < 0) {
        throw const LomseBridgeException(
          LomseBridgeStatus.internalError,
          'Lomse returned an invalid MusicXML buffer.',
        );
      }
      return utf8.decode(buffer.asTypedList(size));
    } finally {
      final buffer = outMusicXml.value;
      if (buffer != nullptr) _bridge.bufferFree(buffer);
      calloc.free(outMusicXml);
      calloc.free(outMusicXmlSize);
      calloc.free(outRevision);
    }
  });

  @override
  Future<void> dispose() => Future<void>.sync(() {
    if (_handle == nullptr) return;
    _bridge.dispose(_handle);
    _handle = nullptr;
  });

  void _runHistory(int Function(Pointer<Void>, Pointer<Uint64>) operation) {
    final outRevision = calloc<Uint64>();
    try {
      _complete(operation(_handle, outRevision), outRevision.value);
    } finally {
      calloc.free(outRevision);
    }
  }

  void _complete(int rawStatus, int revision) {
    final status = LomseBridgeStatus.fromCode(rawStatus);
    if (status != LomseBridgeStatus.ok) {
      final nativeMessage = _bridge.lastError(_handle);
      throw LomseBridgeException(
        status,
        nativeMessage.isEmpty ? 'Lomse operation failed.' : nativeMessage,
      );
    }
    _revision = revision;
  }

  void _ensureOpen() {
    if (_handle == nullptr) {
      throw StateError('The Lomse editor session is already disposed.');
    }
  }

  T _withUtf8<T>(String value, T Function(Pointer<Uint8>, int size) callback) {
    final encoded = utf8.encode(value);
    final bytes = calloc<Uint8>(encoded.length + 1);
    try {
      bytes.asTypedList(encoded.length).setAll(0, encoded);
      return callback(bytes, encoded.length);
    } finally {
      calloc.free(bytes);
    }
  }
}

typedef _AbiVersionNative = Uint32 Function();
typedef _AbiVersionDart = int Function();

typedef _CreateNative = Pointer<Void> Function();
typedef _CreateDart = Pointer<Void> Function();

typedef _LoadMusicXmlNative =
    Int32 Function(Pointer<Void>, Pointer<Uint8>, IntPtr, Pointer<Uint64>);
typedef _LoadMusicXmlDart =
    int Function(Pointer<Void>, Pointer<Uint8>, int, Pointer<Uint64>);

typedef _ExecuteJsonNative =
    Int32 Function(Pointer<Void>, Pointer<Uint8>, IntPtr, Pointer<Uint64>);
typedef _ExecuteJsonDart =
    int Function(Pointer<Void>, Pointer<Uint8>, int, Pointer<Uint64>);

typedef _HistoryNative = Int32 Function(Pointer<Void>, Pointer<Uint64>);
typedef _HistoryDart = int Function(Pointer<Void>, Pointer<Uint64>);

typedef _ExportMusicXmlNative =
    Int32 Function(
      Pointer<Void>,
      Pointer<Pointer<Uint8>>,
      Pointer<IntPtr>,
      Pointer<Uint64>,
    );
typedef _ExportMusicXmlDart =
    int Function(
      Pointer<Void>,
      Pointer<Pointer<Uint8>>,
      Pointer<IntPtr>,
      Pointer<Uint64>,
    );

typedef _LastErrorNative = Pointer<Utf8> Function(Pointer<Void>);
typedef _LastErrorDart = Pointer<Utf8> Function(Pointer<Void>);

typedef _BufferFreeNative = Void Function(Pointer<Void>);
typedef _BufferFreeDart = void Function(Pointer<Void>);

typedef _DisposeNative = Void Function(Pointer<Void>);
typedef _DisposeDart = void Function(Pointer<Void>);
