part of 'security_cubit.dart';

enum SecurityStatus { initial, loading, loaded, error }

class SecurityState extends Equatable {
  const SecurityState({
    this.status    = SecurityStatus.initial,
    this.stats,
    this.logs      = const [],
    this.bannedIps = const [],
    this.error,
    this.unbanning,
  });

  final SecurityStatus status;
  final SecurityStats? stats;
  final List<SecurityLog> logs;
  final List<BannedIp> bannedIps;
  final String? error;
  final String? unbanning; // az éppen unban alatt lévő IP

  SecurityState copyWith({
    SecurityStatus? status,
    SecurityStats? stats,
    List<SecurityLog>? logs,
    List<BannedIp>? bannedIps,
    String? error,
    String? unbanning,
  }) =>
      SecurityState(
        status:    status    ?? this.status,
        stats:     stats     ?? this.stats,
        logs:      logs      ?? this.logs,
        bannedIps: bannedIps ?? this.bannedIps,
        error:     error,
        unbanning: unbanning,
      );

  @override
  List<Object?> get props => [status, stats, logs, bannedIps, error, unbanning];
}
