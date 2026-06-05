import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../repositories/auth_repository.dart';
import '../../services/push_notification_service.dart';
import '../../services/session_log_service.dart';
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
    // [M3.1] App-config lekérés (maintenance + verzió check)
    try {
      final client = Supabase.instance.client;
      final res = await client.functions.invoke('app-config');
      final cfg = (res.data as Map<String, dynamic>?) ?? {};

      if (cfg['maintenance_mode'] == true) {
        final title   = cfg['maintenance_title']   as String? ?? 'Karbantartás';
        final message = cfg['maintenance_message'] as String? ?? '';
        if (!isClosed) emit(SessionMaintenance(title: title, message: message));
        return;
      }

      final versionState = await _checkVersion(cfg);
      if (versionState != null) {
        if (!isClosed) emit(versionState);
        return;
      }
    } catch (e) {
      debugPrint('[SessionCubit] app-config fetch error: $e');
      if (await _repo.isInMaintenance()) {
        if (!isClosed) emit(const SessionMaintenance());
        return;
      }
    }

    final user = _repo.currentUser;
    if (user != null) {
      await _onUserLoggedIn(user);
    } else {
      if (!isClosed) emit(SessionLoggedOut());
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
        if (!isClosed) emit(SessionLoggedOut());
      }
    });
  }

  // [M3.1] Verziószám összehasonlítás
  Future<SessionState?> _checkVersion(Map<String, dynamic> cfg) async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      final current = pkg.version;

      final bool isAndroid = defaultTargetPlatform == TargetPlatform.android;
      final minKey    = isAndroid ? 'min_app_version_android'    : 'min_app_version_ios';
      final latestKey = isAndroid ? 'latest_app_version_android' : 'latest_app_version_ios';
      final urlKey    = isAndroid ? 'app_store_url_android'      : 'app_store_url_ios';

      final minVersion    = cfg[minKey]    as String? ?? '1.0.0';
      final latestVersion = cfg[latestKey] as String? ?? '1.0.0';
      final storeUrl      = cfg[urlKey]    as String? ?? '';

      if (_cmpVersion(current, minVersion) < 0) {
        return SessionForceUpdate(
          currentVersion: current,
          requiredVersion: minVersion,
          storeUrl: storeUrl,
        );
      }
      if (_cmpVersion(current, latestVersion) < 0) {
        return SessionSoftUpdate(
          currentVersion: current,
          latestVersion: latestVersion,
          storeUrl: storeUrl,
        );
      }
    } catch (e) {
      debugPrint('[SessionCubit] version check error: $e');
    }
    return null;
  }

  int _cmpVersion(String a, String b) {
    List<int> p(String v) =>
        v.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final av = p(a); final bv = p(b);
    final len = av.length > bv.length ? av.length : bv.length;
    for (var i = 0; i < len; i++) {
      final diff = (i < av.length ? av[i] : 0) - (i < bv.length ? bv[i] : 0);
      if (diff != 0) return diff;
    }
    return 0;
  }

  Future<void> _onUserLoggedIn(User user) async {
    var profile = await _repo.getUserProfile(user.id);

    if (profile == null) {
      await Future.delayed(const Duration(seconds: 2));
      profile = await _repo.getUserProfile(user.id);
    }

    if (isClosed) return;

    if (profile != null) {
      emit(SessionLoggedIn(user, profile));
      PushNotificationService.instance.registerToken(user.id).catchError((_) {});
      // [M2.3] Eszközadatok + geo logolása
      SessionLogService.instance.logSession().catchError((_) {});
    } else {
      await signOut();
    }
  }

  Future<void> signOut() async {
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


  /// [M3.1] SoftUpdate képernyőn a "Később" gomb után – továbblép a login/home felé.
  Future<void> skipSoftUpdate() async {
    final user = _repo.currentUser;
    if (user != null) {
      await _onUserLoggedIn(user);
    } else {
      if (!isClosed) emit(SessionLoggedOut());
    }
  }

  @override
  Future<void> close() {
    _authSub?.cancel();
    return super.close();
  }
}

