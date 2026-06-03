import 'package:flutter/material.dart';

// ============================================================
// App Color Tokens – single source of truth
// ============================================================

class AppColorPalette {
  final Color primary;
  final Color primaryVariant;
  final Color secondary;
  final Color accent;
  final Color success;
  final Color warning;
  final Color error;
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color onBackground;
  final Color onSurface;
  final Color onPrimary;
  final Color divider;

  const AppColorPalette({
    required this.primary,
    required this.primaryVariant,
    required this.secondary,
    required this.accent,
    required this.success,
    required this.warning,
    required this.error,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.onBackground,
    required this.onSurface,
    required this.onPrimary,
    required this.divider,
  });

  static const AppColorPalette dark = AppColorPalette(
    primary:         Color(0xFF6366F1), // Indigo 500
    primaryVariant:  Color(0xFF4F46E5), // Indigo 600
    secondary:       Color(0xFF34D399), // Emerald 400
    accent:          Color(0xFFFBBF24), // Amber 400
    success:         Color(0xFF34D399),
    warning:         Color(0xFFFBBF24),
    error:           Color(0xFFEF4444),
    background:      Color(0xFF0F1117),
    surface:         Color(0xFF1A1D27),
    surfaceVariant:  Color(0xFF252836),
    onBackground:    Color(0xFFFFFFFF),
    onSurface:       Color(0xFFFFFFFF),
    onPrimary:       Color(0xFFFFFFFF),
    divider:         Color(0x1FFFFFFF),
  );

  static const AppColorPalette light = AppColorPalette(
    primary:         Color(0xFF6366F1),
    primaryVariant:  Color(0xFF4F46E5),
    secondary:       Color(0xFF10B981),
    accent:          Color(0xFFF59E0B),
    success:         Color(0xFF10B981),
    warning:         Color(0xFFF59E0B),
    error:           Color(0xFFDC2626),
    background:      Color(0xFFF5F5F7),
    surface:         Color(0xFFFFFFFF),
    surfaceVariant:  Color(0xFFF0F0F5),
    onBackground:    Color(0xFF111827),
    onSurface:       Color(0xFF111827),
    onPrimary:       Color(0xFFFFFFFF),
    divider:         Color(0x1F000000),
  );
}

// ──────────────────────────────────────────────────────────────
// Glass / Overlay helpers
// ──────────────────────────────────────────────────────────────
class AppGlass {
  AppGlass._();
  static const Color g1     = Color(0x0DFFFFFF);
  static const Color g2     = Color(0x14FFFFFF);
  static const Color g3     = Color(0x1EFFFFFF);
  static const Color stroke = Color(0x1AFFFFFF);
}

// ──────────────────────────────────────────────────────────────
// Foreground alpha helpers
// ──────────────────────────────────────────────────────────────
class AppFg {
  AppFg._();
  static const Color full = Color(0xFFFFFFFF);
  static const Color fg2  = Color(0xC7FFFFFF); // 78 %
  static const Color fg3  = Color(0x8FFFFFFF); // 56 %
  static const Color fg4  = Color(0x61FFFFFF); // 38 %
}

// ──────────────────────────────────────────────────────────────
// Glow helpers
// ──────────────────────────────────────────────────────────────
class AppGlow {
  AppGlow._();
  static List<BoxShadow> get primary => [
    const BoxShadow(color: Color(0x556366F1), blurRadius: 24),
  ];
  static List<BoxShadow> get secondary => [
    const BoxShadow(color: Color(0x5534D399), blurRadius: 24),
  ];
  static List<BoxShadow> get card => [
    const BoxShadow(color: Color(0x40000000), blurRadius: 30, offset: Offset(0, 10)),
  ];
  static List<BoxShadow> get error => [
    const BoxShadow(color: Color(0x80EF4444), blurRadius: 24),
  ];
}

// ──────────────────────────────────────────────────────────────
// Static accessor (delegates to active theme)
// ──────────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  static AppColorPalette get _p => AppColors._palette;
  static AppColorPalette _palette = AppColorPalette.dark;

  static void use(AppColorPalette palette) => _palette = palette;

  static Color get primary        => _p.primary;
  static Color get primaryVariant => _p.primaryVariant;
  static Color get secondary      => _p.secondary;
  static Color get accent         => _p.accent;
  static Color get success        => _p.success;
  static Color get warning        => _p.warning;
  static Color get error          => _p.error;
  static Color get background     => _p.background;
  static Color get surface        => _p.surface;
  static Color get surfaceVariant => _p.surfaceVariant;
  static Color get onBackground   => _p.onBackground;
  static Color get onSurface      => _p.onSurface;
  static Color get onPrimary      => _p.onPrimary;
  static Color get divider        => _p.divider;
}
