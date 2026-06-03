import 'package:equatable/equatable.dart';
import '../../models/user_session.dart';

// ============================================================
// SessionsState – Admin Session kezelő állapotgép  [M6]
// ============================================================

enum SessionsStatus { initial, loading, loaded, error }

class SessionsState extends Equatable {
  final SessionsStatus status;
  final List<UserSession> sessions;
  final Map<String, int> osBreakdown;
  final Map<String, int> versionBreakdown;
  final Map<String, dynamic> stats;
  final String? error;
  final Set<String> revoking; // éppen visszavonás alatt álló session ID-k

  const SessionsState({
    this.status           = SessionsStatus.initial,
    this.sessions         = const [],
    this.osBreakdown      = const {},
    this.versionBreakdown = const {},
    this.stats            = const {},
    this.error,
    this.revoking         = const {},
  });

  bool get isLoading => status == SessionsStatus.loading;

  int get activeSessions   => sessions.where((s) => s.isActive).length;
  int get totalSessions    => sessions.length;

  SessionsState copyWith({
    SessionsStatus?        status,
    List<UserSession>?     sessions,
    Map<String, int>?      osBreakdown,
    Map<String, int>?      versionBreakdown,
    Map<String, dynamic>?  stats,
    String?                error,
    Set<String>?           revoking,
    bool                   clearError = false,
  }) {
    return SessionsState(
      status:           status           ?? this.status,
      sessions:         sessions         ?? this.sessions,
      osBreakdown:      osBreakdown      ?? this.osBreakdown,
      versionBreakdown: versionBreakdown ?? this.versionBreakdown,
      stats:            stats            ?? this.stats,
      error:            clearError ? null : (error ?? this.error),
      revoking:         revoking         ?? this.revoking,
    );
  }

  @override
  List<Object?> get props =>
      [status, sessions, osBreakdown, versionBreakdown, stats, error, revoking];
}
