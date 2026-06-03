import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_config.dart';

// ============================================================
// AppConfigRepository (Admin) – app_config tábla kezelése  [M5]
// ============================================================

class AppConfigRepository {
  final SupabaseClient _db;

  AppConfigRepository({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  /// Összes konfig bejegyzés lekérése (rendezett)
  Future<List<AppConfigEntry>> fetchAll() async {
    final res = await _db
        .from('app_config')
        .select()
        .order('key', ascending: true);

    return (res as List)
        .map((r) => AppConfigEntry.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Egyetlen érték frissítése
  Future<void> updateEntry(String key, String value) async {
    await _db.from('app_config').upsert({
      'key':        key,
      'value':      value,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'updated_by': _db.auth.currentUser?.id,
    });
  }

  /// Feature flag toggle
  Future<void> setFlag(String key, bool value) async {
    await updateEntry(key, value.toString());
  }

  /// Karbantartás mód vezérlése
  Future<void> setMaintenanceMode(
    bool enabled, {
    String? title,
    String? message,
  }) async {
    final updates = <Map<String, dynamic>>[
      {
        'key':        'maintenance_mode',
        'value':      enabled.toString(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'updated_by': _db.auth.currentUser?.id,
      },
    ];

    if (title != null) {
      updates.add({
        'key':        'maintenance_title',
        'value':      title,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'updated_by': _db.auth.currentUser?.id,
      });
    }

    if (message != null) {
      updates.add({
        'key':        'maintenance_message',
        'value':      message,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'updated_by': _db.auth.currentUser?.id,
      });
    }

    await _db.from('app_config').upsert(updates);
  }

  /// App verzió frissítése
  Future<void> updateVersions({
    String? minIos,
    String? minAndroid,
    String? latestIos,
    String? latestAndroid,
    String? storeUrlIos,
    String? storeUrlAndroid,
  }) async {
    final updates = <Map<String, dynamic>>[];
    void add(String key, String? value) {
      if (value != null) {
        updates.add({
          'key':        key,
          'value':      value,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'updated_by': _db.auth.currentUser?.id,
        });
      }
    }

    add('min_app_version_ios',      minIos);
    add('min_app_version_android',  minAndroid);
    add('latest_app_version_ios',   latestIos);
    add('latest_app_version_android', latestAndroid);
    add('app_store_url_ios',        storeUrlIos);
    add('app_store_url_android',    storeUrlAndroid);

    if (updates.isNotEmpty) {
      await _db.from('app_config').upsert(updates);
    }
  }
}
