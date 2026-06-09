import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'foreground_push_message.dart';
import 'foreground_push_banner.dart';

// Re-export so consumers only need one import.
export 'foreground_push_message.dart';

/// Wraps any widget tree. When a FCM foreground message arrives, a slide-in
/// banner appears at the top of the screen — rendered into the *root* [Overlay]
/// so it floats above every pushed Navigator route.
///
/// Usage:
/// ```dart
/// ForegroundPushOverlay(
///   onTap: (msg) { /* handle tap */ },
///   child: YourRootWidget(),
/// )
/// ```
class ForegroundPushOverlay extends StatefulWidget {
  final Widget child;
  final ForegroundPushTapCallback? onTap;

  const ForegroundPushOverlay({
    super.key,
    required this.child,
    this.onTap,
  });

  @override
  State<ForegroundPushOverlay> createState() => _ForegroundPushOverlayState();
}

class _ForegroundPushOverlayState extends State<ForegroundPushOverlay>
    with SingleTickerProviderStateMixin {
  StreamSubscription<RemoteMessage>? _sub;
  ForegroundPushMessage? _current;
  OverlayEntry? _entry;
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _slide = Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));

    // Web uses a different FCM flow (browser permission) — skip the stream.
    if (!kIsWeb) {
      _sub = FirebaseMessaging.onMessage.listen(_onMessage);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _dismissTimer?.cancel();
    _removeEntry();
    _ctrl.dispose();
    super.dispose();
  }

  void _onMessage(RemoteMessage msg) {
    final title = msg.notification?.title ?? msg.data['title'] as String? ?? '';
    final body = msg.notification?.body ?? msg.data['body'] as String? ?? '';
    if (title.isEmpty && body.isEmpty) return;
    if (!mounted) return;

    _current = ForegroundPushMessage(title: title, body: body, data: msg.data);

    _dismissTimer?.cancel();
    _showEntry();
    _ctrl.forward(from: 0);

    // Auto-dismiss after 4 seconds
    _dismissTimer = Timer(const Duration(seconds: 4), _dismiss);
  }

  /// Inserts the banner into the root overlay so it draws above all routes.
  void _showEntry() {
    _removeEntry();
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _entry = OverlayEntry(
      builder: (_) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: ForegroundPushBanner(
                message: _current!,
                onTap: _onTap,
                onDismiss: _dismiss,
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_entry!);
  }

  void _removeEntry() {
    _entry?.remove();
    _entry = null;
  }

  void _dismiss() {
    _dismissTimer?.cancel();
    if (!_ctrl.isAnimating && _ctrl.value == 0) {
      _removeEntry();
      return;
    }
    _ctrl.reverse().then((_) {
      _removeEntry();
      if (mounted) _current = null;
    });
  }

  void _onTap() {
    final msg = _current;
    _dismiss();
    if (msg != null) widget.onTap?.call(msg);
  }

  @override
  Widget build(BuildContext context) {
    // The banner lives in the root overlay (see _showEntry), so build simply
    // passes the child through unchanged.
    return widget.child;
  }
}
