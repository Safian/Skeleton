import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ============================================================
// DeepLinkService – iOS Universal Links + Android App Links + web
//
// Inicializálás: DeepLinkService.instance.initialize(navigatorKey)
// Ismert útvonalak:
//   /invite-accept?token=<uuid>  → InviteAcceptScreen
// ============================================================

class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final _appLinks = AppLinks();
  GlobalKey<NavigatorState>? _navigatorKey;

  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;

    // App cold-start linkje
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _route(initial);
    } catch (e) {
      debugPrint('[DeepLink] getInitialLink error: $e');
    }

    // Futó app linkjei
    _appLinks.uriLinkStream.listen(
      _route,
      onError: (e) => debugPrint('[DeepLink] stream error: $e'),
    );
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

      // Bővítési pont: további útvonalak
      // case '/profile':
      //   nav.pushNamed('/profile', arguments: uri.queryParameters['id']);
    }
  }
}
