enum StorageProvider {
  local,
  osFileProvider,
  googleDrive,
  oneDrive,
  dropbox,
  webDav,
}

/// Source marker for setlist entries that still need a local score binding.
/// These rows stay in the database so the downloaded setlist keeps its order,
/// but are hidden from the Library until a real PDF is imported.
const jamPendingSourceProvider = 'jam_pending';

/// PDF cached from the conductor for the current Jam session.
/// These rows are temporary and stay hidden from the Library.
const jamHostSourceProvider = 'jam_host';

extension StorageProviderX on StorageProvider {
  String get key => switch (this) {
    StorageProvider.local => 'local',
    StorageProvider.osFileProvider => 'os_file_provider',
    StorageProvider.googleDrive => 'google_drive',
    StorageProvider.oneDrive => 'onedrive',
    StorageProvider.dropbox => 'dropbox',
    StorageProvider.webDav => 'webdav',
  };

  String get label => switch (this) {
    StorageProvider.local => '기기',
    StorageProvider.osFileProvider => '파일 선택기',
    StorageProvider.googleDrive => 'Google Drive',
    StorageProvider.oneDrive => 'OneDrive',
    StorageProvider.dropbox => 'Dropbox',
    StorageProvider.webDav => 'WebDAV',
  };
}

StorageProvider? storageProviderFromKey(String key) {
  for (final provider in StorageProvider.values) {
    if (provider.key == key) return provider;
  }
  return null;
}
