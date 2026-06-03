import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

// ============================================================
// App Typography – Google Fonts alapú
// ============================================================

class AppTextStyles {
  final TextStyle displayLarge;
  final TextStyle displayMedium;
  final TextStyle titleLarge;
  final TextStyle titleMedium;
  final TextStyle titleSmall;
  final TextStyle bodyLarge;
  final TextStyle bodyMedium;
  final TextStyle bodySmall;
  final TextStyle label;
  final TextStyle eyebrow;
  final TextStyle button;
  final TextStyle mono;

  const AppTextStyles({
    required this.displayLarge,
    required this.displayMedium,
    required this.titleLarge,
    required this.titleMedium,
    required this.titleSmall,
    required this.bodyLarge,
    required this.bodyMedium,
    required this.bodySmall,
    required this.label,
    required this.eyebrow,
    required this.button,
    required this.mono,
  });

  static AppTextStyles build(AppColorPalette colors) {
    final text = colors.onBackground;
    return AppTextStyles(
      displayLarge: GoogleFonts.inter(
        fontSize: 36, fontWeight: FontWeight.w800,
        color: text, letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 28, fontWeight: FontWeight.w800,
        color: text, letterSpacing: -0.3,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 22, fontWeight: FontWeight.w700, color: text,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 18, fontWeight: FontWeight.w700, color: text,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w600, color: text,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16, fontWeight: FontWeight.w400, color: text,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w400, color: text,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12, fontWeight: FontWeight.w400,
        color: text.withValues(alpha: 0.6),
      ),
      label: GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w500, color: text,
      ),
      eyebrow: GoogleFonts.inter(
        fontSize: 11, fontWeight: FontWeight.w700,
        color: text.withValues(alpha: 0.5), letterSpacing: 0.8,
      ),
      button: GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w600, color: colors.onPrimary,
      ),
      mono: GoogleFonts.firaCode(
        fontSize: 13, fontWeight: FontWeight.w400, color: text,
      ),
    );
  }
}

class AppTypography {
  AppTypography._();

  static AppTextStyles _styles = AppTextStyles.build(AppColorPalette.dark);
  static void rebuild(AppColorPalette colors) =>
      _styles = AppTextStyles.build(colors);

  static TextStyle get displayLarge  => _styles.displayLarge;
  static TextStyle get displayMedium => _styles.displayMedium;
  static TextStyle get titleLarge    => _styles.titleLarge;
  static TextStyle get titleMedium   => _styles.titleMedium;
  static TextStyle get titleSmall    => _styles.titleSmall;
  static TextStyle get bodyLarge     => _styles.bodyLarge;
  static TextStyle get bodyMedium    => _styles.bodyMedium;
  static TextStyle get bodySmall     => _styles.bodySmall;
  static TextStyle get label         => _styles.label;
  static TextStyle get eyebrow       => _styles.eyebrow;
  static TextStyle get button        => _styles.button;
  static TextStyle get mono          => _styles.mono;
}
