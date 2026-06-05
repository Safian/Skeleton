import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_config.dart';

// ============================================================
// ConfigRepository – app_config tábla olvasása
// ============================================================

class ConfigRepository {
  final SupabaseClient _db;

  ConfigRepository({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  /// Teljes konfig map lekérése (RPC-vel egy menetben)
  Future<AppConfig> fetchConfig() async {
    try {
      final result = await _db.rpc('get_app_config_map');
      if (result is Map<String, dynamic>) {
        return AppConfig.fromMap(result);
      }
      return AppConfig.defaults;
    } catch (e) {
      debugPrint('[ConfigRepository] fetchConfig failed: $e');
      return AppConfig.defaults;
    }
  }

  /// Egyetlen konfig érték frissítése (admin)
  Future<void> updateConfig(String key, String value) async {
    await _db.from('app_config').upsert({
      'key':   key,
      'value': value,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Karbantartás mód be/ki kapcsolása
  Future<void> setMaintenanceMode(bool enabled, {String? message}) async {
    await _db.from('app_config').upsert([
      {'key': 'maintenance_mode', 'value': enabled.toString()},
      if (message != null)
        {'key': 'maintenance_message', 'value': message},
    ]);
  }

  /// Feature flag frissítése
  Future<void> setFeatureFlag(String flagKey, bool value) async {
    await _db.from('app_config').upsert({
      'key':   flagKey,
      'value': value.toString(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
