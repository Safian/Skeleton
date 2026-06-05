import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ============================================================
// SecureStorageService  [M2.1] – Admin app
//
// iOS  → Keychain
// Android → EncryptedSharedPreferences (Keystore-backed AES)
// ============================================================

class SecureStorageService {
  SecureStorageService._();
  static final SecureStorageService instance = SecureStorageService._();

  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: _androidOptions,
    iOptions: _iosOptions,
  );

  static const _kAccessToken  = 'admin_auth_access_token';
  static const _kRefreshToken = 'admin_auth_refresh_token';
  static const _kUserId       = 'admin_auth_user_id';
  static const _kUserEmail    = 'admin_auth_user_email';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String userId,
    String? email,
  }) async {
    await Future.wait([
      _storage.write(key: _kAccessToken,  value: accessToken),
      _storage.write(key: _kRefreshToken, value: refreshToken),
      _storage.write(key: _kUserId,       value: userId),
      if (email != null) _storage.write(key: _kUserEmail, value: email),
    ]);
  }

  Future<String?> get accessToken  => _storage.read(key: _kAccessToken);
  Future<String?> get refreshToken => _storage.read(key: _kRefreshToken);
  Future<String?> get userId       => _storage.read(key: _kUserId);
  Future<String?> get userEmail    => _storage.read(key: _kUserEmail);

  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _kAccessToken),
      _storage.delete(key: _kRefreshToken),
      _storage.delete(key: _kUserId),
      _storage.delete(key: _kUserEmail),
    ]);
  }

  Future<void> clearAll() => _storage.deleteAll();
}
