import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/storage/domain/sync_status.dart';

void main() {
  final syncedAt = DateTime.utc(2026, 8, 20, 5);

  test('로컬 파일과 원격 스냅샷을 비교해 상태를 계산한다', () {
    expect(
      resolveSyncStatus(
        hasLocalRecord: false,
        offlineAvailable: false,
        remotePresent: true,
      ),
      SyncStatus.cloudOnly,
    );
    expect(
      resolveSyncStatus(
        hasLocalRecord: true,
        offlineAvailable: true,
        remotePresent: true,
      ),
      SyncStatus.offlineAvailable,
    );
    expect(
      resolveSyncStatus(
        hasLocalRecord: true,
        offlineAvailable: true,
        remotePresent: true,
        syncedModifiedAt: syncedAt,
        syncedSize: 1024,
        remoteModifiedAt: syncedAt,
        remoteSize: 1024,
      ),
      SyncStatus.synced,
    );
    expect(
      resolveSyncStatus(
        hasLocalRecord: true,
        offlineAvailable: true,
        remotePresent: true,
        syncedModifiedAt: syncedAt,
        syncedSize: 1024,
        remoteModifiedAt: syncedAt.add(const Duration(minutes: 1)),
        remoteSize: 2048,
      ),
      SyncStatus.updated,
    );
    expect(
      resolveSyncStatus(
        hasLocalRecord: true,
        offlineAvailable: true,
        remotePresent: false,
        syncedModifiedAt: syncedAt,
        syncedSize: 1024,
      ),
      SyncStatus.missing,
    );
  });
}
