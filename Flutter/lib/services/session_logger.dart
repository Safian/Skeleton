import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

// ============================================================
// SessionLogger – Bejelentkezési metaadat naplózás  [M6]
//
// Minden sikeres auth esemény után meghívandó.
// Elküldi az eszköz adatokat a session-log Edge Function-nak.
//
// Használat (pl. SessionCubit-ben, _onUserLoggedIn után):
//   await SessionLogger.instance.log();
// ============================================================

class SessionLogger {
  SessionLogger._();
  static final SessionLogger instance = SessionLogger._();

  bool _logged = false; // Életciklusonként egyszer logoljuk

  // ── Fő belépési pont ──────────────────────────────────────

  /// Bejelentkezési session logolása.
  /// [force] = true esetén akkor is logol, ha már logolt ebben az életciklusban.
  Future<void> log({bool force = false}) async {
    if (_logged && !force) return;

    try {
      final client = Supabase.instance.client;
      final session = client.auth.currentSession;

      if (session == null) return; // Nincs bejelentkezve

      final deviceInfo  = await _collectDeviceInfo();
      final packageInfo = await PackageInfo.fromPlatform();

      final payload = {
        'device_model':  deviceInfo['model'],
        'device_brand':  deviceInfo['brand'],
        'os_name':       deviceInfo['os'],
        'os_version':    deviceInfo['osVersion'],
        'app_version':   packageInfo.version,
        'app_build':     packageInfo.buildNumber,
        'locale':        _getLocale(),
        // A user id-t küldjük session-azonosítóként – soha ne szivárogjon ki
        // az access token (még részlet sem) a backend logokba.
        'supabase_session_id': session.user.id,
      };

      await client.functions.invoke(
        'session-log',
        body: payload,
      );

      _logged = true;
      debugPrint('[SessionLogger] Session logged successfully');
    } catch (e) {
      // Nem blokkoló – ha sikertelen, csendben eldobjuk
      debugPrint('[SessionLogger] Failed to log session: $e');
    }
  }

  /// Reset – pl. kijelentkezéskor, hogy legközelebb újra logoljon
  void reset() => _logged = false;

  // ── Eszközadat gyűjtés ────────────────────────────────────

  Future<Map<String, String?>> _collectDeviceInfo() async {
    final plugin = DeviceInfoPlugin();

    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await plugin.iosInfo;
        return {
          'model':     info.utsname.machine,
          'brand':     'Apple',
          'os':        'iOS',
          'osVersion': info.systemVersion,
        };
      }

      if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await plugin.androidInfo;
        return {
          'model':     info.model,
          'brand':     info.brand,
          'os':        'Android',
          'osVersion': info.version.release,
        };
      }

      if (defaultTargetPlatform == TargetPlatform.macOS) {
        final info = await plugin.macOsInfo;
        return {
          'model':     info.model,
          'brand':     'Apple',
          'os':        'macOS',
          'osVersion': info.osRelease,
        };
      }

      if (defaultTargetPlatform == TargetPlatform.windows) {
        final info = await plugin.windowsInfo;
        return {
          'model':     info.computerName,
          'brand':     null,
          'os':        'Windows',
          'osVersion': info.displayVersion,
        };
      }

      if (defaultTargetPlatform == TargetPlatform.linux) {
        final info = await plugin.linuxInfo;
        return {
          'model':     info.name,
          'brand':     null,
          'os':        'Linux',
          'osVersion': info.version,
        };
      }
    } catch (e) {
      debugPrint('[SessionLogger] Device info error: $e');
    }

    return {
      'model': null, 'brand': null, 'os': null, 'osVersion': null,
    };
  }

  String _getLocale() {
    try {
      // A WidgetsBinding locale-ból nyerjük ki
      final locale = PlatformDispatcher.instance.locale;
      return locale.toLanguageTag(); // pl. 'hu-HU'
    } catch (_) {
      return 'unknown';
    }
  }
}
