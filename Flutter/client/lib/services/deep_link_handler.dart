import 'dart:async';
import 'dart:convert';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'secure_storage_service.dart';

// ignore_for_file: close_sinks

// ============================================================
// DeepLinkHandler
//
// Maps incoming URIs to named actions using the url_mappings
// stored in app_settings (deeplink_url_mappings).
//
// Matching logic:
//   - Static:        "/invite-accept" matches exactly
//   - Parameterised: "/item/:id" matches "/item/abc" and extracts params
//   - Token-based:   "/link/:token" → resolve_token action → calls
//                    resolve-deeplink edge function to unwrap the JWT
//
// Deferred deep link: on first launch, checks the pending-invite edge
// function for a server-side IP match and fires an 'invite' action if found.
//
// Usage:
//   // in initState of your root widget:
//   DeepLinkHandler.instance
//     ..onLink = _routeDeepLink
//     ..init();
// ============================================================

class DeepLinkHandler {
  DeepLinkHandler._();

  static final DeepLinkHandler instance = DeepLinkHandler._();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  /// Callback invoked whenever an incoming deep link is resolved to an action.
  void Function(DeepLinkMatch match)? onLink;

  // ── Broadcast stream ───────────────────────────────────────
  // Fires for every resolved link; subscribe in any widget that needs it.
  final _linkController = StreamController<DeepLinkMatch>.broadcast();
  Stream<DeepLinkMatch> get linkStream => _linkController.stream;

  /// Starts listening. Call once from your root widget's initState.
  Future<void> init() async {
    // Cold-start link (app launched via deep link)
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) await _dispatch(initial);
    } catch (e) {
      debugPrint('[DeepLink] getInitialLink error: $e');
    }

    // Links received while the app is already running
    _sub = _appLinks.uriLinkStream.listen(
      (uri) => _dispatch(uri),
      onError: (e) => debugPrint('[DeepLink] stream error: $e'),
    );

    // First-launch deferred check via pending-invite edge function
    await _checkDeferredLink();
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _linkController.close();
  }

  // ── Deferred (IP-based) invite check ──────────────────────
  Future<void> _checkDeferredLink() async {
    final secure = SecureStorageService.instance;
    if (await secure.isDeferredLinkChecked) return;
    await secure.markDeferredLinkChecked();

    try {
      final res = await Supabase.instance.client.functions.invoke(
        'pending-invite',
        method: HttpMethod.get,
        queryParameters: {'check': '1'},
      );
      final data = res.data as Map<String, dynamic>?;
      if (data == null) return;

      final found = data['found'] as bool? ?? false;
      final token = data['token'] as String? ?? '';

      if (found && token.isNotEmpty) {
        debugPrint('[DeepLink] deferred invite match: $token');
        await Future.delayed(const Duration(milliseconds: 500));
        _emit(DeepLinkMatch(
          action: 'invite',
          params: {'token': token},
          uri: Uri.parse('app://invite-accept?token=$token'),
        ));
      }
    } catch (e) {
      debugPrint('[DeepLink] deferred check error: $e');
    }
  }

  // ── Internal dispatch ──────────────────────────────────────
  Future<void> _dispatch(Uri uri) async {
    debugPrint('[DeepLink] incoming: $uri');
    final mappings = await _loadMappings();
    final match = _resolve(uri, mappings);
    if (match != null) {
      debugPrint('[DeepLink] resolved → action=${match.action} params=${match.params}');
      _emit(match);
    } else {
      debugPrint('[DeepLink] no mapping for path: ${uri.path}');
    }
  }

  void _emit(DeepLinkMatch match) {
    onLink?.call(match);
    _linkController.add(match);
  }

  DeepLinkMatch? _resolve(Uri uri, List<_Mapping> mappings) {
    for (final m in mappings) {
      final params = _matchPath(uri.path, m.path);
      if (params != null) {
        return DeepLinkMatch(
          action: m.action,
          params: {...params, ...uri.queryParameters},
          uri: uri,
        );
      }
    }
    return null;
  }

  /// Returns extracted path params if [template] matches [path], else null.
  /// e.g. template="/item/:id", path="/item/abc" → {"id": "abc"}
  Map<String, String>? _matchPath(String path, String template) {
    final tParts = template.split('/');
    final pParts = path.split('/');
    if (tParts.length != pParts.length) return null;

    final params = <String, String>{};
    for (int i = 0; i < tParts.length; i++) {
      if (tParts[i].startsWith(':')) {
        params[tParts[i].substring(1)] = pParts[i];
      } else if (tParts[i] != pParts[i]) {
        return null;
      }
    }
    return params;
  }

  Future<List<_Mapping>> _loadMappings() async {
    try {
      final rows = await Supabase.instance.client
          .from('app_settings')
          .select('value')
          .eq('id', 'deeplink_url_mappings')
          .limit(1);
      if (rows.isEmpty) return [];
      final raw = rows[0]['value'] as String? ?? '[]';
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list
          .map((m) => _Mapping(
                path: m['path']?.toString() ?? '',
                action: m['action']?.toString() ?? '',
              ))
          .where((m) => m.path.isNotEmpty && m.action.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[DeepLink] failed to load mappings: $e');
      return [];
    }
  }
}

// ── Internal types ─────────────────────────────────────────

class _Mapping {
  final String path;
  final String action;
  const _Mapping({required this.path, required this.action});
}

// ── Public types ───────────────────────────────────────────

/// Resolved deep link ready for the UI layer to act on.
class DeepLinkMatch {
  final String action;
  final Map<String, String> params;
  final Uri uri;
  const DeepLinkMatch({required this.action, required this.params, required this.uri});
}
