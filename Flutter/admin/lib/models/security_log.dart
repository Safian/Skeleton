import 'package:equatable/equatable.dart';

enum SecurityEventType {
  bruteForce,
  successfulSshLogin,
  rateLimitExceeded,
  portScan,
  banned,
  unbanned,
  unknown;

  static SecurityEventType fromString(String value) => switch (value) {
        'brute_force'           => bruteForce,
        'successful_ssh_login'  => successfulSshLogin,
        'rate_limit_exceeded'   => rateLimitExceeded,
        'port_scan'             => portScan,
        'banned'                => banned,
        'unbanned'              => unbanned,
        _                       => unknown,
      };

  String get label => switch (this) {
        bruteForce          => 'Brute Force',
        successfulSshLogin  => 'SSH Belépés',
        rateLimitExceeded   => 'Rate Limit',
        portScan            => 'Port Scan',
        banned              => 'IP Tiltva',
        unbanned            => 'IP Feloldva',
        unknown             => 'Ismeretlen',
      };
}

class SecurityLog extends Equatable {
  const SecurityLog({
    required this.id,
    required this.createdAt,
    required this.timestamp,
    required this.source,
    required this.eventType,
    this.ipAddress,
    this.description,
    required this.isResolved,
    this.resolvedAt,
    this.metadata,
  });

  final String id;
  final DateTime createdAt;
  final DateTime timestamp;
  final String source;
  final SecurityEventType eventType;
  final String? ipAddress;
  final String? description;
  final bool isResolved;
  final DateTime? resolvedAt;
  final Map<String, dynamic>? metadata;

  factory SecurityLog.fromJson(Map<String, dynamic> json) => SecurityLog(
        id:          json['id'] as String,
        createdAt:   DateTime.parse(json['created_at'] as String),
        timestamp:   DateTime.parse(json['timestamp'] as String),
        source:      json['source'] as String,
        eventType:   SecurityEventType.fromString(json['event_type'] as String),
        ipAddress:   json['ip_address'] as String?,
        description: json['description'] as String?,
        isResolved:  (json['is_resolved'] as bool?) ?? false,
        resolvedAt:  json['resolved_at'] != null
            ? DateTime.parse(json['resolved_at'] as String)
            : null,
        metadata:    (json['metadata'] as Map<String, dynamic>?),
      );

  @override
  List<Object?> get props => [id];
}

class BannedIp extends Equatable {
  const BannedIp({
    required this.id,
    required this.ipAddress,
    required this.bannedAt,
    this.reason,
    this.jail,
    this.isActive = true,
  });

  final String id;
  final String ipAddress;
  final DateTime bannedAt;
  final String? reason;
  final String? jail;
  final bool isActive;

  factory BannedIp.fromJson(Map<String, dynamic> json) => BannedIp(
        id:        json['id'] as String,
        ipAddress: json['ip_address'] as String,
        bannedAt:  DateTime.parse(json['banned_at'] as String),
        reason:    json['reason'] as String?,
        jail:      json['jail'] as String?,
        isActive:  (json['is_active'] as bool?) ?? true,
      );

  @override
  List<Object?> get props => [id];
}

class SecurityStats extends Equatable {
  const SecurityStats({
    required this.totalEvents,
    required this.unresolvedEvents,
    required this.eventsToday,
    required this.bruteForceCount,
    required this.sshLoginCount,
    required this.activeBans,
    this.topAttackerIp,
  });

  final int totalEvents;
  final int unresolvedEvents;
  final int eventsToday;
  final int bruteForceCount;
  final int sshLoginCount;
  final int activeBans;
  final String? topAttackerIp;

  factory SecurityStats.fromJson(Map<String, dynamic> json) => SecurityStats(
        totalEvents:      (json['total_events']      as num?)?.toInt() ?? 0,
        unresolvedEvents: (json['unresolved_events'] as num?)?.toInt() ?? 0,
        eventsToday:      (json['events_today']      as num?)?.toInt() ?? 0,
        bruteForceCount:  (json['brute_force_count'] as num?)?.toInt() ?? 0,
        sshLoginCount:    (json['ssh_login_count']   as num?)?.toInt() ?? 0,
        activeBans:       (json['active_bans']       as num?)?.toInt() ?? 0,
        topAttackerIp:    json['top_attacker_ip'] as String?,
      );

  static SecurityStats empty() => const SecurityStats(
        totalEvents: 0, unresolvedEvents: 0, eventsToday: 0,
        bruteForceCount: 0, sshLoginCount: 0, activeBans: 0,
      );

  @override
  List<Object?> get props => [totalEvents, activeBans, eventsToday];
}
