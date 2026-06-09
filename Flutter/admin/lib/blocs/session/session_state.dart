import 'package:skeleton_shared/skeleton_shared.dart';
import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

/// Nincs bejelentkezett felhasználó (opcionális force-logout üzenet)
class SessionLoggedOut extends SessionState {
  final String? message;
  const SessionLoggedOut({this.message});
  @override
  List<Object?> get props => [message];
}

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

/// Bejelentkezés után elfogadandó jogi dokumentumok vannak
class SessionAcceptLegal extends SessionState {
  final User user;
  final UserProfile profile;
  final List<LegalDocument> pendingDocuments;

  const SessionAcceptLegal(this.user, this.profile, this.pendingDocuments);

  @override
  List<Object?> get props => [user.id, profile, pendingDocuments];
}
