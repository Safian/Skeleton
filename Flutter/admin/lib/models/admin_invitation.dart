import 'package:equatable/equatable.dart';

// ============================================================
// AdminInvitation model – tükrözi az admin_invitations táblát
// ============================================================

enum InvitationStatus { pending, accepted, expired }

class AdminInvitation extends Equatable {
  final String id;
  final String token;
  final String email;
  final String role;
  final String? invitedBy;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? acceptedAt;
  final bool isUsed;
  final String? note;

  const AdminInvitation({
    required this.id,
    required this.token,
    required this.email,
    required this.role,
    this.invitedBy,
    required this.createdAt,
    required this.expiresAt,
    this.acceptedAt,
    required this.isUsed,
    this.note,
  });

  InvitationStatus get status {
    if (isUsed) return InvitationStatus.accepted;
    if (expiresAt.isBefore(DateTime.now())) return InvitationStatus.expired;
    return InvitationStatus.pending;
  }

  factory AdminInvitation.fromJson(Map<String, dynamic> json) {
    return AdminInvitation(
      id:         json['id'] as String,
      token:      json['token'] as String,
      email:      json['email'] as String,
      role:       json['role'] as String? ?? 'admin',
      invitedBy:  json['invited_by'] as String?,
      createdAt:  DateTime.parse(json['created_at'] as String),
      expiresAt:  DateTime.parse(json['expires_at'] as String),
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
      isUsed: json['is_used'] as bool? ?? false,
      note:   json['note'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, token, email, role, isUsed];
}
