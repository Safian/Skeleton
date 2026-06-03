import 'package:flutter/material.dart';
import 'tutorial_controller.dart';

// ============================================================
// TutorialBubble – A magyarázó buborék widget  [M8]
//
// Megjelenítési logika:
//  - A célzott widget pozíciójához képest above/below/left/right
//  - Háromszög nyíl a targetra mutató irányban
//  - Lépés számláló, Tovább / Kész gombok
//  - Szöveg az AppLocalizations-ból jön (külső callback)
// ============================================================

class TutorialBubble extends StatelessWidget {
  final TutorialController controller;
  final String title;
  final String description;
  final TutorialBubblePosition position;

  const TutorialBubble({
    super.key,
    required this.controller,
    required this.title,
    required this.description,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Nyíl felülre (ha a buborék a target alatt van)
            if (position == TutorialBubblePosition.below)
              _Arrow(pointing: AxisDirection.up),

            _BubbleBody(
              controller:  controller,
              title:       title,
              description: description,
            ),

            // Nyíl alulra (ha a buborék a target felett van)
            if (position == TutorialBubblePosition.above)
              _Arrow(pointing: AxisDirection.down),
          ],
        ),
      ),
    );
  }
}

// ── Buborék törzse ─────────────────────────────────────────────

class _BubbleBody extends StatelessWidget {
  final TutorialController controller;
  final String title;
  final String description;

  const _BubbleBody({
    required this.controller,
    required this.title,
    required this.description,
  });

  static const _bg         = Color(0xFF1E293B);
  static const _primary    = Color(0xFF6C63FF);
  static const _onBg       = Colors.white;
  static const _onBgMuted  = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    final step  = controller.currentIndex + 1;
    final total = controller.steps.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        _bg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color:   Colors.black.withValues(alpha: 0.4),
            blurRadius:   16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fejléc: cím + lépés számláló
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color:      _onBg,
                    fontSize:   14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '$step / $total',
                style: const TextStyle(
                  color:    _onBgMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Leírás
          Text(
            description,
            style: const TextStyle(
              color:    _onBgMuted,
              fontSize: 13,
              height:   1.5,
            ),
          ),
          const SizedBox(height: 12),

          // Haladás sáv
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:            controller.progress,
              backgroundColor:  Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(_primary),
              minHeight:        3,
            ),
          ),
          const SizedBox(height: 12),

          // Gombok
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Kihagyás
              TextButton(
                onPressed: () => controller.skip(),
                style: TextButton.styleFrom(
                  foregroundColor: _onBgMuted,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Kihagyás', style: TextStyle(fontSize: 12)),
              ),

              Row(
                children: [
                  // Vissza (ha nem az első lépésen vagyunk)
                  if (!controller.isFirst) ...[
                    _NavButton(
                      label:     '‹',
                      onPressed: controller.previous,
                      filled:    false,
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Tovább / Kész
                  _NavButton(
                    label:     controller.isLast ? 'Kész' : 'Tovább',
                    onPressed: controller.next,
                    filled:    true,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool filled;

  const _NavButton({
    required this.label,
    required this.onPressed,
    required this.filled,
  });

  static const _primary = Color(0xFF6C63FF);

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13)),
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: _primary,
        side: const BorderSide(color: _primary),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}

// ── Háromszög nyíl ─────────────────────────────────────────────

class _Arrow extends StatelessWidget {
  final AxisDirection pointing;

  const _Arrow({required this.pointing});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(20, 10),
      painter: _ArrowPainter(pointing: pointing),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  final AxisDirection pointing;
  const _ArrowPainter({required this.pointing});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF1E293B);
    final path  = Path();

    switch (pointing) {
      case AxisDirection.up:
        path
          ..moveTo(size.width / 2, 0)
          ..lineTo(0, size.height)
          ..lineTo(size.width, size.height)
          ..close();
      case AxisDirection.down:
        path
          ..moveTo(0, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width / 2, size.height)
          ..close();
      default:
        break;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.pointing != pointing;
}
