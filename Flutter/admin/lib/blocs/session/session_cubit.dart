import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:skeleton_shared/skeleton_shared.dart';
import '../../repositories/auth_repository.dart';
import 'session_state.dart';

// ============================================================
// SessionCubit – auth életciklus kezelő (top-level)
// ============================================================

class SessionCubit extends Cubit<SessionState> {
  final AuthRepository _repo;
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<List<Map<String, dynamic>>>? _profileSub;
  bool _handleInProgress = false;
  String? _pendingSignOutMessage;

  SessionCubit({required AuthRepository repository})
      : _repo = repository,
        super(SessionBooting()) {
    _init();
  }

  Future<void> _init() async {
    // Maintenance check before login
    if (await _repo.isInMaintenance()) {
      if (!isClosed) emit(const SessionMaintenance());
      return;
    }

    final user = _repo.currentUser;
    if (user != null) {
      await _onUserLoggedIn(user);
    } else {
      if (!isClosed) emit(const SessionLoggedOut());
    }

    _authSub = _repo.authStateChanges.listen((authState) async {
      final event   = authState.event;
      final session = authState.session;

      if (event == AuthChangeEvent.passwordRecovery) {
        if (!isClosed) emit(SessionPasswordRecovery());
      } else if (session != null &&
          (event == AuthChangeEvent.signedIn ||
           event == AuthChangeEvent.tokenRefreshed ||
           event == AuthChangeEvent.userUpdated)) {
        await _onUserLoggedIn(session.user);
      } else if (event == AuthChangeEvent.signedOut) {
        _profileSub?.cancel();
        _profileSub = null;
        final msg = _pendingSignOutMessage;
        _pendingSignOutMessage = null;
        if (!isClosed) emit(SessionLoggedOut(message: msg));
      }
    });
  }

  Future<void> _onUserLoggedIn(User user) async {
    if (_handleInProgress) return;
    _handleInProgress = true;

    try {
      var profile = await _repo.getUserProfile(user.id);

      if (profile == null) {
        await Future.delayed(const Duration(seconds: 2));
        profile = await _repo.getUserProfile(user.id);
      }

      if (isClosed) return;

      if (profile == null) {
        await signOut();
        return;
      }

      emit(SessionLoggedIn(user, profile));
      _subscribeToProfileRealtime(user.id, profile);
    } finally {
      _handleInProgress = false;
    }
  }

  void _subscribeToProfileRealtime(String userId, UserProfile currentProfile) {
    _profileSub?.cancel();
    _profileSub = Supabase.instance.client
        .from('user_profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .listen((rows) {
          if (rows.isEmpty || isClosed) return;
          try {
            final updated = UserProfile.fromJson(rows.first);

            if (updated.isDeleted == true) {
              signOut(message: 'A fiókod törölve lett.');
              return;
            }

            if (_isRoleDowngrade(currentProfile.role, updated.role)) {
              signOut(message: 'A fiókod jogosultsága megváltozott. Kérjük jelentkezz be újra.');
              return;
            }

            final s = state;
            if (s is SessionLoggedIn && !isClosed) {
              emit(SessionLoggedIn(s.user, updated));
            }
          } catch (_) {}
        }, onError: (_) {});
  }

  bool _isRoleDowngrade(String oldRole, String newRole) {
    const hierarchy = {'admin': 2, 'user': 1};
    return (hierarchy[newRole] ?? 0) < (hierarchy[oldRole] ?? 0);
  }

  Future<void> signOut({String? message}) async {
    _pendingSignOutMessage = message;
    _profileSub?.cancel();
    _profileSub = null;
    return _repo.signOut();
  }

  Future<void> reloadProfile() async {
    final s = state;
    if (s is SessionLoggedIn) {
      final profile = await _repo.getUserProfile(s.user.id);
      if (profile != null && !isClosed) emit(SessionLoggedIn(s.user, profile));
    }
  }

  void updateProfile(UserProfile updated) {
    final s = state;
    if (s is SessionLoggedIn && !isClosed) {
      emit(SessionLoggedIn(s.user, updated));
    }
  }

  @override
  Future<void> close() {
    _authSub?.cancel();
    _profileSub?.cancel();
    return super.close();
  }
}
