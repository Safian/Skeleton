import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/security_log.dart';
import '../../repositories/security_repository.dart';

part 'security_state.dart';

class SecurityCubit extends Cubit<SecurityState> {
  SecurityCubit({required SecurityRepository repository})
      : _repo = repository,
        super(const SecurityState());

  final SecurityRepository _repo;
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeSub;

  // ── Filters ──────────────────────────────────────────────────

  String? _eventTypeFilter;
  String? _sourceFilter;
  String? _ipFilter;
  bool? _resolvedFilter;

  // ── Load ─────────────────────────────────────────────────────

  Future<void> load() async {
    emit(state.copyWith(status: SecurityStatus.loading));
    try {
      final results = await Future.wait([
        _repo.getStats(),
        _repo.getLogs(
          eventTypeFilter: _eventTypeFilter,
          sourceFilter: _sourceFilter,
          ipFilter: _ipFilter,
          resolvedFilter: _resolvedFilter,
        ),
        _repo.getBannedIps(),
      ]);

      emit(state.copyWith(
        status:    SecurityStatus.loaded,
        stats:     results[0] as SecurityStats,
        logs:      results[1] as List<SecurityLog>,
        bannedIps: results[2] as List<BannedIp>,
        error:     null,
      ));

      _subscribeRealtime();
    } catch (e) {
      emit(state.copyWith(status: SecurityStatus.error, error: e.toString()));
    }
  }

  // ── Realtime ─────────────────────────────────────────────────

  void _subscribeRealtime() {
    _realtimeSub?.cancel();
    _realtimeSub = _repo.watchLogs().listen((rows) {
      if (isClosed) return; // realtime esemény a cubit bezárása után is jöhet
      final logs = rows
          .map((r) => SecurityLog.fromJson(r))
          .toList();
      emit(state.copyWith(logs: logs));
      // Stats is frissítése
      _refreshStats();
    });
  }

  Future<void> _refreshStats() async {
    try {
      final stats = await _repo.getStats();
      if (isClosed) return; // await után a cubit bezárhatott
      emit(state.copyWith(stats: stats));
    } catch (_) {}
  }

  // ── Filters ──────────────────────────────────────────────────

  void setEventTypeFilter(String? value) {
    _eventTypeFilter = value;
    load();
  }

  void setSourceFilter(String? value) {
    _sourceFilter = value;
    load();
  }

  void setIpFilter(String? value) {
    _ipFilter = (value?.isEmpty ?? true) ? null : value;
    load();
  }

  void setResolvedFilter(bool? value) {
    _resolvedFilter = value;
    load();
  }

  void clearFilters() {
    _eventTypeFilter = null;
    _sourceFilter    = null;
    _ipFilter        = null;
    _resolvedFilter  = null;
    load();
  }

  // ── Actions ──────────────────────────────────────────────────

  Future<void> resolveLog(String logId) async {
    try {
      await _repo.resolveLog(logId);
      load();
    } catch (e) {
      emit(state.copyWith(error: 'Hiba a lezárásnál: $e'));
    }
  }

  Future<bool> unbanIp(String ipAddress, {String? jail}) async {
    emit(state.copyWith(unbanning: ipAddress));
    try {
      await _repo.unbanIp(ipAddress, jail: jail);
      emit(state.copyWith(unbanning: null));
      load();
      return true;
    } catch (e) {
      emit(state.copyWith(unbanning: null, error: 'Unban sikertelen: $e'));
      return false;
    }
  }

  @override
  Future<void> close() {
    _realtimeSub?.cancel();
    return super.close();
  }
}
