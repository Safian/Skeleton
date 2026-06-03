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

/// Karbantartási üzemmód
class SessionMaintenance extends SessionState {}

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
