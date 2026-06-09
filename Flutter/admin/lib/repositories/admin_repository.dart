import 'package:skeleton_shared/skeleton_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/admin_stats.dart';
import '../models/ai_model.dart';

// ============================================================
// AdminRepository – admin-only Supabase műveletek
// Csak admin role-lal rendelkező felhasználók számára!
// ============================================================

class AdminRepository {
  final SupabaseClient _db;

  AdminRepository({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  // ── Statisztikák ─────────────────────────────────────────
  // Párhuzamos fetch + kliens oldali aggregálás.
  // count().filter() láncolás nem támogatott supabase_flutter v2-ben,
  // ezért a szűrést Dart-ban végezzük a visszakapott listákon.
  Future<AdminStats> getStats() async {
    final results = await Future.wait([
      _db.from('user_profiles').select('id, created_at'),
      _db.from('items').select('id, is_active'),
    ]);
    final usersRes = results[0];
    final itemsRes = results[1];

    final now       = DateTime.now().toUtc();
    final todayStart = DateTime.utc(now.year, now.month, now.day);
    final weekStart  = todayStart.subtract(const Duration(days: 7));

    int newToday = 0, newWeek = 0;
    for (final u in usersRes) {
      final created = DateTime.tryParse(u['created_at'] as String? ?? '');
      if (created == null) continue;
      if (created.isAfter(todayStart)) newToday++;
      if (created.isAfter(weekStart))  newWeek++;
    }

    final activeItems = itemsRes
        .where((i) => i['is_active'] == true)
        .length;

    return AdminStats(
      totalUsers:       usersRes.length,
      newUsersToday:    newToday,
      newUsersThisWeek: newWeek,
      totalItems:       itemsRes.length,
      activeItems:      activeItems,
    );
  }

  // ── Felhasználók ─────────────────────────────────────────
  Future<List<UserProfile>> getAllUsers({String? search}) async {
    var query = _db
        .from('user_profiles')
        .select()
        .order('created_at', ascending: false);

    final res = await query;
    final users = (res as List).map((j) => UserProfile.fromJson(j)).toList();

    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      return users.where((u) =>
          u.email.toLowerCase().contains(q) ||
          (u.displayName?.toLowerCase().contains(q) ?? false)).toList();
    }
    return users;
  }

  Future<UserProfile?> getUser(String userId) async {
    try {
      final res = await _db
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .single();
      return UserProfile.fromJson(res);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateUserRole(String userId, String role) async {
    await _db
        .from('user_profiles')
        .update({'role': role, 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', userId);
  }

  Future<void> updateUserDisplayName(String userId, String displayName) async {
    await _db
        .from('user_profiles')
        .update({'display_name': displayName, 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', userId);
  }

  // ── Fordítások ───────────────────────────────────────────
  Future<List<TranslationEntry>> fetchAllTranslations() async {
    final response = await _db
        .from('translations')
        .select('key, hu, en, locales')
        .order('key');
    return (response as List).map((t) => TranslationEntry.fromJson(t)).toList();
  }

  Future<void> createTranslation(TranslationEntry entry) async {
    await _db.from('translations').insert({
      'key': entry.key,
      'hu': entry.hu,
      'en': entry.en,
      'locales': entry.locales,
    });
  }

  Future<void> updateTranslation(String oldKey, TranslationEntry entry) async {
    await _db.from('translations').update({
      'key': entry.key,
      'hu': entry.hu,
      'en': entry.en,
      'locales': entry.locales,
    }).eq('key', oldKey);
  }

  Future<void> deleteTranslation(String key) async {
    await _db.from('translations').delete().eq('key', key);
  }

  /// A kódba ágyazott (offline) fordítási kulcsok beszúrása a `translations`
  /// táblába, ha még nincsenek ott. Így az AI nyelv-generálás a pre-login
  /// oldalak (login, maintenance, …) szövegeit is lefordítja.
  /// A már létező kulcsokat NEM írja felül (admin szerkesztések megmaradnak).
  /// Visszaadja a ténylegesen beszúrt kulcsok számát.
  Future<int> seedMissingCodebaseTranslations(
      Map<String, Map<String, String>> codebase) async {
    final existing = await _db.from('translations').select('key');
    final existingKeys =
        (existing as List).map((e) => (e as Map)['key'] as String).toSet();

    final toInsert = <Map<String, dynamic>>[];
    codebase.forEach((key, vals) {
      if (!existingKeys.contains(key)) {
        toInsert.add({
          'key': key,
          'hu': vals['hu'] ?? '',
          'en': vals['en'] ?? '',
          'locales': <String, dynamic>{},
        });
      }
    });

    if (toInsert.isNotEmpty) {
      await _db.from('translations').insert(toInsert);
    }
    return toInsert.length;
  }

  // ── Dokumentumok ──────────────────────────────────────────
  Future<List<LegalDocument>> fetchAllLegalDocuments() async {
    final response = await _db
        .from('legal_documents')
        .select()
        .order('id');
    return (response as List).map((d) => LegalDocument.fromJson(d)).toList();
  }

  Future<void> updateLegalDocument(LegalDocument doc) async {
    if (doc.isActive) {
      // Deaktiváljuk az ugyanolyan típusú dokumentum összes többi verzióját,
      // de a most mentendő verziót NEM (azt az upsert állítja be).
      await _db
          .from('legal_documents')
          .update({'is_active': false})
          .eq('id', doc.id)
          .neq('version', doc.version);
    }
    final data = {
      'id': doc.id,
      'version': doc.version,
      'title_locales': doc.titleLocales,
      'content_locales': doc.contentLocales,
      'is_active': doc.isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    await _db
        .from('legal_documents')
        .upsert(data, onConflict: 'id, version');
  }

  // ── app_settings ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchAppSettings() async {
    final res = await _db.from('app_settings').select().order('id');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> getAppSetting(String id) async {
    try {
      final res = await _db.from('app_settings').select().eq('id', id).single();
      return res;
    } catch (_) {
      return null;
    }
  }

  Future<void> updateAppSetting(String id, String value, String description) async {
    await _db.from('app_settings').upsert({
      'id': id,
      'value': value,
      'description': description,
    }, onConflict: 'id');
  }

  // ── AI Models ─────────────────────────────────────────────────
  Future<List<AiModel>> fetchAiModels() async {
    final res = await _db
        .from('ai_models')
        .select()
        .order('created_at', ascending: true);
    return (res as List).map((m) => AiModel.fromJson(m)).toList();
  }

  Future<void> createAiModel(Map<String, dynamic> data) async {
    await _db.from('ai_models').insert(data);
  }

  Future<void> updateAiModel(String id, Map<String, dynamic> data) async {
    await _db.from('ai_models').update(data).eq('id', id);
  }

  Future<void> deleteAiModel(String id) async {
    await _db.from('ai_models').delete().eq('id', id);
  }

  Future<void> setDefaultAiModel(String id) async {
    // Előbb töröljük az összes default jelölést, majd beállítjuk az újat.
    await _db.from('ai_models').update({'is_default': false});
    await _db.from('ai_models').update({'is_default': true}).eq('id', id);
  }

  // ── Cost Stats ────────────────────────────────────────────────
  Future<Map<String, dynamic>> fetchCostStats() async {
    try {
      final result = await _db.rpc('get_admin_cost_stats');
      final data = result as Map?;
      if (data == null) return _emptyCostStats();
      return {
        'gpt_cost_today':      (data['gpt_cost_today'] as num?)?.toDouble() ?? 0.0,
        'gpt_cost_month':      (data['gpt_cost_month'] as num?)?.toDouble() ?? 0.0,
        'total_cost_today':    (data['total_cost_today'] as num?)?.toDouble() ?? 0.0,
        'total_cost_month':    (data['total_cost_month'] as num?)?.toDouble() ?? 0.0,
        'input_tokens_month':  (data['input_tokens_month'] as num?)?.toInt() ?? 0,
        'output_tokens_month': (data['output_tokens_month'] as num?)?.toInt() ?? 0,
      };
    } catch (_) {
      return _emptyCostStats();
    }
  }

  Map<String, dynamic> _emptyCostStats() => {
        'gpt_cost_today': 0.0,
        'gpt_cost_month': 0.0,
        'total_cost_today': 0.0,
        'total_cost_month': 0.0,
        'input_tokens_month': 0,
        'output_tokens_month': 0,
      };

  // ── Logs ──────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchAppErrorLogs({int limit = 200}) async {
    final res = await _db
        .from('app_error_logs')
        .select('id, created_at, app, error_type, error_message, context, user_id')
        .order('created_at', ascending: false)
        .limit(limit);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchGptLogs({int limit = 200}) async {
    final res = await _db
        .from('gpt_usage_logs')
        .select('id, created_at, model, input_tokens, output_tokens, cost_usd, user_id')
        .order('created_at', ascending: false)
        .limit(limit);
    return (res as List).cast<Map<String, dynamic>>();
  }

  // ── Push Notifications ────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchPushLogs({int limit = 100}) async {
    final res = await _db
        .from('push_notification_logs')
        .select('id, created_at, target_group, title, body, status, error_message, tokens_count')
        .order('created_at', ascending: false)
        .limit(limit);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<int> fetchPushTokenCount() async {
    try {
      final res = await _db.from('user_push_tokens').select('id');
      return (res as List).length;
    } catch (_) {
      return 0;
    }
  }
}

