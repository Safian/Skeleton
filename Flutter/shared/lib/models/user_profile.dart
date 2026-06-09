import 'package:equatable/equatable.dart';

// ============================================================
// UserProfile model – tükrözi a Supabase user_profiles táblát
// ============================================================

class UserProfile extends Equatable {
  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final String role;
  final String language;
  final bool isDeleted;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
    required this.role,
    this.language = 'hu',
    this.isDeleted = false,
    required this.createdAt,
  });

  String get displayNameOrEmail =>
      (displayName != null && displayName!.isNotEmpty) ? displayName! : email;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id:          json['id'] as String,
      email:       json['email'] as String? ?? '',
      displayName: json['display_name'] as String?,
      avatarUrl:   json['avatar_url'] as String?,
      role:        json['role'] as String? ?? 'user',
      language:    json['language'] as String? ?? 'hu',
      isDeleted:   json['is_deleted'] as bool? ?? false,
      createdAt:   DateTime.tryParse(json['created_at'] as String? ?? '') ??
                   DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id':           id,
    'email':        email,
    'display_name': displayName,
    'avatar_url':   avatarUrl,
    'role':         role,
    'language':     language,
    'is_deleted':   isDeleted,
    'created_at':   createdAt.toIso8601String(),
  };

  UserProfile copyWith({
    String? displayName,
    String? avatarUrl,
    String? role,
    String? language,
    bool? isDeleted,
  }) {
    return UserProfile(
      id:          id,
      email:       email,
      displayName: displayName ?? this.displayName,
      avatarUrl:   avatarUrl   ?? this.avatarUrl,
      role:        role        ?? this.role,
      language:    language    ?? this.language,
      isDeleted:   isDeleted   ?? this.isDeleted,
      createdAt:   createdAt,
    );
  }

  @override
  List<Object?> get props => [id, email, displayName, avatarUrl, role, language, isDeleted];
}

