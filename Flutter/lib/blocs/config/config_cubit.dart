import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../repositories/config_repository.dart';
import 'config_state.dart';

// ============================================================
// ConfigCubit – Remote Config kezelő  [M5]
//
// Felelős:
//  1. App indulásakor (Splash alatt) konfig lekérése
//  2. Maintenance mode detektálása
//  3. Verzióellenőrzés (force / soft update)
//  4. Feature flagek elérhetővé tétele az egész appban
// ============================================================

class ConfigCubit extends Cubit<ConfigState> {
  final ConfigRepository _repo;

  ConfigCubit({required ConfigRepository repository})
      : _repo = repository,
        super(const ConfigState());

  // ── Konfig betöltése ───────────────────────────────────────

  Future<void> load() async {
    emit(state.copyWith(status: ConfigStatus.loading, clearError: true));

    try {
      final config = await _repo.fetchConfig();
      final updateStatus = await _resolveUpdateStatus(config);

      emit(state.copyWith(
        status:       ConfigStatus.loaded,
        config:       config,
        updateStatus: updateStatus,
      ));
    } catch (e) {
      debugPrint('[ConfigCubit] load error: $e');
      // Hiba esetén defaults-szal folytatjuk – az app nem állhat meg
      emit(state.copyWith(
        status:      ConfigStatus.loaded,
        updateStatus: UpdateStatus.none,
        error:        e.toString(),
      ));
    }
  }

  // ── Verzió összehasonlítás ─────────────────────────────────

  Future<UpdateStatus> _resolveUpdateStatus(dynamic config) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version; // pl. '1.2.3'

      // Futó platform alapján a megfelelő min/latest verziót választjuk
      final isIos = defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS;

      final minVersion = isIos
          ? config.minVersionIos
          : config.minVersionAndroid;

      final latestVersion = isIos
          ? config.latestVersionIos
          : config.latestVersionAndroid;

      // Force update – ha a jelenlegi verzió kisebb a minimálisan elfogadhatónál
      if (_compareVersions(current, minVersion) < 0) {
        return UpdateStatus.force;
      }

      // Soft update – ha van újabb verzió, de még futhat a régi
      if (_compareVersions(current, latestVersion) < 0) {
        return UpdateStatus.soft;
      }

      return UpdateStatus.none;
    } catch (e) {
      debugPrint('[ConfigCubit] version check error: $e');
      return UpdateStatus.none;
    }
  }

  /// Semantic version összehasonlítás.
  /// Visszatérési érték: -1 (a < b), 0 (a == b), 1 (a > b)
  int _compareVersions(String a, String b) {
    final pa = _parseParts(a);
    final pb = _parseParts(b);
    for (int i = 0; i < 3; i++) {
      if (pa[i] < pb[i]) return -1;
      if (pa[i] > pb[i]) return 1;
    }
    return 0;
  }

  List<int> _parseParts(String v) {
    final parts = v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    while (parts.length < 3) parts.add(0);
    return parts.take(3).toList();
  }

  // ── Admin-oldali frissítések ───────────────────────────────

  /// Karbantartás mód be/ki kapcsolása (admin)
  Future<void> setMaintenanceMode(bool enabled, {String? message}) async {
    await _repo.setMaintenanceMode(enabled, message: message);
    await load(); // Újra töltjük a konfig-ot
  }

  /// Feature flag módosítása (admin)
  Future<void> setFeatureFlag(String key, bool value) async {
    await _repo.setFeatureFlag(key, value);
    await load();
  }

  /// Egyedi konfig érték módosítása (admin)
  Future<void> updateConfigValue(String key, String value) async {
    await _repo.updateConfig(key, value);
    await load();
  }
}
