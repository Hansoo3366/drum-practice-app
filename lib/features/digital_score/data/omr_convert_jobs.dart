import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:page_a_diddle/core/platform/screen_awake.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_convert_client.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_convert_service.dart';
import 'package:page_a_diddle/features/library/domain/picked_local_file.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum OmrConvertJobStatus { running, failed }

class OmrConvertJob {
  const OmrConvertJob({
    required this.id,
    required this.title,
    required this.status,
    this.serverJobId,
    this.progress = 0,
    this.step = '',
    this.error,
    this.folderId,
    this.originalName,
    this.profile = OmrRecognitionProfile.standard,
  });

  factory OmrConvertJob.fromJson(Map<String, Object?> json) {
    return OmrConvertJob(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      status: OmrConvertJobStatus.running,
      serverJobId: json['serverJobId']?.toString(),
      folderId: json['folderId']?.toString(),
      progress: (json['progress'] as num?)?.round() ?? 0,
      step: json['step']?.toString() ?? '',
      originalName: json['originalName']?.toString(),
      profile: json['profile'] == 'chords_lyrics'
          ? OmrRecognitionProfile.chordsLyrics
          : OmrRecognitionProfile.standard,
    );
  }

  final String id;
  final String title;
  final OmrConvertJobStatus status;
  final String? serverJobId;
  final int progress;
  final String step;
  final String? error;
  final String? folderId;
  final String? originalName;
  final OmrRecognitionProfile profile;

  bool get isRunning => status == OmrConvertJobStatus.running;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'serverJobId': serverJobId,
    'folderId': folderId,
    'progress': progress,
    'step': step,
    'originalName': originalName,
    'profile': profile.wireValue,
  };

  OmrConvertJob copyWith({
    OmrConvertJobStatus? status,
    String? serverJobId,
    int? progress,
    String? step,
    String? error,
    bool clearError = false,
  }) {
    return OmrConvertJob(
      id: id,
      title: title,
      status: status ?? this.status,
      serverJobId: serverJobId ?? this.serverJobId,
      progress: progress ?? this.progress,
      step: step ?? this.step,
      error: clearError ? null : error ?? this.error,
      folderId: folderId,
      originalName: originalName,
      profile: profile,
    );
  }
}

class OmrConvertJobs extends Notifier<List<OmrConvertJob>> {
  static const _prefsKey = 'omr_pending_jobs';
  final Map<String, bool> _polling = {};
  final _finished =
      StreamController<({String songId, String title})>.broadcast();

  /// Every conversion that ended as a score in the library. A conversion
  /// takes minutes and the user looks elsewhere meanwhile: the screen says
  /// when it is done.
  Stream<({String songId, String title})> get finished => _finished.stream;

  @override
  List<OmrConvertJob> build() {
    ref.onDispose(_finished.close);
    unawaited(_restore());
    return const [];
  }

  Future<void> enqueue(
    PickedLocalFile source, {
    String? folderId,
    OmrRecognitionProfile profile = OmrRecognitionProfile.standard,
  }) async {
    final bytes =
        source.bytes ??
        (source.path == null ? null : await File(source.path!).readAsBytes());
    if (bytes == null || bytes.isEmpty) {
      throw const FormatException('변환할 파일을 읽을 수 없습니다.');
    }
    final id = 'omr-${DateTime.now().microsecondsSinceEpoch}';
    final title = path.basenameWithoutExtension(source.name);
    state = [
      ...state,
      OmrConvertJob(
        id: id,
        title: title,
        status: OmrConvertJobStatus.running,
        folderId: folderId,
        originalName: source.name,
        profile: profile,
      ),
    ];
    await _writePending(id, bytes);
    await _setWakeLock();
    await _upload(id, source.name, bytes, profile);
  }

  /// Sends the file of job [id] to the server and starts following it.
  Future<void> _upload(
    String id,
    String name,
    Uint8List bytes,
    OmrRecognitionProfile profile,
  ) async {
    try {
      final remote = await ref
          .read(omrConvertServiceProvider)
          .start(
            source: PickedLocalFile(name: name, bytes: bytes),
            profile: profile,
          );
      state = [
        for (final job in state)
          if (job.id == id)
            job.copyWith(
              serverJobId: remote.id,
              progress: remote.progress,
              step: remote.step,
            )
          else
            job,
      ];
      await _persist();
      unawaited(_poll(id));
    } on Object catch (error) {
      _fail(id, error);
    }
  }

