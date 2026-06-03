import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ============================================================
// AppAvatar – initials / image / icon alapú avatar
// ============================================================

class AppAvatar extends StatelessWidget {
  final String? name;
  final String? imageUrl;
  final IconData? fallbackIcon;
  final double size;
  final Color? color;

  const AppAvatar({
    super.key,
    this.name,
    this.imageUrl,
    this.fallbackIcon,
    this.size = 40,
    this.color,
  });

  String get _initials {
    if (name == null || name!.trim().isEmpty) return '?';
    final parts = name!.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first.substring(0, parts.first.length.clamp(1, 2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppColors.primary.withValues(alpha: 0.25);

    if (imageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(bg),
        ),
      );
    }
    return _placeholder(bg);
  }

  Widget _placeholder(Color bg) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      alignment: Alignment.center,
      child: fallbackIcon != null
          ? Icon(fallbackIcon, size: size * 0.5, color: AppColors.primary)
          : Text(
              _initials,
              style: AppTypography.label.copyWith(
                color: AppColors.primary,
                fontSize: size * 0.35,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}
