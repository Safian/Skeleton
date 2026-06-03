import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/admin_invitation.dart';
import '../../repositories/invitation_repository.dart';

part 'invitations_state.dart';

// ============================================================
// InvitationsCubit – admin meghívók state kezelése
// ============================================================

class InvitationsCubit extends Cubit<InvitationsState> {
  final InvitationRepository _repo;

  InvitationsCubit({required InvitationRepository repository})
      : _repo = repository,
        super(const InvitationsState());

  Future<void> load() async {
    emit(state.copyWith(status: InvitationsStatus.loading, error: null));
    try {
      final invitations = await _repo.getInvitations();
      emit(state.copyWith(
        status:      InvitationsStatus.loaded,
        invitations: invitations,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: InvitationsStatus.error,
        error:  e.toString(),
      ));
    }
  }

  Future<bool> sendInvitation({
    required String email,
    String role = 'admin',
    String? note,
  }) async {
    emit(state.copyWith(isSending: true, sendError: null));
    try {
      final result = await _repo.sendInvitation(
        email: email, role: role, note: note,
      );
      emit(state.copyWith(
        isSending:   false,
        lastInviteUrl: result['invite_url'] as String?,
        lastEmailSent: result['email_sent'] as bool? ?? false,
      ));
      await load(); // frissítjük a listát
      return true;
    } catch (e) {
      emit(state.copyWith(isSending: false, sendError: e.toString()));
      return false;
    }
  }

  Future<void> revokeInvitation(String id) async {
    try {
      await _repo.revokeInvitation(id);
      await load();
    } catch (e) {
      emit(state.copyWith(error: 'Visszavonás sikertelen: $e'));
    }
  }

  Future<void> deleteInvitation(String id) async {
    try {
      await _repo.deleteInvitation(id);
      await load();
    } catch (e) {
      emit(state.copyWith(error: 'Törlés sikertelen: $e'));
    }
  }

  void clearSendResult() {
    emit(state.copyWith(
      sendError:     null,
      lastInviteUrl: null,
      lastEmailSent: null,
    ));
  }
}
