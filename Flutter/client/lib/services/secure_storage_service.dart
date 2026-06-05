import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ============================================================
// SecureStorageService  [M2.1]
//
// iOS  → Keychain (kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
// Android → EncryptedSharedPreferences (Keystore-backed AES)
//
// Adatok fennmaradnak alkalmazás törlésen/újratelepítésen is iOS-en.
// Android-on az encryptedSharedPreferences visszafejthető az OS által
// megőrzött kulccsal, így újratelepítés után üres marad.
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

  // ── Key constants ────────────────────────────────────────────
  static const _kAccessToken    = 'auth_access_token';
  static const _kRefreshToken   = 'auth_refresh_token';
  static const _kUserId         = 'auth_user_id';
  static const _kUserEmail      = 'auth_user_email';
  static const _kSessionId      = 'session_log_id';
  static const _kDeferredLinkChecked = 'deferred_link_checked';

  // ── Write ────────────────────────────────────────────────────
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

  Future<void> saveSessionLogId(String sessionId) =>
      _storage.write(key: _kSessionId, value: sessionId);

  Future<void> markDeferredLinkChecked() =>
      _storage.write(key: _kDeferredLinkChecked, value: 'true');

  // ── Read ─────────────────────────────────────────────────────
  Future<String?> get accessToken  => _storage.read(key: _kAccessToken);
  Future<String?> get refreshToken => _storage.read(key: _kRefreshToken);
  Future<String?> get userId       => _storage.read(key: _kUserId);
  Future<String?> get userEmail    => _storage.read(key: _kUserEmail);
  Future<String?> get sessionLogId => _storage.read(key: _kSessionId);

  Future<bool> get isDeferredLinkChecked async {
    final v = await _storage.read(key: _kDeferredLinkChecked);
    return v == 'true';
  }

  // ── Delete ───────────────────────────────────────────────────
  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _kAccessToken),
      _storage.delete(key: _kRefreshToken),
      _storage.delete(key: _kUserId),
      _storage.delete(key: _kUserEmail),
      _storage.delete(key: _kSessionId),
    ]);
  }

  Future<void> clearAll() => _storage.deleteAll();
}
