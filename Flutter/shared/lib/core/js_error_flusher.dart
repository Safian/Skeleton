import 'js_error_flusher_stub.dart'
    if (dart.library.html) 'js_error_flusher_web.dart';
import 'log_service.dart';

/// Reads JS errors cached in localStorage by the index.html error catcher
/// and sends them to [LogService] using the current authenticated session.
///
/// Call this once after the user is confirmed logged-in.
/// Safe to call on native platforms — it is a no-op via the stub.
Future<void> flushPendingJsErrors(String appName) async {
  try {
    final errors = await readPendingJsErrorsImpl();
    if (errors.isEmpty) return;

    // Drop entries older than 7 days (stale, not worth sending)
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 7))
        .millisecondsSinceEpoch;

    for (final entry in errors) {
      final ts = entry['ts'];
      if (ts is int && ts < cutoff) continue;

      LogService.instance.error(
        app: appName,
        type: entry['error_type']?.toString() ?? 'js_error',
        message: entry['error_message']?.toString() ?? '',
        context: {'source': 'js_error_cache', 'ts': ts},
      );
    }

    await clearPendingJsErrorsImpl();
  } catch (_) {
    // Never crash the app over error flushing
  }
}
