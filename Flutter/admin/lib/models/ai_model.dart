// ============================================================
// AiModel – represents a row in the ai_models table
// ============================================================

class AiModel {
  final String id;
  final String name;
  final String model;
  final String? systemPrompt;
  final bool isDefault;
  final DateTime createdAt;

  const AiModel({
    required this.id,
    required this.name,
    required this.model,
    this.systemPrompt,
    required this.isDefault,
    required this.createdAt,
  });

  factory AiModel.fromJson(Map<String, dynamic> json) {
    return AiModel(
      id: json['id'] as String,
      name: json['name'] as String,
      model: json['model'] as String,
      systemPrompt: json['system_prompt'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'model': model,
        if (systemPrompt != null) 'system_prompt': systemPrompt,
        'is_default': isDefault,
      };

  AiModel copyWith({
    String? name,
    String? model,
    String? systemPrompt,
    bool? isDefault,
  }) {
    return AiModel(
      id: id,
      name: name ?? this.name,
      model: model ?? this.model,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt,
    );
  }
}
