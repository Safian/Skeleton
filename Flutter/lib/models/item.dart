import 'package:equatable/equatable.dart';

// ============================================================
// Item model – lista képernyő demo adatmodellje
// Projektenként cseréld le a valódi modellre.
// ============================================================

class Item extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String? category;
  final bool isActive;
  final DateTime createdAt;

  const Item({
    required this.id,
    required this.title,
    this.description,
    this.category,
    required this.isActive,
    required this.createdAt,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id:          json['id'] as String,
      title:       json['title'] as String,
      description: json['description'] as String?,
      category:    json['category'] as String?,
      isActive:    json['is_active'] as bool? ?? true,
      createdAt:   DateTime.tryParse(json['created_at'] as String? ?? '') ??
                   DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id':          id,
    'title':       title,
    'description': description,
    'category':    category,
    'is_active':   isActive,
    'created_at':  createdAt.toIso8601String(),
  };

  @override
  List<Object?> get props => [id, title, description, category, isActive];
}
