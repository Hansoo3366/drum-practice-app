import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:page_a_diddle/features/digital_score/data/omr_convert_client.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_convert_jobs.dart';

void main() {
  test('failed job keeps the title and stores the error', () {
    const job = OmrConvertJob(
      id: 'omr-1',
      title: 'Ditto_RoadPiano',
      status: OmrConvertJobStatus.running,
      progress: 42,
    );
    final failed = job.copyWith(
      status: OmrConvertJobStatus.failed,
      error: 'convert timed out',
    );
    expect(failed.title, 'Ditto_RoadPiano');
    expect(failed.isRunning, isFalse);
    expect(failed.error, 'convert timed out');
  });

  test('pending job keeps its recognition profile after restoration', () {
    const job = OmrConvertJob(
      id: 'omr-2',
      title: 'Ditto',
      status: OmrConvertJobStatus.running,
      profile: OmrRecognitionProfile.chordsLyrics,
    );
    final restored = OmrConvertJob.fromJson(job.toJson());
    expect(restored.profile, OmrRecognitionProfile.chordsLyrics);
  });

  group('network retry', () {
    test('keeps polling through a brief connection drop', () async {
      var calls = 0;
      final waits = <Duration>[];
      final result = await retryOnNetworkError(
        () async {
          calls++;
          if (calls == 1) throw const SocketException('Connection refused');
          if (calls == 2) throw http.ClientException('Connection reset');
          return 'done';
        },
        shouldContinue: () => true,
        wait: (delay) async => waits.add(delay),
      );

      expect(result, 'done');
      expect(waits, [const Duration(seconds: 2), const Duration(seconds: 4)]);
    });

    test('a server-reported failure is not retried', () {
      var calls = 0;
      expect(
        retryOnNetworkError<String>(
          () async {
            calls++;
            throw const OmrConvertException('변환 실패');
          },
          shouldContinue: () => true,
          wait: (_) async {},
        ),
        throwsA(isA<OmrConvertException>()),
      );
      expect(calls, 1);
    });

    test('gives up after the retry window', () async {
      var time = DateTime(2026);
      await expectLater(
        retryOnNetworkError<String>(
          () async => throw const SocketException('down'),
          shouldContinue: () => true,
          window: const Duration(minutes: 5),
          now: () => time,
          wait: (delay) async => time = time.add(const Duration(minutes: 2)),
        ),
        throwsA(isA<SocketException>()),
      );
    });

    test('stops quietly when the job is removed', () async {
      final result = await retryOnNetworkError<String>(
        () async => throw const SocketException('down'),
        shouldContinue: () => false,
        wait: (_) async {},
      );
      expect(result, isNull);
    });
  });
}
