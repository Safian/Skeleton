class LegalDocument {
  final String id;
  final String version;
  final bool isActive;
  final Map<String, dynamic> titleLocales;
  final Map<String, dynamic> contentLocales;
  final DateTime updatedAt;

  LegalDocument({
    required this.id,
    this.version = '1.0',
    this.isActive = true,
    required this.titleLocales,
    required this.contentLocales,
    required this.updatedAt,
  });

  factory LegalDocument.fromJson(Map<String, dynamic> json) {
    return LegalDocument(
      id: json['id'] as String,
      version: json['version'] as String? ?? '1.0',
      isActive: json['is_active'] as bool? ?? true,
      titleLocales: json['title_locales'] as Map<String, dynamic>? ?? {},
      contentLocales: json['content_locales'] as Map<String, dynamic>? ?? {},
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'version': version,
      'is_active': isActive,
      'title_locales': titleLocales,
      'content_locales': contentLocales,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String localizedTitle(String lang) {
    final v = titleLocales[lang];
    if (v is String && v.trim().isNotEmpty) return v.trim();
    final huVal = titleLocales['hu'];
    if (huVal is String && huVal.trim().isNotEmpty) return huVal.trim();
    return id;
  }

  String localizedContent(String lang) {
    final v = contentLocales[lang];
    if (v is String && v.trim().isNotEmpty) return v.trim();
    final huVal = contentLocales['hu'];
    if (huVal is String && huVal.trim().isNotEmpty) return huVal.trim();
    return '';
  }
}
