import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// RemoteConfig – app konfig singleton szerviz  [M5]
//
// Betölti az `app-config` edge function publikus kimenetét és
// tipizált getter-eken keresztül teszi elérhetővé a flageket.
//
// Hiba esetén nem-fatális: az app safe defaults-szal fut tovább.
// Nincs BLoC szükséglet – bárhonnan hívható:
//   RemoteConfig.instance.flag('feature_name')
// ============================================================

class RemoteConfig {
  RemoteConfig._();
  static final RemoteConfig instance = RemoteConfig._();

  Map<String, dynamic> _values = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  // ── Maintenance ────────────────────────────────────────────

  bool get maintenanceMode =>
      _values['maintenance_mode'] == true ||
      _values['maintenance_mode'] == 'true';

  String get maintenanceTitle =>
      (_values['maintenance_title'] as String?) ?? 'Karbantartás';

  String get maintenanceMessage =>
      (_values['maintenance_message'] as String?) ??
      'Az alkalmazás karbantartás alatt áll.';

  // ── Verzió ────────────────────────────────────────────────

  String get minVersionIos =>
      (_values['min_app_version_ios'] as String?) ?? '0.0.0';

  String get minVersionAndroid =>
      (_values['min_app_version_android'] as String?) ?? '0.0.0';

  String get latestVersionIos =>
      (_values['latest_app_version_ios'] as String?) ?? '0.0.0';

  String get latestVersionAndroid =>
      (_values['latest_app_version_android'] as String?) ?? '0.0.0';

  String get appStoreUrlIos =>
      (_values['app_store_url_ios'] as String?) ?? '';

  String get appStoreUrlAndroid =>
      (_values['app_store_url_android'] as String?) ?? '';

  // ── Feature flagek ─────────────────────────────────────────

  bool get registrationEnabled => flag('feature_registration_enabled', fallback: true);
  bool get googleLoginEnabled  => flag('feature_google_login');
  bool get appleLoginEnabled   => flag('feature_apple_login');
  bool get pushEnabled         => flag('feature_push_notifications');
  bool get bugReporterEnabled  => flag('feature_bug_reporter');
  bool get tutorialEnabled     => flag('feature_tutorial', fallback: true);

  // ── App info ───────────────────────────────────────────────

  String get appName     => (_values['app_name'] as String?) ?? 'App';
  String get supportEmail => (_values['support_email'] as String?) ?? '';

  // ── Generikus elérők ───────────────────────────────────────

  /// Boolean feature flag lekérése, [fallback] alapértékkel.
  bool flag(String key, {bool fallback = false}) {
    final v = _values[key];
    if (v is bool) return v;
    if (v is String) return v == 'true';
    return fallback;
  }

  /// String érték lekérése.
  String? string(String key) => _values[key] as String?;

  /// Int érték lekérése.
  int? integer(String key) {
    final v = _values[key];
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  // ── Betöltés ───────────────────────────────────────────────

  /// Konfig betöltése az `app-config` edge function-ből.
  /// Timeout: 5mp. Hiba esetén silent fail – safe defaults maradnak.
  Future<void> load() async {
    try {
      final res = await Supabase.instance.client.functions
          .invoke('app-config', method: HttpMethod.get)
          .timeout(const Duration(seconds: 5));
      if (res.data is Map) {
        _values = Map<String, dynamic>.from(res.data as Map);
        _loaded = true;
      }
    } catch (e) {
      debugPrint('[RemoteConfig] load failed: $e');
    }
  }
}
