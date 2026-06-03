import 'package:bloc/bloc.dart';
import '../../repositories/session_repository.dart';
import 'sessions_state.dart';

// ============================================================
// SessionsCubit – Admin Session kezelő  [M6]
// ============================================================

class SessionsCubit extends Cubit<SessionsState> {
  final SessionRepository _repo;

  SessionsCubit({required SessionRepository repository})
      : _repo = repository,
        super(const SessionsState());

  Future<void> load() async {
    emit(state.copyWith(status: SessionsStatus.loading, clearError: true));
    try {
      final results = await Future.wait([
        _repo.fetchActiveSessions(),
        _repo.fetchOsBreakdown(),
        _repo.fetchVersionBreakdown(),
        _repo.fetchStats(),
      ]);

      emit(state.copyWith(
        status:           SessionsStatus.loaded,
        sessions:         results[0] as dynamic,
        osBreakdown:      results[1] as dynamic,
        versionBreakdown: results[2] as dynamic,
        stats:            results[3] as dynamic,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: SessionsStatus.error,
        error:  e.toString(),
      ));
    }
  }

  Future<void> revokeSession(String sessionId) async {
    final newRevoking = {...state.revoking, sessionId};
    emit(state.copyWith(revoking: newRevoking));

    try {
      await _repo.revokeSession(sessionId);

      // Optimista frissítés – kivonjuk a listából
      final updated = state.sessions
          .where((s) => s.id != sessionId)
          .toList();
      final newRevokingDone = {...state.revoking}..remove(sessionId);
      emit(state.copyWith(
        sessions: updated,
        revoking: newRevokingDone,
      ));
    } catch (e) {
      final newRevokingFailed = {...state.revoking}..remove(sessionId);
      emit(state.copyWith(
        error:   'Session visszavonási hiba: $e',
        revoking: newRevokingFailed,
      ));
    }
  }
}
