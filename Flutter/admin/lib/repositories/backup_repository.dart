import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/backup_log.dart';

class BackupRepository {
  final SupabaseClient _db;
  BackupRepository({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  Future<List<BackupLog>> getBackupLogs({int limit = 50}) async {
    final res = await _db
        .from('backup_logs')
        .select()
        .order('created_at', ascending: false)
        .limit(limit) as List<dynamic>;
    return res
        .map((e) => BackupLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ResourceSnapshot>> getResourceSnapshots({int limit = 96}) async {
    // 96 * 15 perc = 24 óra
    final res = await _db
        .from('resource_snapshots')
        .select()
        .order('recorded_at', ascending: true)
        .limit(limit) as List<dynamic>;
    return res
        .map((e) => ResourceSnapshot.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Manuális backup indítása (security-unban mintájára, egy trigger endpoint-on keresztül)
  Future<void> triggerManualBackup() async {
    final response = await _db.functions.invoke(
      'trigger-backup',
      body: {'triggered_by': 'manual'},
    );
    if (response.status != 200 && response.status != 201 && response.status != 202) {
      final data = response.data as Map<String, dynamic>?;
      throw Exception(data?['error'] ?? 'Backup trigger sikertelen');
    }
  }
}
