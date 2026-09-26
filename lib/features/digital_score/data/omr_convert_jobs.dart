import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_convert_client.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_convert_service.dart';
import 'package:page_a_diddle/features/library/domain/picked_local_file.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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
  }) {
    return OmrConvertJob(
      id: id,
      title: title,
      status: status ?? this.status,
      serverJobId: serverJobId ?? this.serverJobId,
      progress: progress ?? this.progress,
      step: step ?? this.step,
      error: error ?? this.error,
      folderId: folderId,
      originalName: originalName,
      profile: profile,
    );
  }
}

class OmrConvertJobs extends Notifier<List<OmrConvertJob>> {
  static const _prefsKey = 'omr_pending_jobs';
  final Map<String, bool> _polling = {};

  @override
  List<OmrConvertJob> build() {
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
    try {
      final remote = await ref
          .read(omrConvertServiceProvider)
          .start(
            source: PickedLocalFile(name: source.name, bytes: bytes),
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

  void dismiss(String id) {
    _polling[id] = false;
    state = [
      for (final job in state)
        if (job.id != id) job,
    ];
    unawaited(_persist());
    unawaited(_setWakeLock());
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
        final remote = await service.status(serverJobId);
        if (!_polling.containsKey(id)) return;
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
          _fail(id, OmrConvertException(remote.error));
          return;
        }
        if (remote.isDone) {
          final originalBytes = await _readPending(id);
          await service.importResult(
            jobId: serverJobId,
            title: local.title,
            folderId: local.folderId,
            original: originalBytes == null
                ? null
                : PickedLocalFile(
                    name: local.originalName ?? '${local.title}.pdf',
                    bytes: originalBytes,
                  ),
          );
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

  void _fail(String id, Object error) {
    _polling[id] = false;
    final message = error is OmrConvertException
        ? error.message
        : error.toString();
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
    if (running) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
  }
}

final omrConvertJobsProvider =
    NotifierProvider<OmrConvertJobs, List<OmrConvertJob>>(OmrConvertJobs.new);
