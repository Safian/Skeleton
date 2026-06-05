import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../repositories/auth_repository.dart';
import '../../services/session_logger.dart'; // [M6]
import '../../services/push_notification_service.dart';
import 'session_state.dart';

// ============================================================
// SessionCubit – auth életciklus kezelő (top-level)
// ============================================================

class SessionCubit extends Cubit<SessionState> {
  final AuthRepository _repo;
  StreamSubscription<AuthState>? _authSub;

  SessionCubit({required AuthRepository repository})
      : _repo = repository,
        super(SessionBooting()) {
    _init();
  }

  Future<void> _init() async {
    // Maintenance check
    if (await _repo.isInMaintenance()) {
      emit(SessionMaintenance());
      return;
    }

    // Initial state
    final user = _repo.currentUser;
    if (user != null) {
      await _onUserLoggedIn(user);
    } else {
      emit(SessionLoggedOut());
    }

    // Live auth stream
    _authSub = _repo.authStateChanges.listen((authState) async {
      final event   = authState.event;
      final session = authState.session;

      if (event == AuthChangeEvent.passwordRecovery) {
        emit(SessionPasswordRecovery());
      } else if (session != null &&
          (event == AuthChangeEvent.signedIn ||
           event == AuthChangeEvent.tokenRefreshed ||
           event == AuthChangeEvent.userUpdated)) {
        await _onUserLoggedIn(session.user);
      } else if (event == AuthChangeEvent.signedOut) {
        SessionLogger.instance.reset(); // [M6]
        final s = state;
        if (s is SessionLoggedIn) {
          PushNotificationService.instance
              .unregisterToken(s.user.id)
              .catchError((_) {});
        }
        emit(SessionLoggedOut());
      }
    });
  }

  Future<void> _onUserLoggedIn(User user) async {
    var profile = await _repo.getUserProfile(user.id);

    // Profile trigger még nem futott le – retry 2s múlva
    if (profile == null) {
      await Future.delayed(const Duration(seconds: 2));
      profile = await _repo.getUserProfile(user.id);
    }

    if (isClosed) return; // a cubit közben bezárhatott (await-ek után)

    if (profile != null) {
      emit(SessionLoggedIn(user, profile));

      // [M6] Bejelentkezési metaadat naplózás
      SessionLogger.instance.log().catchError((_) {});
      // Push token regisztráció
      PushNotificationService.instance.registerToken(user.id).catchError((_) {});
    } else {
      // Törött session – kijelentkeztetjük
      await signOut();
    }
  }

  Future<void> signOut() async => _repo.signOut();

  Future<void> reloadProfile() async {
    final s = state;
    if (s is SessionLoggedIn) {
      final profile = await _repo.getUserProfile(s.user.id);
      if (profile != null) emit(SessionLoggedIn(s.user, profile));
    }
  }

  @override
  Future<void> close() {
    _authSub?.cancel();
    return super.close();
  }
}
