import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_profile.dart';

// ============================================================
// SessionState – globális auth állapotgép
// ============================================================

abstract class SessionState extends Equatable {
  const SessionState();
  @override
  List<Object?> get props => [];
}

/// App indulása, Supabase inicializálás
class SessionBooting extends SessionState {}

/// Karbantartási üzemmód  [M3.1]
class SessionMaintenance extends SessionState {
  final String title;
  final String message;
  const SessionMaintenance({
    this.title   = 'Karbantartás',
    this.message = '',
  });
  @override
  List<Object?> get props => [title, message];
}

/// Ajánlott frissítés – az app folytatható  [M3.1]
class SessionSoftUpdate extends SessionState {
  final String currentVersion;
  final String latestVersion;
  final String storeUrl;
  const SessionSoftUpdate({
    required this.currentVersion,
    required this.latestVersion,
    required this.storeUrl,
  });
  @override
  List<Object?> get props => [currentVersion, latestVersion, storeUrl];
}

/// Kötelező frissítés – az app nem folytatható  [M3.1]
class SessionForceUpdate extends SessionState {
  final String currentVersion;
  final String requiredVersion;
  final String storeUrl;
  const SessionForceUpdate({
    required this.currentVersion,
    required this.requiredVersion,
    required this.storeUrl,
  });
  @override
  List<Object?> get props => [currentVersion, requiredVersion, storeUrl];
}

/// Nincs bejelentkezett felhasználó
class SessionLoggedOut extends SessionState {}

/// Sikeres bejelentkezés
class SessionLoggedIn extends SessionState {
  final User user;
  final UserProfile profile;
  const SessionLoggedIn(this.user, this.profile);
  @override
  List<Object?> get props => [user.id, profile];
}

/// Password-reset link megnyitása után
class SessionPasswordRecovery extends SessionState {}
