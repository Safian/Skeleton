import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized, fire-and-forget error logger.
///
/// Usage:
///   LogService.instance.error(
///     app: 'client',
///     type: 'chat_error',
///     message: e.toString(),
///     context: {'screen': 'HomeScreen'},
///     stackTrace: st,
///   );
///
/// Never throws — all errors are silently swallowed so logging never
/// crashes the app.
class LogService {
  LogService._();
  static final LogService instance = LogService._();

  SupabaseClient? _client;

  /// Call once at app startup (after Supabase.initialize).
  void init(SupabaseClient client) {
    _client = client;
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  void error({
    required String app,
    required String type,
    required String message,
    Map<String, dynamic>? context,
    StackTrace? stackTrace,
  }) {
    _write(
      app: app,
      errorType: type,
      message: message,
      context: context,
      stackTrace: stackTrace,
    );
  }

  void authError(String app, Object error, [StackTrace? st]) =>
      this.error(app: app, type: 'auth_error', message: error.toString(), stackTrace: st);

  void networkError(String app, Object error, [StackTrace? st]) =>
      this.error(app: app, type: 'network_error', message: error.toString(), stackTrace: st);

  void sessionError(String app, Object error, [StackTrace? st]) =>
      this.error(app: app, type: 'session_error', message: error.toString(), stackTrace: st);

  void permissionError(String app, Object error, [StackTrace? st]) =>
      this.error(app: app, type: 'permission_error', message: error.toString(), stackTrace: st);

  // ── Internal ────────────────────────────────────────────────────────────────

  void _write({
    required String app,
    required String errorType,
    required String message,
    Map<String, dynamic>? context,
    StackTrace? stackTrace,
  }) {
    if (_client == null) return;

    final clampedMessage =
        message.length > 2000 ? message.substring(0, 2000) : message;
    final clampedStack = stackTrace != null
        ? (stackTrace.toString().length > 3000
            ? stackTrace.toString().substring(0, 3000)
            : stackTrace.toString())
        : null;

    final currentUserId = _client!.auth.currentUser?.id;

    if (currentUserId == null) {
      // Pre-login: the anon role cannot INSERT into app_error_logs (RLS is
      // `TO authenticated`). Route through the `log-error` edge function, which
      // inserts with service_role behind a rate limit. Fire-and-forget.
      _client!.functions
          .invoke('log-error', body: {
            'app': app,
            'error_type': errorType,
            'error_message': clampedMessage,
            'context': context ?? {},
            'stack_trace': clampedStack,
          })
          .then((_) {
            if (kDebugMode) {
              debugPrint('[LogService] (edge) [$app] [$errorType] $clampedMessage');
            }
          })
          .catchError((e) {
            if (kDebugMode) debugPrint('[LogService] Edge log failed: $e');
          });
      return;
    }

    // Authenticated: direct insert via RLS. Fire-and-forget: never await/throw.
    _client!
        .from('app_error_logs')
        .insert({
          'app': app,
          'user_id': currentUserId,
          'error_type': errorType,
          'error_message': clampedMessage,
          'context': context ?? {},
          'stack_trace': clampedStack,
        })
        .then((_) {
          if (kDebugMode) {
            debugPrint('[LogService] [$app] [$errorType] $clampedMessage');
          }
        })
        .catchError((e) {
          // Silently ignore — logging must never crash the app
          if (kDebugMode) debugPrint('[LogService] Failed to write log: $e');
        });
  }
}
