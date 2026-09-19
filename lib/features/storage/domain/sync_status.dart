import 'package:page_a_diddle/l10n/app_localizations.dart';

enum SyncStatus {
  cloudOnly('cloud_only'),
  offlineAvailable('offline_available'),
  synced('synced'),
  updated('updated'),
  missing('missing');

  const SyncStatus(this.key);

  final String key;

  String label(AppLocalizations l10n) => switch (this) {
    SyncStatus.cloudOnly => l10n.syncCloud,
    SyncStatus.offlineAvailable => l10n.syncOffline,
    SyncStatus.synced => l10n.syncSynced,
    SyncStatus.updated => l10n.syncUpdate,
    SyncStatus.missing => l10n.syncMissing,
  };

  static SyncStatus? fromKey(String? key) {
    for (final status in values) {
      if (status.key == key) return status;
    }
    return null;
  }
}

SyncStatus resolveSyncStatus({
  required bool hasLocalRecord,
  required bool offlineAvailable,
  required bool remotePresent,
  DateTime? syncedModifiedAt,
  int? syncedSize,
  DateTime? remoteModifiedAt,
  int? remoteSize,
}) {
  if (!hasLocalRecord || !offlineAvailable) return SyncStatus.cloudOnly;
  if (!remotePresent) return SyncStatus.missing;
  if (syncedModifiedAt == null && syncedSize == null) {
    return SyncStatus.offlineAvailable;
  }

  final modifiedMatches =
      syncedModifiedAt == null ||
      remoteModifiedAt == null ||
      syncedModifiedAt.isAtSameMomentAs(remoteModifiedAt);
  final sizeMatches =
      syncedSize == null || remoteSize == null || syncedSize == remoteSize;
  return modifiedMatches && sizeMatches
      ? SyncStatus.synced
      : SyncStatus.updated;
}
