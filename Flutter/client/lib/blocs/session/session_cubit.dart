import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:skeleton_shared/skeleton_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../repositories/auth_repository.dart';
import '../../services/push_notification_service.dart';
import '../../services/session_log_service.dart';
import 'session_state.dart';

// ============================================================
// SessionCubit – auth életciklus kezelő
//
// Kizárólag az auth állapotot kezeli.
// Maintenance mód + verzióellenőrzés → ConfigCubit  [M5]
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

      // Maintenance check
      final inMaintenance = await _repo.isInMaintenance();
      if (inMaintenance) {
        if (!isClosed) emit(SessionMaintenance());
        return;
      }

      // Pending legal documents check
      final pendingDocs = await _repo.getPendingLegalDocuments(user.id);
      if (pendingDocs.isNotEmpty) {
        if (!isClosed) emit(SessionAcceptLegal(user, profile, pendingDocs));
        return;
      }

      emit(SessionLoggedIn(user, profile));
      _subscribeToProfileRealtime(user.id, profile);
      PushNotificationService.instance.registerToken(user.id).catchError((_) {});
      // [M2.3] Eszközadatok + geo logolása
      SessionLogService.instance.logSession().catchError((_) {});
    } finally {
      _handleInProgress = false;
    }
  }

  /// Realtime subscription on user_profiles — detects force-logout triggers:
  ///   • role downgrade (admin→user)
  ///   • is_deleted = true (account deactivated)
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

            // Optimistic profile update for non-critical changes
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
    _profileSub?.cancel();
    _profileSub = null;
    _pendingSignOutMessage = message;

    final s = state;
    if (s is SessionLoggedIn) {
      await PushNotificationService.instance
          .unregisterToken(s.user.id)
          .catchError((_) {});
    }
    return _repo.signOut();
  }

  Future<void> reloadProfile() async {
    final s = state;
    if (s is SessionLoggedIn) {
      final profile = await _repo.getUserProfile(s.user.id);
      if (profile != null && !isClosed) emit(SessionLoggedIn(s.user, profile));
    }
  }

  /// Optimistically updates the in-memory profile without a DB round-trip.
  void updateProfile(UserProfile updated) {
    final s = state;
    if (s is SessionLoggedIn && !isClosed) {
      emit(SessionLoggedIn(s.user, updated));
    }
  }

  /// Accepts a legal document and re-checks if any pending documents remain.
  Future<void> acceptDocument(String documentId, String version) async {
    final s = state;
    if (s is! SessionAcceptLegal) return;

    try {
      await _repo.acceptLegalDocument(s.user.id, documentId, version);
      final remaining = await _repo.getPendingLegalDocuments(s.user.id);
      if (isClosed) return;

      if (remaining.isEmpty) {
        emit(SessionLoggedIn(s.user, s.profile));
        _subscribeToProfileRealtime(s.user.id, s.profile);
        PushNotificationService.instance.registerToken(s.user.id).catchError((_) {});
        SessionLogService.instance.logSession().catchError((_) {});
      } else {
        emit(SessionAcceptLegal(s.user, s.profile, remaining));
      }
    } catch (_) {}
  }

  @override
  Future<void> close() {
    _authSub?.cancel();
    _profileSub?.cancel();
    return super.close();
  }
}
