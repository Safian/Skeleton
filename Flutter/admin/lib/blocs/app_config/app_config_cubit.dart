import 'package:bloc/bloc.dart';
import '../../repositories/app_config_repository.dart';
import 'app_config_state.dart';

// ============================================================
// AppConfigCubit – Admin Remote Config kezelő  [M5]
// ============================================================

class AppConfigCubit extends Cubit<AppConfigState> {
  final AppConfigRepository _repo;

  AppConfigCubit({required AppConfigRepository repository})
      : _repo = repository,
        super(const AppConfigState());

  Future<void> load() async {
    emit(state.copyWith(status: AppConfigStatus.loading, clearError: true));
    try {
      final entries = await _repo.fetchAll();
      emit(state.copyWith(status: AppConfigStatus.loaded, entries: entries));
    } catch (e) {
      emit(state.copyWith(status: AppConfigStatus.error, error: e.toString()));
    }
  }

  // ── Karbantartás mód ──────────────────────────────────────

  Future<void> setMaintenanceMode(
    bool enabled, {
    String? title,
    String? message,
  }) async {
    emit(state.copyWith(status: AppConfigStatus.saving, savingKey: 'maintenance_mode'));
    try {
      await _repo.setMaintenanceMode(enabled, title: title, message: message);
      await load();
    } catch (e) {
      emit(state.copyWith(
        status:    AppConfigStatus.error,
        error:     'Karbantartás mód frissítési hiba: $e',
        clearSavingKey: true,
      ));
    }
  }

  // ── Feature flag ──────────────────────────────────────────

  Future<void> setFlag(String key, bool value) async {
    emit(state.copyWith(status: AppConfigStatus.saving, savingKey: key));
    try {
      await _repo.setFlag(key, value);

      // Optimista UI frissítés
      final updated = state.entries.map((e) {
        if (e.key == key) return e.copyWith(value: value.toString());
        return e;
      }).toList();
      emit(state.copyWith(
        status:        AppConfigStatus.loaded,
        entries:       updated,
        clearSavingKey: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        status:         AppConfigStatus.error,
        error:          'Flag frissítési hiba: $e',
        clearSavingKey: true,
      ));
      await load(); // Visszaállítás szerver értékre
    }
  }

  // ── Egyedi érték frissítése ───────────────────────────────

  Future<void> updateEntry(String key, String value) async {
    emit(state.copyWith(status: AppConfigStatus.saving, savingKey: key));
    try {
      await _repo.updateEntry(key, value);

      final updated = state.entries.map((e) {
        if (e.key == key) return e.copyWith(value: value);
        return e;
      }).toList();
      emit(state.copyWith(
        status:         AppConfigStatus.loaded,
        entries:        updated,
        clearSavingKey: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        status:         AppConfigStatus.error,
        error:          'Konfig frissítési hiba: $e',
        clearSavingKey: true,
      ));
    }
  }

  // ── Verziók frissítése ────────────────────────────────────

  Future<void> updateVersions({
    String? minIos,
    String? minAndroid,
    String? latestIos,
    String? latestAndroid,
    String? storeUrlIos,
    String? storeUrlAndroid,
  }) async {
    emit(state.copyWith(status: AppConfigStatus.saving, savingKey: 'versions'));
    try {
      await _repo.updateVersions(
        minIos:        minIos,
        minAndroid:    minAndroid,
        latestIos:     latestIos,
        latestAndroid: latestAndroid,
        storeUrlIos:   storeUrlIos,
        storeUrlAndroid: storeUrlAndroid,
      );
      await load();
    } catch (e) {
      emit(state.copyWith(
        status:         AppConfigStatus.error,
        error:          'Verzió frissítési hiba: $e',
        clearSavingKey: true,
      ));
    }
  }
}
