import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ============================================================
// RadialBackground – dekoratív háttér gradient sugár effektekkel
// ============================================================

class RadialBackground extends StatelessWidget {
  final Widget child;

  const RadialBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base background
        Positioned.fill(
          child: Container(color: AppColors.background),
        ),
        // Top-left glow
        Positioned(
          top: -80,
          left: -60,
          child: _glow(AppColors.primary, 260),
        ),
        // Bottom-right glow
        Positioned(
          bottom: -100,
          right: -80,
          child: _glow(AppColors.secondary, 200),
        ),
        // Center subtle glow
        Positioned(
          top: MediaQuery.of(context).size.height * 0.35,
          left: MediaQuery.of(context).size.width * 0.3,
          child: _glow(AppColors.primary.withValues(alpha: 0.3), 150),
        ),
        // Content
        child,
      ],
    );
  }

  Widget _glow(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.25),
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// AppDivider – divider szekció fejléccel
// ============================================================

class AppSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const AppSectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.lg, 0, AppSpacing.sm),
      child: Row(
        children: [
          Text(title.toUpperCase(), style: AppTypography.eyebrow),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ============================================================
// AppEmptyState – üres lista / hiba állapot
// ============================================================

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(title,
              style: AppTypography.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(subtitle!,
                style: AppTypography.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// AppLoadingIndicator – egyszerű töltő
// ============================================================

class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: AppColors.primary,
        strokeWidth: 2.5,
      ),
    );
  }
}
