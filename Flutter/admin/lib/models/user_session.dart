// ============================================================
// UserSession model (Admin) – user_sessions tábla tükre  [M6]
// ============================================================

class UserSession {
  final String id;
  final DateTime createdAt;
  final String userId;
  final String? userEmail;     // JOIN-ból jön (admin view)
  final String? displayName;

  final String? deviceModel;
  final String? deviceBrand;
  final String? osName;
  final String? osVersion;
  final String? appVersion;
  final String? appBuild;
  final String? locale;

  final String? ipAddress;
  final String? geoCountry;
  final String? geoCity;

  final bool isActive;
  final DateTime lastSeenAt;
  final DateTime? revokedAt;

  const UserSession({
    required this.id,
    required this.createdAt,
    required this.userId,
    this.userEmail,
    this.displayName,
    this.deviceModel,
    this.deviceBrand,
    this.osName,
    this.osVersion,
    this.appVersion,
    this.appBuild,
    this.locale,
    this.ipAddress,
    this.geoCountry,
    this.geoCity,
    required this.isActive,
    required this.lastSeenAt,
    this.revokedAt,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      id:          json['id']          as String,
      createdAt:   DateTime.parse(json['created_at'] as String),
      userId:      json['user_id']     as String,
      userEmail:   json['user_email']  as String?,
      displayName: json['display_name'] as String?,
      deviceModel: json['device_model'] as String?,
      deviceBrand: json['device_brand'] as String?,
      osName:      json['os_name']      as String?,
      osVersion:   json['os_version']   as String?,
      appVersion:  json['app_version']  as String?,
      appBuild:    json['app_build']    as String?,
      locale:      json['locale']       as String?,
      ipAddress:   json['ip_address']   as String?,
      geoCountry:  json['geo_country']  as String?,
      geoCity:     json['geo_city']     as String?,
      isActive:    json['is_active']    as bool? ?? true,
      lastSeenAt:  DateTime.parse(json['last_seen_at'] as String? ??
          json['created_at'] as String),
      revokedAt:   json['revoked_at'] != null
          ? DateTime.parse(json['revoked_at'] as String)
          : null,
    );
  }

  String get deviceLabel {
    if (deviceModel != null && deviceModel!.isNotEmpty) return deviceModel!;
    if (osName != null) return '$osName ${osVersion ?? ''}'.trim();
    return 'Ismeretlen';
  }

  String get locationLabel {
    if (geoCity != null && geoCountry != null) return '$geoCity, $geoCountry';
    if (geoCountry != null) return geoCountry!;
    return ipAddress ?? 'N/A';
  }

  String get osPlatform {
    final os = osName?.toLowerCase() ?? '';
    if (os.contains('ios') || os.contains('macos')) return 'apple';
    if (os.contains('android'))                      return 'android';
    return 'unknown';
  }
}
