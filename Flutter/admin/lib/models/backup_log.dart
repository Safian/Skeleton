import 'package:equatable/equatable.dart';

class BackupLog extends Equatable {
  final String id;
  final DateTime createdAt;
  final String backupType;
  final String status;
  final int? durationSecs;
  final int? sizeBytes;
  final String? s3Path;
  final String? errorMessage;
  final String triggeredBy;

  const BackupLog({
    required this.id,
    required this.createdAt,
    required this.backupType,
    required this.status,
    this.durationSecs,
    this.sizeBytes,
    this.s3Path,
    this.errorMessage,
    required this.triggeredBy,
  });

  bool get isSuccess => status == 'success';
  bool get isFailed  => status == 'failed';
  bool get isRunning => status == 'running';

  String get sizeFormatted {
    if (sizeBytes == null) return '-';
    final mb = sizeBytes! / (1024 * 1024);
    if (mb < 1) return '${(sizeBytes! / 1024).toStringAsFixed(1)} KB';
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    return '${(mb / 1024).toStringAsFixed(2)} GB';
  }

  factory BackupLog.fromJson(Map<String, dynamic> json) => BackupLog(
        id:            json['id'] as String,
        createdAt:     DateTime.parse(json['created_at'] as String),
        backupType:    json['backup_type'] as String,
        status:        json['status'] as String,
        durationSecs:  json['duration_secs'] as int?,
        sizeBytes:     json['size_bytes'] as int?,
        s3Path:        json['s3_path'] as String?,
        errorMessage:  json['error_message'] as String?,
        triggeredBy:   json['triggered_by'] as String? ?? 'cron',
      );

  @override
  List<Object?> get props => [id, status, createdAt];
}

class ResourceSnapshot extends Equatable {
  final String id;
  final DateTime recordedAt;
  final double? cpuPercent;
  final int? ramUsedMb;
  final int? ramTotalMb;
  final double? diskUsedGb;
  final double? diskTotalGb;
  final double? diskPercent;

  const ResourceSnapshot({
    required this.id,
    required this.recordedAt,
    this.cpuPercent,
    this.ramUsedMb,
    this.ramTotalMb,
    this.diskUsedGb,
    this.diskTotalGb,
    this.diskPercent,
  });

  double get ramPercent {
    if (ramTotalMb == null || ramTotalMb == 0) return 0;
    return (ramUsedMb ?? 0) / ramTotalMb! * 100;
  }

  factory ResourceSnapshot.fromJson(Map<String, dynamic> json) => ResourceSnapshot(
        id:          json['id'] as String,
        recordedAt:  DateTime.parse(json['recorded_at'] as String),
        cpuPercent:  (json['cpu_percent'] as num?)?.toDouble(),
        ramUsedMb:   json['ram_used_mb'] as int?,
        ramTotalMb:  json['ram_total_mb'] as int?,
        diskUsedGb:  (json['disk_used_gb'] as num?)?.toDouble(),
        diskTotalGb: (json['disk_total_gb'] as num?)?.toDouble(),
        diskPercent: (json['disk_percent'] as num?)?.toDouble(),
      );

  @override
  List<Object?> get props => [id, recordedAt];
}
