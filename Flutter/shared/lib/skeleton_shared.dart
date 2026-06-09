/// skeleton_shared – megosztott UI komponensek, téma és modellek
///
/// Használat:
///   import 'package:skeleton_shared/skeleton_shared.dart';

// Theme
export 'core/theme/app_colors.dart';
export 'core/theme/app_sizes.dart';
export 'core/theme/app_theme.dart';
export 'core/theme/app_typography.dart';

// Components
export 'core/components/components.dart';

// Models
export 'models/legal_document.dart';
export 'models/translation_entry.dart';
export 'models/user_profile.dart';

// Core
export 'core/offline_translations.dart';
export 'core/foreground_push_overlay.dart'; // includes foreground_push_message.dart
export 'core/foreground_push_banner.dart';
export 'core/js_error_flusher.dart';
export 'core/local_storage_cleaner.dart';

// Services
export 'services/remote_config.dart';
export 'services/log_service.dart';
