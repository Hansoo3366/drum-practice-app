import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_convert_jobs.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_convert_client.dart';

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
}
