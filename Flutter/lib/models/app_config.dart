// ============================================================
// AppConfig model – a Supabase app_config tábla tükre
// ============================================================

class AppConfig {
  // Maintenance
  final bool maintenanceMode;
  final String maintenanceTitle;
  final String maintenanceMessage;

  // Versions
  final String minVersionIos;
  final String minVersionAndroid;
  final String latestVersionIos;
  final String latestVersionAndroid;
  final String appStoreUrlIos;
  final String appStoreUrlAndroid;

  // Feature flags
  final bool registrationEnabled;
  final bool googleLoginEnabled;
  final bool appleLoginEnabled;
  final bool pushNotificationsEnabled;
  final bool bugReporterEnabled;
  final bool tutorialEnabled;

  // App info
  final String appName;
  final String supportEmail;

  // Raw map (egyedi flag-ek lekérésére)
  final Map<String, dynamic> raw;

  const AppConfig({
    this.maintenanceMode = false,
    this.maintenanceTitle = 'Karbantartás',
    this.maintenanceMessage = 'Az alkalmazás karbantartás alatt áll.',
    this.minVersionIos = '0.0.0',
    this.minVersionAndroid = '0.0.0',
    this.latestVersionIos = '0.0.0',
    this.latestVersionAndroid = '0.0.0',
    this.appStoreUrlIos = '',
    this.appStoreUrlAndroid = '',
    this.registrationEnabled = true,
    this.googleLoginEnabled = false,
    this.appleLoginEnabled = false,
    this.pushNotificationsEnabled = false,
    this.bugReporterEnabled = false,
    this.tutorialEnabled = true,
    this.appName = 'Skeleton App',
    this.supportEmail = '',
    this.raw = const {},
  });

  factory AppConfig.fromMap(Map<String, dynamic> map) {
    bool b(String key, [bool def = false]) {
      final v = map[key];
      if (v is bool) return v;
      if (v is String) return v == 'true';
      return def;
    }
    String s(String key, [String def = '']) =>
        (map[key] as String?) ?? def;

    return AppConfig(
      maintenanceMode:    b('maintenance_mode'),
      maintenanceTitle:   s('maintenance_title', 'Karbantartás'),
      maintenanceMessage: s('maintenance_message',
          'Az alkalmazás karbantartás alatt áll.'),
      minVersionIos:      s('min_app_version_ios',  '0.0.0'),
      minVersionAndroid:  s('min_app_version_android', '0.0.0'),
      latestVersionIos:   s('latest_app_version_ios', '0.0.0'),
      latestVersionAndroid: s('latest_app_version_android', '0.0.0'),
      appStoreUrlIos:     s('app_store_url_ios'),
      appStoreUrlAndroid: s('app_store_url_android'),
      registrationEnabled:   b('feature_registration_enabled', true),
      googleLoginEnabled:    b('feature_google_login'),
      appleLoginEnabled:     b('feature_apple_login'),
      pushNotificationsEnabled: b('feature_push_notifications'),
      bugReporterEnabled:    b('feature_bug_reporter'),
      tutorialEnabled:       b('feature_tutorial', true),
      appName:               s('app_name', 'Skeleton App'),
      supportEmail:          s('support_email'),
      raw:                   map,
    );
  }

  /// Egyedi feature flag lekérése string key alapján
  bool flag(String key, [bool defaultValue = false]) {
    final v = raw[key];
    if (v is bool) return v;
    if (v is String) return v == 'true';
    return defaultValue;
  }

  static AppConfig get defaults => const AppConfig();
}
