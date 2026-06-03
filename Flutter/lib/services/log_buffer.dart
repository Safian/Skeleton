import 'package:flutter/foundation.dart';

// ============================================================
// LogBuffer – utolsó N log bejegyzés memóriában tárolása  [M7]
//
// A BugReporter csatolja a bug reporthoz.
// Singleton – az egész appban elérhető.
//
// Használat:
//   LogBuffer.instance.log('Felhasználó rányomott a Submit gombra');
//   final logs = LogBuffer.instance.getLogs();
// ============================================================

class LogBuffer {
  LogBuffer._();
  static final LogBuffer instance = LogBuffer._();

  static const int _maxLogs = 50;

  final List<_LogEntry> _entries = [];

  // ── Logolás ───────────────────────────────────────────────

  void log(String message, {String level = 'INFO'}) {
    final entry = _LogEntry(
      timestamp: DateTime.now(),
      level:     level,
      message:   message,
    );
    _entries.add(entry);

    // Maximális méret megtartása
    if (_entries.length > _maxLogs) {
      _entries.removeAt(0);
    }

    // Debug módban a konzolra is kiírjuk
    if (kDebugMode) {
      debugPrint('[${entry.level}] ${entry.message}');
    }
  }

  void info(String message)    => log(message, level: 'INFO');
  void warning(String message) => log(message, level: 'WARN');
  void error(String message)   => log(message, level: 'ERROR');

  // ── Lekérdezés ────────────────────────────────────────────

  /// Az összes tárolt log szövegként (bug reporthoz)
  List<String> getLogs() {
    return _entries.map((e) => e.toString()).toList();
  }

  /// Törlés (pl. kijelentkezéskor)
  void clear() => _entries.clear();
}

// ── Internal ───────────────────────────────────────────────────

class _LogEntry {
  final DateTime timestamp;
  final String level;
  final String message;

  const _LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
  });

  @override
  String toString() {
    final ts = timestamp.toIso8601String();
    return '[$ts] [$level] $message';
  }
}
