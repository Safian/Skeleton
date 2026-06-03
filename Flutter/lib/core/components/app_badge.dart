import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ============================================================
// AppBadge – kis státusz jelölő chip
// ============================================================

enum AppBadgeVariant { primary, success, warning, error, neutral }

class AppBadge extends StatelessWidget {
  final String label;
  final AppBadgeVariant variant;
  final IconData? icon;

  const AppBadge({
    super.key,
    required this.label,
    this.variant = AppBadgeVariant.primary,
    this.icon,
  });

  Color get _bg => switch (variant) {
    AppBadgeVariant.primary => AppColors.primary.withValues(alpha: 0.18),
    AppBadgeVariant.success => AppColors.success.withValues(alpha: 0.18),
    AppBadgeVariant.warning => AppColors.warning.withValues(alpha: 0.18),
    AppBadgeVariant.error   => AppColors.error.withValues(alpha: 0.18),
    AppBadgeVariant.neutral => AppColors.surfaceVariant,
  };

  Color get _fg => switch (variant) {
    AppBadgeVariant.primary => AppColors.primary,
    AppBadgeVariant.success => AppColors.success,
    AppBadgeVariant.warning => AppColors.warning,
    AppBadgeVariant.error   => AppColors.error,
    AppBadgeVariant.neutral => AppColors.onSurface.withValues(alpha: 0.6),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: _fg),
            const SizedBox(width: 4),
          ],
          Text(label,
            style: AppTypography.eyebrow.copyWith(color: _fg, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
