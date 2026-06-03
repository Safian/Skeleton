import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bug_report.dart';

// ============================================================
// BugReportRepository (Admin) – bug_reports tábla kezelése  [M7]
// ============================================================

class BugReportRepository {
  final SupabaseClient _db;

  BugReportRepository({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  /// Bugok lekérése szűrőkkel
  Future<List<BugReport>> fetchReports({
    String? status,
    String? priority,
    int limit = 100,
  }) async {
    var query = _db.from('bug_reports').select();

    if (status != null) {
      query = query.eq('status', status);
    }
    if (priority != null) {
      query = query.eq('priority', priority);
    }

    final res = await query
        .order('created_at', ascending: false)
        .limit(limit);
    return (res as List)
        .map((r) => BugReport.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Bug státuszának frissítése
  Future<void> updateStatus(
    String bugId,
    String status, {
    String? notes,
  }) async {
    await _db.rpc('update_bug_status', params: {
      'p_bug_id': bugId,
      'p_status': status,
      if (notes != null) 'p_notes': notes,
    });
  }

  /// Bug törlése (admin)
  Future<void> deleteBug(String bugId) async {
    await _db.from('bug_reports').delete().eq('id', bugId);
  }
}
