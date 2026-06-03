import 'package:equatable/equatable.dart';
import '../../models/app_config.dart';

// ============================================================
// AppConfigState – Admin Remote Config állapotgép  [M5]
// ============================================================

enum AppConfigStatus { initial, loading, loaded, saving, error }

class AppConfigState extends Equatable {
  final AppConfigStatus status;
  final List<AppConfigEntry> entries;
  final String? error;
  final String? savingKey; // melyik kulcsot mentjük éppen

  const AppConfigState({
    this.status     = AppConfigStatus.initial,
    this.entries    = const [],
    this.error,
    this.savingKey,
  });

  bool get isLoading => status == AppConfigStatus.loading;
  bool get isSaving  => status == AppConfigStatus.saving;

  /// Karbantartás mód aktuális értéke
  bool get maintenanceMode {
    final e = entries.where((e) => e.key == 'maintenance_mode').firstOrNull;
    return e?.boolValue ?? false;
  }

  /// Karbantartás üzenet
  String get maintenanceMessage {
    return entries
            .where((e) => e.key == 'maintenance_message')
            .firstOrNull
            ?.value ??
        '';
  }

  /// Karbantartás cím
  String get maintenanceTitle {
    return entries
            .where((e) => e.key == 'maintenance_title')
            .firstOrNull
            ?.value ??
        'Karbantartás';
  }

  /// Feature flag-ek csoportja
  List<AppConfigEntry> get featureFlags =>
      entries.where((e) => e.isFlag).toList();

  /// Verziókhoz kapcsolódó bejegyzések
  List<AppConfigEntry> get versionEntries =>
      entries.where((e) => e.isVersion).toList();

  /// Karbantartáshoz kapcsolódó bejegyzések
  List<AppConfigEntry> get maintenanceEntries =>
      entries.where((e) => e.isMaintenance).toList();

  /// Egyéb bejegyzések
  List<AppConfigEntry> get otherEntries => entries
      .where((e) => !e.isFlag && !e.isVersion && !e.isMaintenance)
      .toList();

  AppConfigState copyWith({
    AppConfigStatus?       status,
    List<AppConfigEntry>?  entries,
    String?                error,
    String?                savingKey,
    bool                   clearError = false,
    bool                   clearSavingKey = false,
  }) {
    return AppConfigState(
      status:     status     ?? this.status,
      entries:    entries    ?? this.entries,
      error:      clearError ? null : (error ?? this.error),
      savingKey:  clearSavingKey ? null : (savingKey ?? this.savingKey),
    );
  }

  @override
  List<Object?> get props => [status, entries, error, savingKey];
}
