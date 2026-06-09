class TranslationEntry {
  final String key;
  final String hu;
  final String en;
  final Map<String, dynamic> locales;

  TranslationEntry({
    required this.key,
    required this.hu,
    required this.en,
    required this.locales,
  });

  factory TranslationEntry.fromJson(Map<String, dynamic> json) {
    return TranslationEntry(
      key: json['key'] as String,
      hu: json['hu'] as String? ?? '',
      en: json['en'] as String? ?? '',
      locales: json['locales'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'hu': hu,
      'en': en,
      'locales': locales,
    };
  }

  TranslationEntry copyWith({
    String? key,
    String? hu,
    String? en,
    Map<String, dynamic>? locales,
  }) {
    return TranslationEntry(
      key: key ?? this.key,
      hu: hu ?? this.hu,
      en: en ?? this.en,
      locales: locales ?? this.locales,
    );
  }
}