  Future<void> resume() async {
    await _restore();
  }

  /// Tries a failed job again. One the server already has is only checked
  /// again: the server may have finished while the phone was offline, so
  /// nothing is uploaded twice. One that never reached the server (no
  /// connection when it was started) is sent from the file kept for it.
  Future<void> retry(String id) async {
    final job = state.where((job) => job.id == id).firstOrNull;
    if (job == null || job.isRunning) return;
    final onServer = (job.serverJobId ?? '').isNotEmpty;
    final bytes = onServer ? null : await _readPending(id);
    if (!onServer && bytes == null) return;
    state = [
      for (final item in state)
        if (item.id == id)
          item.copyWith(status: OmrConvertJobStatus.running, clearError: true)
        else
          item,
    ];
    unawaited(_persist());
    unawaited(_setWakeLock());
    if (bytes == null) {
      unawaited(_poll(id));
    } else {
      await _upload(id, job.originalName ?? job.title, bytes, job.profile);
    }
  }

  void dismiss(String id) {
    _polling[id] = false;
    state = [
      for (final job in state)
        if (job.id != id) job,
    ];
    unawaited(_persist());
    unawaited(_setWakeLock());
    // The file kept for a retry is not needed any more.
    unawaited(_deletePending(id).then((_) {}, onError: (Object _) {}));
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw);
    if (decoded is! List) return;
    final restored = [
      for (final item in decoded)
        if (item is Map)
          OmrConvertJob.fromJson(Map<String, Object?>.from(item)),
    ].where((job) => job.id.isNotEmpty && (job.serverJobId ?? '').isNotEmpty);
    if (restored.isEmpty) return;
    final existing = {for (final job in state) job.id};
    state = [
      ...state,
      for (final job in restored)
        if (!existing.contains(job.id)) job,
    ];
    await _setWakeLock();
    for (final job in restored) {
      unawaited(_poll(job.id));
    }
  }

  Future<void> _poll(String id) async {
    if (_polling[id] == true) return;
    _polling[id] = true;
    final service = ref.read(omrConvertServiceProvider);
    try {
      while (_polling[id] == true) {
        final local = state.where((job) => job.id == id).firstOrNull;
        final serverJobId = local?.serverJobId;
        if (local == null || serverJobId == null) return;
        final remote = await _retryingNetwork(
          id,
          () => service.status(serverJobId),
        );
        if (remote == null || !_polling.containsKey(id)) return;
        state = [
          for (final job in state)
            if (job.id == id)
              job.copyWith(
                progress: remote.progress < job.progress
                    ? job.progress
                    : remote.progress,
                step: remote.step,
              )
            else
              job,
        ];
        if (remote.isError) {
          _fail(id, OmrConvertException(convertServerFailure(remote.error)));
          return;
        }
        if (remote.isDone) {
          final originalBytes = await _readPending(id);
          final imported = await _retryingNetwork(
            id,
            () => service.importResult(
              jobId: serverJobId,
              title: local.title,
              folderId: local.folderId,
              original: originalBytes == null
                  ? null
                  : PickedLocalFile(
                      name: local.originalName ?? '${local.title}.pdf',
                      bytes: originalBytes,
                    ),
            ),
          );
          if (imported == null) return;
          if (!_finished.isClosed) {
            _finished.add((songId: imported, title: local.title));
          }
          await _deletePending(id);
          _polling[id] = false;
          state = [
            for (final job in state)
              if (job.id != id) job,
          ];
          await _persist();
          await _setWakeLock();
          return;
        }
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    } on Object catch (error) {
      _fail(id, error);
    }
  }

  /// Returns null when polling stopped (job removed) during a retry.
  Future<T?> _retryingNetwork<T>(String id, Future<T> Function() request) {
    return retryOnNetworkError(
      request,
      shouldContinue: () => _polling[id] == true,
    );
  }

  void _fail(String id, Object error) {
    _polling[id] = false;
    final message = convertFailureMessage(error);
    state = [
      for (final job in state)
        if (job.id == id)
          job.copyWith(status: OmrConvertJobStatus.failed, error: message)
        else
          job,
    ];
    unawaited(_persist());
    unawaited(_setWakeLock());
  }

  Future<File> _pendingFile(String id) async {
    final root = await getApplicationDocumentsDirectory();
    return File(path.join(root.path, 'omr_pending', '$id.bin'));
  }

  Future<void> _writePending(String id, Uint8List bytes) async {
    final file = await _pendingFile(id);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  Future<Uint8List?> _readPending(String id) async {
    final file = await _pendingFile(id);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  Future<void> _deletePending(String id) async {
    final file = await _pendingFile(id);
    if (await file.exists()) await file.delete();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final running = [
      for (final job in state)
        if (job.isRunning && (job.serverJobId ?? '').isNotEmpty) job.toJson(),
    ];
    await prefs.setString(_prefsKey, jsonEncode(running));
  }

  Future<void> _setWakeLock() async {
    final running = state.any((job) => job.isRunning);
    await (running ? ScreenAwake.hold(this) : ScreenAwake.release(this));
  }
}

final omrConvertJobsProvider =
    NotifierProvider<OmrConvertJobs, List<OmrConvertJob>>(OmrConvertJobs.new);

/// How long a conversion keeps retrying while the network is unreachable.
/// The server keeps converting meanwhile, so a brief drop on a phone (Wi-Fi
/// to mobile data, a tunnel) must not throw the finished result away.
const omrNetworkRetryWindow = Duration(minutes: 5);

/// What the server's reason for a failed job reads as to the user. The
/// server writes for its own log ("No valid MusicXML result; see
/// recognition.json and candidate logs").
String convertServerFailure(String error) {
  final text = error.toLowerCase();
  if (text.contains('no valid musicxml') || text.contains('no score')) {
    return '악보를 찾지 못했습니다. 악보가 또렷하게 보이는 사진이나 PDF인지 확인하세요.';
  }
  if (text.contains('timed out') || text.contains('timeout')) {
    return '변환이 너무 오래 걸려 멈췄습니다. 쪽 수를 줄여 다시 시도하세요.';
  }
  if (text.contains('restart')) {
    return '서버가 다시 시작되어 변환이 끊겼습니다. 다시 시도하세요.';
  }
  return '변환하지 못했습니다. 다시 시도하세요.';
}

/// What a failed conversion says on its card. The server's own reasons are
/// shown as they are; a connection that failed, or anything unexpected, is
/// said in words the user can act on instead of the exception's text.
String convertFailureMessage(Object error) => switch (error) {
  OmrConvertException(:final message) => message,
  FormatException(:final message) when message.isNotEmpty => message,
  _ when isTransientNetworkError(error) =>
    '변환 서버에 연결하지 못했습니다. 인터넷 연결을 확인하고 다시 시도하세요.',
  _ => '변환하지 못했습니다. 다시 시도하세요.',
};

bool isTransientNetworkError(Object error) =>
    error is SocketException ||
    error is TimeoutException ||
    error is http.ClientException ||
    error is HttpException;

/// Runs [request], retrying transient network failures with backoff
/// (2 s doubling to 20 s) for up to [window]. Other errors, such as a job the
/// server reports as failed, are rethrown at once. Returns null when
/// [shouldContinue] turns false while waiting.
Future<T?> retryOnNetworkError<T>(
  Future<T> Function() request, {
  required bool Function() shouldContinue,
  Duration window = omrNetworkRetryWindow,
  Future<void> Function(Duration delay)? wait,
  DateTime Function()? now,
}) async {
  final clock = now ?? DateTime.now;
  final pause = wait ?? (delay) => Future<void>.delayed(delay);
  final started = clock();
  var delay = const Duration(seconds: 2);
  while (true) {
    try {
      return await request();
    } on Object catch (error) {
      if (!isTransientNetworkError(error) ||
          clock().difference(started) > window) {
        rethrow;
      }
    }
    await pause(delay);
    if (!shouldContinue()) return null;
    delay = Duration(seconds: (delay.inSeconds * 2).clamp(2, 20));
  }
}
