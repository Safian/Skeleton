import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_session.dart';

// ============================================================
// SessionRepository (Admin) – user_sessions tábla olvasása  [M6]
// ============================================================

class SessionRepository {
  final SupabaseClient _db;

  SessionRepository({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  /// Összes aktív session lekérése (felhasználói adatokkal)
  Future<List<UserSession>> fetchActiveSessions({int limit = 200}) async {
    // user_sessions tábla + user_profiles JOIN (display_name, email)
    final res = await _db
        .from('user_sessions')
        .select('''
          *,
          user_profiles!user_id(display_name, email)
        ''')
        .eq('is_active', true)
        .order('last_seen_at', ascending: false)
        .limit(limit);

    return (res as List).map((r) {
      final map = Map<String, dynamic>.from(r as Map);
      // Egyszerűsítés – nested JSON kicsomagolása
      map['display_name'] = (r['user_profiles'] as Map?)?['display_name'];
      map['user_email']   = (r['user_profiles'] as Map?)?['email'];
      return UserSession.fromJson(map);
    }).toList();
  }

  /// Egy felhasználó összes session-je
  Future<List<UserSession>> fetchUserSessions(String userId) async {
    final res = await _db
        .from('user_sessions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);

    return (res as List)
        .map((r) => UserSession.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Session visszavonása
  Future<void> revokeSession(String sessionId) async {
    await _db.rpc('revoke_session', params: {'session_id': sessionId});
  }

  /// Aggregált statisztikák
  Future<Map<String, dynamic>> fetchStats() async {
    final res = await _db.rpc('get_session_stats');
    return (res as Map<String, dynamic>?) ?? {};
  }

  /// OS megoszlás az összes session-ből (pl. pie charthoz)
  Future<Map<String, int>> fetchOsBreakdown() async {
    final res = await _db
        .from('user_sessions')
        .select('os_name')
        .eq('is_active', true);

    final counts = <String, int>{};
    for (final row in res as List) {
      final os = (row as Map)['os_name'] as String? ?? 'Unknown';
      counts[os] = (counts[os] ?? 0) + 1;
    }
    return counts;
  }

  /// Verzió megoszlás
  Future<Map<String, int>> fetchVersionBreakdown() async {
    final res = await _db
        .from('user_sessions')
        .select('app_version')
        .eq('is_active', true);

    final counts = <String, int>{};
    for (final row in res as List) {
      final ver = (row as Map)['app_version'] as String? ?? 'Unknown';
      counts[ver] = (counts[ver] ?? 0) + 1;
    }
    return counts;
  }
}
