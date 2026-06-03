import 'package:flutter/material.dart';
import 'tutorial_controller.dart';
import 'tutorial_bubble.dart';

// ============================================================
// TutorialOverlay – Áttetsző overlay a tutorial megjelenítéséhez  [M8]
//
// Működési elv:
//  1. A TutorialController meghatározza az aktuális lépést
//  2. Az overlay megkeresi a célzott widget pozícióját (GlobalKey)
//  3. Félhomályos háttér + kiemelő lyuk (hole-punch) jelenik meg
//  4. A TutorialBubble a kiemelés mellé/fölé/alá pozicionálódik
//
// Használat:
//
//   // A képernyőn:
//   Stack(
//     children: [
//       // ... normál tartalom ...
//       TutorialOverlay(
//         controller: _tutorialController,
//         titleResolver:       (key) => context.l10n.resolve(key),
//         descriptionResolver: (key) => context.l10n.resolve(key),
//       ),
//     ],
//   )
//
// LOKALIZÁCIÓ: A titleLocKey és descriptionLocKey értékeket
// az AppLocalizations rendszerednek megfelelő resolver-rel fordítod le.
// ============================================================

typedef LocalizationResolver = String Function(String key);

class TutorialOverlay extends StatefulWidget {
  final TutorialController controller;

  /// Fordítja a TutorialStep.titleLocKey értékét megjelenítendő szöveggé.
  /// Példa: (key) => AppLocalizations.of(context)!.resolve(key)
  final LocalizationResolver titleResolver;

  /// Fordítja a TutorialStep.descriptionLocKey értékét.
  final LocalizationResolver descriptionResolver;

  const TutorialOverlay({
    super.key,
    required this.controller,
    required this.titleResolver,
    required this.descriptionResolver,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);

    widget.controller.addListener(_onControllerChange);
    _onControllerChange(); // Kezdeti állapot
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    _animCtrl.dispose();
    super.dispose();
  }

  void _onControllerChange() {
    if (!mounted) return;
    setState(() {});
    if (widget.controller.isActive) {
      _animCtrl.forward();
    } else {
      _animCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.isActive || widget.controller.currentStep == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _fadeAnim,
      builder: (context, _) {
        if (_fadeAnim.value == 0) return const SizedBox.shrink();
        return Opacity(
          opacity: _fadeAnim.value,
          child: _buildOverlay(context),
        );
      },
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final step = widget.controller.currentStep!;

    // Célzott widget pozíciójának lekérése
    final renderBox = step.targetKey.currentContext
        ?.findRenderObject() as RenderBox?;

    if (renderBox == null || !renderBox.attached) {
      // Ha a widget nem látható, csak a buborékot mutatjuk középen
      return _buildFallbackOverlay();
    }

    final targetPos  = renderBox.localToGlobal(Offset.zero);
    final targetSize = renderBox.size;
    final screenSize = MediaQuery.of(context).size;

    final highlightRect = Rect.fromLTWH(
      targetPos.dx - 8,
      targetPos.dy - 8,
      targetSize.width + 16,
      targetSize.height + 16,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Homályos háttér kiemelő lyukkal ────────────────
        GestureDetector(
          onTap: () => widget.controller.next(), // Koppintás = Tovább
          child: CustomPaint(
            painter: _HolePunchPainter(highlightRect: highlightRect),
            child: const SizedBox.expand(),
          ),
        ),

        // ── Buborék elhelyezése ─────────────────────────────
        _PositionedBubble(
          highlightRect: highlightRect,
          screenSize:    screenSize,
          position:      step.position,
          child: TutorialBubble(
            controller:  widget.controller,
            title:       widget.titleResolver(step.titleLocKey),
            description: widget.descriptionResolver(step.descriptionLocKey),
            position:    step.position,
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackOverlay() {
    final step = widget.controller.currentStep!;
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: () => widget.controller.next(),
          child: Container(color: Colors.black54),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: TutorialBubble(
              controller:  widget.controller,
              title:       widget.titleResolver(step.titleLocKey),
              description: widget.descriptionResolver(step.descriptionLocKey),
              position:    TutorialBubblePosition.below,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Buborék pozicionálása ──────────────────────────────────────

class _PositionedBubble extends StatelessWidget {
  final Rect highlightRect;
  final Size screenSize;
  final TutorialBubblePosition position;
  final Widget child;

  const _PositionedBubble({
    required this.highlightRect,
    required this.screenSize,
    required this.position,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    const bubbleMaxWidth  = 280.0;
    const bubbleEstHeight = 180.0;
    const margin          = 16.0;

    double top;
    double left = (highlightRect.left + highlightRect.width / 2 -
        bubbleMaxWidth / 2).clamp(margin, screenSize.width - bubbleMaxWidth - margin);

    switch (position) {
      case TutorialBubblePosition.below:
        top = highlightRect.bottom + 8;
        // Ha nem fér el alul → fölé tesszük
        if (top + bubbleEstHeight > screenSize.height - margin) {
          top = (highlightRect.top - bubbleEstHeight - 8).clamp(margin, double.infinity);
        }
      case TutorialBubblePosition.above:
        top = (highlightRect.top - bubbleEstHeight - 8)
            .clamp(margin, double.infinity);
        if (top < margin) top = highlightRect.bottom + 8;
      case TutorialBubblePosition.left:
        top  = highlightRect.top;
        left = (highlightRect.left - bubbleMaxWidth - 8)
            .clamp(margin, double.infinity);
      case TutorialBubblePosition.right:
        top  = highlightRect.top;
        left = highlightRect.right + 8;
    }

    return Positioned(
      top:  top,
      left: left,
      width: bubbleMaxWidth,
      child: child,
    );
  }
}

// ── Hole-punch háttér festő ────────────────────────────────────

class _HolePunchPainter extends CustomPainter {
  final Rect highlightRect;

  const _HolePunchPainter({required this.highlightRect});

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Kiemelés lekerekített sarka
    final highlightRRect = RRect.fromRectAndRadius(
      highlightRect,
      const Radius.circular(12),
    );

    // Átlátszatlan rész (kivéve a kiemelés)
    final path = Path()
      ..addRect(fullRect)
      ..addRRect(highlightRRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.72),
    );

    // Kiemelés kerülete (fénylő border)
    canvas.drawRRect(
      highlightRRect,
      Paint()
        ..style  = PaintingStyle.stroke
        ..color  = const Color(0xFF6C63FF).withValues(alpha: 0.8)
        ..strokeWidth = 2.0,
    );
  }

  @override
  bool shouldRepaint(_HolePunchPainter old) =>
      old.highlightRect != highlightRect;
}
