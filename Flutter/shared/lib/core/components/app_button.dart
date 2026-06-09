import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ============================================================
// AppButton – primary / secondary / danger / text variánsok
// ============================================================

enum AppButtonVariant { primary, secondary, danger, ghost }

class AppButton extends StatelessWidget {
  final String label;
  final AppButtonVariant variant;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;

  const AppButton({
    super.key,
    required this.label,
    this.variant = AppButtonVariant.primary,
    this.onTap,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final bg = switch (variant) {
      AppButtonVariant.primary   => AppColors.primary,
      AppButtonVariant.secondary => AppColors.surface,
      AppButtonVariant.danger    => AppColors.error,
      AppButtonVariant.ghost     => Colors.transparent,
    };
    final fg = switch (variant) {
      AppButtonVariant.primary   => AppColors.onPrimary,
      AppButtonVariant.secondary => AppColors.onSurface,
      AppButtonVariant.danger    => Colors.white,
      AppButtonVariant.ghost     => AppColors.primary,
    };
    final side = switch (variant) {
      AppButtonVariant.secondary => BorderSide(color: AppColors.divider),
      AppButtonVariant.ghost     => BorderSide.none,
      _                          => BorderSide.none,
    };

    Widget child = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: fg,
            ),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
          ],
          Text(label, style: AppTypography.button.copyWith(color: fg)),
        ],
      ],
    );

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm + 4,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.fromBorderSide(side),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
