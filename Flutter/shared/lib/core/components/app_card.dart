import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ============================================================
// AppCard – alap kártya + glass variáns
// ============================================================

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool glass;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.glass = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = padding ?? const EdgeInsets.all(AppSpacing.md);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          padding: p,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            color: glass ? AppGlass.g2 : AppColors.surface,
            border: Border.all(
              color: glass ? AppGlass.stroke : AppColors.divider,
            ),
            boxShadow: glass ? null : AppGlow.card,
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── GlassCard alias ───────────────────────────────────────────
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const GlassCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) =>
      AppCard(child: child, padding: padding, glass: true);
}
