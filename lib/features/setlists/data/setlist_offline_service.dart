import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/core/storage/storage_provider.dart';
import 'package:page_a_diddle/features/setlists/data/setlist_repository.dart';
import 'package:page_a_diddle/features/storage/data/remote_score_service.dart';
import 'package:page_a_diddle/features/storage/data/webdav_connection.dart';
import 'package:page_a_diddle/features/storage/domain/sync_status.dart';

class SetlistOfflineResult {
  const SetlistOfflineResult({
    required this.downloaded,
    required this.failedTitles,
  });

  final int downloaded;
  final List<String> failedTitles;
}

class SetlistOfflineService {
  const SetlistOfflineService({
    required SetlistRepository setlists,
    required RemoteScoreService remoteScores,
  }) : _setlists = setlists,
       _remoteScores = remoteScores;

  final SetlistRepository _setlists;
  final RemoteScoreService _remoteScores;

  Future<SetlistOfflineResult> download(String setlistId) async {
    final items = await _setlists.watchItems(setlistId).first;
    final targets = items.where(
      (item) =>
          item.song.sourceProvider == StorageProvider.webDav.key &&
          (!item.song.offlineAvailable ||
              item.song.syncStatus == SyncStatus.updated.key),
    );
    var downloaded = 0;
    final failed = <String>[];

    for (final item in targets) {
      try {
        await _remoteScores.download(item.song);
        downloaded++;
      } on WebDavConnectionException {
        failed.add(item.song.title);
      } on FormatException {
        failed.add(item.song.title);
      } on FileSystemException {
        failed.add(item.song.title);
      }
    }
    return SetlistOfflineResult(downloaded: downloaded, failedTitles: failed);
  }
}

final setlistOfflineServiceProvider = Provider<SetlistOfflineService>((ref) {
  return SetlistOfflineService(
    setlists: ref.watch(setlistRepositoryProvider),
    remoteScores: ref.watch(remoteScoreServiceProvider),
  );
});
