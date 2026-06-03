// ============================================================
// AppConfig model (Admin) – app_config tábla teljes tükre  [M5]
// ============================================================

class AppConfigEntry {
  final String key;
  final String value;
  final String valueType; // 'string' | 'bool' | 'int' | 'json'
  final String description;
  final DateTime updatedAt;

  const AppConfigEntry({
    required this.key,
    required this.value,
    required this.valueType,
    required this.description,
    required this.updatedAt,
  });

  factory AppConfigEntry.fromJson(Map<String, dynamic> json) {
    return AppConfigEntry(
      key:         json['key']         as String,
      value:       json['value']       as String? ?? '',
      valueType:   json['value_type']  as String? ?? 'string',
      description: json['description'] as String? ?? '',
      updatedAt:   DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  // Értelmezett boolean érték
  bool get boolValue => value == 'true';

  // Értelmezett int érték
  int get intValue => int.tryParse(value) ?? 0;

  // Feature flag-e?
  bool get isFlag => valueType == 'bool';

  // Karbantartáshoz kapcsolódó-e?
  bool get isMaintenance => key.startsWith('maintenance_');

  // Verzióhoz kapcsolódó-e?
  bool get isVersion =>
      key.startsWith('min_app_version') ||
      key.startsWith('latest_app_version') ||
      key.startsWith('app_store_url');

  AppConfigEntry copyWith({String? value}) {
    return AppConfigEntry(
      key:         key,
      value:       value ?? this.value,
      valueType:   valueType,
      description: description,
      updatedAt:   DateTime.now(),
    );
  }
}
