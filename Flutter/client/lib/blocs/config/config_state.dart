import 'package:equatable/equatable.dart';

// ============================================================
// ConfigState – Remote Config állapotgép  [M5]
// ============================================================

enum ConfigStatus { initial, loading, loaded, error }

/// Update típus – verziózás alapján
enum UpdateStatus {
  none,   // Nincs szükséges frissítés
  soft,   // Ajánlott (lehet elutasítani)
  force,  // Kötelező (nem lehet továbblépni)
}

class ConfigState extends Equatable {
  final ConfigStatus status;
  final UpdateStatus updateStatus;
  final String? error;

  const ConfigState({
    this.status       = ConfigStatus.initial,
    this.updateStatus = UpdateStatus.none,
    this.error,
  });

  bool get isLoaded    => status == ConfigStatus.loaded;
  bool get isLoading   => status == ConfigStatus.loading;
  bool get forceUpdate => updateStatus == UpdateStatus.force;
  bool get softUpdate  => updateStatus == UpdateStatus.soft;

  ConfigState copyWith({
    ConfigStatus?  status,
    UpdateStatus?  updateStatus,
    String?        error,
    bool clearError = false,
  }) {
    return ConfigState(
      status:       status       ?? this.status,
      updateStatus: updateStatus ?? this.updateStatus,
      error:        clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, updateStatus, error];
}
