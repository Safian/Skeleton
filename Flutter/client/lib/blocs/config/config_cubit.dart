import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:skeleton_shared/skeleton_shared.dart';
import 'config_state.dart';

// ============================================================
// ConfigCubit – Remote Config kezelő  [M5]
//
// Felelős:
//  1. App indulásakor (Splash alatt) RemoteConfig betöltése
//  2. Maintenance mode detektálása
//  3. Verzióellenőrzés (force / soft update)
//
// Feature flag-ek olvasásához közvetlenül:
//   RemoteConfig.instance.flag('feature_name')
// ============================================================

class ConfigCubit extends Cubit<ConfigState> {
  ConfigCubit() : super(const ConfigState());

  // ── Konfig betöltése ───────────────────────────────────────

  Future<void> load() async {
    emit(state.copyWith(status: ConfigStatus.loading, clearError: true));

    try {
      await RemoteConfig.instance.load();
      final updateStatus = await _resolveUpdateStatus();

      emit(state.copyWith(
        status:       ConfigStatus.loaded,
        updateStatus: updateStatus,
      ));
    } catch (e) {
      debugPrint('[ConfigCubit] load error: $e');
      emit(state.copyWith(
        status:       ConfigStatus.loaded,
        updateStatus: UpdateStatus.none,
        error:        e.toString(),
      ));
    }
  }

  // ── Verzió összehasonlítás ─────────────────────────────────

  Future<UpdateStatus> _resolveUpdateStatus() async {
    try {
      final info    = await PackageInfo.fromPlatform();
      final current = info.version;

      final isIos = defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS;

      final minVersion    = isIos
          ? RemoteConfig.instance.minVersionIos
          : RemoteConfig.instance.minVersionAndroid;
      final latestVersion = isIos
          ? RemoteConfig.instance.latestVersionIos
          : RemoteConfig.instance.latestVersionAndroid;

      if (_compareVersions(current, minVersion) < 0) return UpdateStatus.force;
      if (_compareVersions(current, latestVersion) < 0) return UpdateStatus.soft;
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
    while (parts.length < 3) { parts.add(0); }
    return parts.take(3).toList();
  }
}
