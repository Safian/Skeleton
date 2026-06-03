part of 'invitations_cubit.dart';

enum InvitationsStatus { initial, loading, loaded, error }

class InvitationsState extends Equatable {
  final InvitationsStatus status;
  final List<AdminInvitation> invitations;
  final String? error;
  final bool isSending;
  final String? sendError;
  final String? lastInviteUrl;
  final bool? lastEmailSent;

  const InvitationsState({
    this.status      = InvitationsStatus.initial,
    this.invitations = const [],
    this.error,
    this.isSending   = false,
    this.sendError,
    this.lastInviteUrl,
    this.lastEmailSent,
  });

  List<AdminInvitation> get pending  =>
      invitations.where((i) => i.status == InvitationStatus.pending).toList();
  List<AdminInvitation> get accepted =>
      invitations.where((i) => i.status == InvitationStatus.accepted).toList();
  List<AdminInvitation> get expired  =>
      invitations.where((i) => i.status == InvitationStatus.expired).toList();

  InvitationsState copyWith({
    InvitationsStatus? status,
    List<AdminInvitation>? invitations,
    String? error,
    bool? isSending,
    String? sendError,
    String? lastInviteUrl,
    bool? lastEmailSent,
  }) {
    return InvitationsState(
      status:        status        ?? this.status,
      invitations:   invitations   ?? this.invitations,
      error:         error,
      isSending:     isSending     ?? this.isSending,
      sendError:     sendError,
      lastInviteUrl: lastInviteUrl,
      lastEmailSent: lastEmailSent,
    );
  }

  @override
  List<Object?> get props => [
    status, invitations, error, isSending, sendError, lastInviteUrl, lastEmailSent
  ];
}
