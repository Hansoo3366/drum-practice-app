import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:page_a_diddle/features/storage/cloud/domain/cloud_models.dart';

class CloudTokenStore {
  CloudTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _accessKey(CloudKind kind) => 'cloud.${kind.id}.access';
  String _refreshKey(CloudKind kind) => 'cloud.${kind.id}.refresh';
  String _expiryKey(CloudKind kind) => 'cloud.${kind.id}.expiry';
  String _extraKey(CloudKind kind) => 'cloud.${kind.id}.extra';

  Future<bool> hasSession(CloudKind kind) async {
    final access = await _storage.read(key: _accessKey(kind));
    return access != null && access.isNotEmpty;
  }

  Future<String?> readAccessToken(CloudKind kind) {
    return _storage.read(key: _accessKey(kind));
  }

  Future<String?> readRefreshToken(CloudKind kind) {
    return _storage.read(key: _refreshKey(kind));
  }

  Future<DateTime?> readExpiry(CloudKind kind) async {
    final raw = await _storage.read(key: _expiryKey(kind));
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<String?> readExtra(CloudKind kind) {
    return _storage.read(key: _extraKey(kind));
  }

  Future<void> writeSession({
    required CloudKind kind,
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? extra,
  }) async {
    await _storage.write(key: _accessKey(kind), value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _refreshKey(kind), value: refreshToken);
    }
    if (expiresAt != null) {
      await _storage.write(
        key: _expiryKey(kind),
        value: expiresAt.toIso8601String(),
      );
    }
    if (extra != null) {
      await _storage.write(key: _extraKey(kind), value: extra);
    }
  }

  Future<void> clear(CloudKind kind) async {
    await _storage.delete(key: _accessKey(kind));
    await _storage.delete(key: _refreshKey(kind));
    await _storage.delete(key: _expiryKey(kind));
    await _storage.delete(key: _extraKey(kind));
  }
}

final cloudTokenStoreProvider = Provider<CloudTokenStore>((ref) {
  return CloudTokenStore();
});
