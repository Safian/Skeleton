import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'secure_storage_service.dart';

// ============================================================
// SessionLogService  [M2.3]
//
// Sikeres bejelentkezés után összegyűjti az eszközadatokat és
// elküldi a `session-log` Edge Function-nak.
// Az eredmény (session_id) Keychain-ben kerül mentésre.
// ============================================================

class SessionLogService {
  SessionLogService._();
  static final SessionLogService instance = SessionLogService._();

  final _deviceInfo   = DeviceInfoPlugin();
  final _secure       = SecureStorageService.instance;

  // ── Fő belépési pont ─────────────────────────────────────────
  /// Hívja a SessionCubit._onUserLoggedIn() után.
  Future<void> logSession() async {
    try {
      final client = Supabase.instance.client;
      final session = client.auth.currentSession;
      if (session == null) return;

      final payload = await _buildPayload(session);

      final response = await client.functions.invoke(
        'session-log',
        body: payload,
      );

      if (response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final sid = data['session_id']?.toString();
        if (sid != null) {
          await _secure.saveSessionLogId(sid);
        }
      }
    } catch (e) {
      debugPrint('[SessionLog] error: $e');
    }
  }

  // ── Payload összeállítása ────────────────────────────────────
  Future<Map<String, dynamic>> _buildPayload(Session session) async {
    final pkg = await PackageInfo.fromPlatform();
    final payload = <String, dynamic>{
      'app_version':         pkg.version,
      'app_build':           pkg.buildNumber,
      'locale':              Platform.localeName,
      'supabase_session_id': session.user.id,
    };

    if (kIsWeb) {
      final webInfo = await _deviceInfo.webBrowserInfo;
      payload['device_model'] = webInfo.browserName.name;
      payload['os_name']      = 'Web';
      payload['os_version']   = webInfo.platform ?? '';
    } else if (Platform.isAndroid) {
      final info = await _deviceInfo.androidInfo;
      payload['device_model'] = info.model;
      payload['device_brand'] = info.brand;
      payload['os_name']      = 'Android';
      payload['os_version']   = info.version.release;
    } else if (Platform.isIOS) {
      final info = await _deviceInfo.iosInfo;
      payload['device_model'] = info.utsname.machine;
      payload['device_brand'] = 'Apple';
      payload['os_name']      = 'iOS';
      payload['os_version']   = info.systemVersion;
    } else if (Platform.isMacOS) {
      final info = await _deviceInfo.macOsInfo;
      payload['device_model'] = info.model;
      payload['device_brand'] = 'Apple';
      payload['os_name']      = 'macOS';
      payload['os_version']   = info.osRelease;
    }

    return payload;
  }
}
