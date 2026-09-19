import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/features/library/domain/picked_local_file.dart';
import 'package:page_a_diddle/features/library/domain/score_file_filter.dart';
import 'package:page_a_diddle/features/storage/cloud/data/cloud_oauth_config.dart';
import 'package:page_a_diddle/features/storage/cloud/data/cloud_token_store.dart';
import 'package:page_a_diddle/features/storage/cloud/data/dropbox_service.dart';
import 'package:page_a_diddle/features/storage/cloud/data/google_drive_service.dart';
import 'package:page_a_diddle/features/storage/cloud/domain/cloud_models.dart';

class CloudStorageFacade {
  CloudStorageFacade({
    required GoogleDriveService google,
    required DropboxService dropbox,
  }) : _google = google,
       _dropbox = dropbox;

  final GoogleDriveService _google;
  final DropboxService _dropbox;

  bool canAttempt(CloudKind kind) => CloudOAuthConfig.canAttempt(kind);

  Future<bool> isConnected(CloudKind kind) => switch (kind) {
    CloudKind.googleDrive => _google.isConnected(),
    CloudKind.dropbox => _dropbox.isConnected(),
  };

  Future<void> connect(CloudKind kind) => switch (kind) {
    CloudKind.googleDrive => _google.connect(),
    CloudKind.dropbox => _dropbox.connect(),
  };

  Future<void> disconnect(CloudKind kind) => switch (kind) {
    CloudKind.googleDrive => _google.disconnect(),
    CloudKind.dropbox => _dropbox.disconnect(),
  };

  Future<List<CloudEntry>> list(
    CloudKind kind, {
    String? folderId,
    String? folderPath,
    ScoreFileFilter filter = ScoreFileFilter.pdf,
  }) => switch (kind) {
    CloudKind.googleDrive => _google.list(folderId: folderId, filter: filter),
    CloudKind.dropbox => _dropbox.list(folderPath: folderPath, filter: filter),
  };

  Future<PickedLocalFile> download(CloudKind kind, CloudEntry entry) =>
      switch (kind) {
        CloudKind.googleDrive => _google.download(entry),
        CloudKind.dropbox => _dropbox.download(entry),
      };
}

final googleDriveServiceProvider = Provider<GoogleDriveService>((ref) {
  return GoogleDriveService(ref.watch(cloudTokenStoreProvider));
});

final dropboxServiceProvider = Provider<DropboxService>((ref) {
  return DropboxService(ref.watch(cloudTokenStoreProvider));
});

final cloudStorageProvider = Provider<CloudStorageFacade>((ref) {
  return CloudStorageFacade(
    google: ref.watch(googleDriveServiceProvider),
    dropbox: ref.watch(dropboxServiceProvider),
  );
});
