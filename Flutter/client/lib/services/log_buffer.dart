import 'package:flutter/foundation.dart';

// ============================================================
// LogBuffer  [M4.1]
//
// Körkörösen felülírt, max 50 bejegyzéses in-memory log buffer.
// A QA Shield bug reporthoz csatolja az utolsó 50 kliens-oldali
// hibanaplót.
//
// Használat:
//   LogBuffer.instance.add('SomeScreen: error loading data');
//   final logs = LogBuffer.instance.recent();
// ============================================================

class LogBuffer {
  LogBuffer._();
  static final LogBuffer instance = LogBuffer._();

  static const int _maxEntries = 50;
  final List<String> _entries = [];

  /// Naplóbejegyzés hozzáadása timestamp-pel.
  void add(String message) {
    final ts = DateTime.now().toIso8601String();
    final entry = '[$ts] $message';
    if (_entries.length >= _maxEntries) {
      _entries.removeAt(0);
    }
    _entries.add(entry);
    if (kDebugMode) debugPrint('[LogBuffer] $entry');
  }

  /// Az utolsó N bejegyzés visszaadása (legrégebbi először).
  List<String> recent([int count = _maxEntries]) {
    final n = count.clamp(0, _entries.length);
    return List.unmodifiable(_entries.sublist(_entries.length - n));
  }

  /// Összes bejegyzés törlése.
  void clear() => _entries.clear();

  /// Bejegyzések száma.
  int get length => _entries.length;
}
