import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'secure_storage_service.dart';

// ============================================================
// DeepLinkService  [M2.4]
//
// 1. iOS Universal Links + Android App Links + web linkek (app_links)
// 2. Deferred deep link: legelső indításkor IP-egyeztetés a
//    pending-invite Edge Function-nel – automatikus navigáció
//    InviteAcceptScreen-re ha egyezés van.
// ============================================================

class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final _appLinks = AppLinks();
  GlobalKey<NavigatorState>? _navigatorKey;

  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;

    // Cold-start link
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _route(initial);
    } catch (e) {
      debugPrint('[DeepLink] getInitialLink error: $e');
    }

    // Live stream
    _appLinks.uriLinkStream.listen(
      _route,
      onError: (e) => debugPrint('[DeepLink] stream error: $e'),
    );

    // [M2.4] Deferred check
    await _checkDeferredLink();
  }

  // ── [M2.4] Deferred Link Check ──────────────────────────────
  Future<void> _checkDeferredLink() async {
    final secure = SecureStorageService.instance;
    if (await secure.isDeferredLinkChecked) return;
    await secure.markDeferredLinkChecked();

    try {
      final client = Supabase.instance.client;
      final res = await client.functions.invoke(
        'pending-invite',
        method: HttpMethod.get,
        queryParameters: {'check': '1'},
      );

      final data = res.data as Map<String, dynamic>?;
      if (data == null) return;

      final found = data['found'] as bool? ?? false;
      final token = data['token'] as String? ?? '';

      if (found && token.isNotEmpty) {
        debugPrint('[DeepLink] Deferred invite match: $token');
        await Future.delayed(const Duration(milliseconds: 500));
        _navigatorKey?.currentState?.pushNamed('/invite-accept', arguments: token);
      }
    } catch (e) {
      debugPrint('[DeepLink] deferred check error: $e');
    }
  }

  void _route(Uri uri) {
    debugPrint('[DeepLink] incoming: $uri');
    final nav = _navigatorKey?.currentState;
    if (nav == null) return;

    switch (uri.path) {
      case '/invite-accept':
        final token = uri.queryParameters['token'] ?? '';
        if (token.isNotEmpty) {
          nav.pushNamed('/invite-accept', arguments: token);
        }
    }
  }
}
