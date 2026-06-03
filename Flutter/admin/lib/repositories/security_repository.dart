import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/security_log.dart';

class SecurityRepository {
  SecurityRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // ── Stats ────────────────────────────────────────────────────

  Future<SecurityStats> getStats() async {
    final result = await _client.rpc('get_security_stats');
    return SecurityStats.fromJson(result as Map<String, dynamic>);
  }

  // ── Logs ────────────────────────────────────────────────────

  Future<List<SecurityLog>> getLogs({
    int limit = 50,
    int offset = 0,
    String? eventTypeFilter,
    String? sourceFilter,
    String? ipFilter,
    bool? resolvedFilter,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    var query = _client.from('security_logs').select();

    if (eventTypeFilter != null) {
      query = query.eq('event_type', eventTypeFilter);
    }
    if (sourceFilter != null) {
      query = query.eq('source', sourceFilter);
    }
    if (resolvedFilter != null) {
      query = query.eq('is_resolved', resolvedFilter);
    }
    if (ipFilter != null && ipFilter.isNotEmpty) {
      query = query.ilike('ip_address', '%$ipFilter%');
    }
    if (fromDate != null) {
      query = query.gte('created_at', fromDate.toIso8601String());
    }
    if (toDate != null) {
      query = query.lte('created_at', toDate.toIso8601String());
    }

    final data = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1) as List<dynamic>;
    return data
        .map((e) => SecurityLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> resolveLog(String logId) async {
    await _client.rpc('resolve_security_log', params: {'log_id': logId});
  }

  // ── Banned IPs ───────────────────────────────────────────────

  Future<List<BannedIp>> getBannedIps() async {
    final data = await _client
        .from('banned_ips')
        .select()
        .eq('is_active', true)
        .order('banned_at', ascending: false) as List<dynamic>;

    return data
        .map((e) => BannedIp.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Unban: Supabase edge function hívása
  Future<void> unbanIp(String ipAddress, {String? jail}) async {
    final session = _client.auth.currentSession;
    if (session == null) throw Exception('Not authenticated');

    final response = await _client.functions.invoke(
      'security-unban',
      body: {
        'ip_address': ipAddress,
        if (jail != null) 'jail': jail,
      },
    );

    if (response.status != 200) {
      throw Exception('Unban sikertelen: ${response.data}');
    }
  }

  // ── Realtime ─────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> watchLogs() {
    return _client
        .from('security_logs')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(100);
  }
}
