// ============================================================
// App Sizes & Spacing Tokens
// ============================================================

class AppRadius {
  AppRadius._();
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 12;
  static const double lg  = 16;
  static const double xl  = 20;
  static const double xxl = 28;
  static const double pill = 9999;
}

class AppSpacing {
  AppSpacing._();
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 16;
  static const double lg  = 24;
  static const double xl  = 32;
  static const double xxl = 48;
}

class AppIconSize {
  AppIconSize._();
  static const double sm  = 16;
  static const double md  = 20;
  static const double lg  = 24;
  static const double xl  = 32;
  static const double xxl = 48;
}

// Backwards-compat alias – maps to AppSpacing values
class AppSizes {
  AppSizes._();
  static const double xs       = AppSpacing.xs;
  static const double sm       = AppSpacing.sm;
  static const double md       = AppSpacing.md;
  static const double lg       = AppSpacing.lg;
  static const double xl       = AppSpacing.xl;
  static const double xxl      = AppSpacing.xxl;
  static const double radiusMd = AppRadius.md;
  static const double radiusLg = AppRadius.lg;
}
