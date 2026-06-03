import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/translation/translation_cubit.dart';
import 'codebase_translations.dart';

extension TranslationExtension on BuildContext {
  /// Fordítási kulcs feloldása. Sorrend:
  ///   1. Backend (TranslationCubit) – runtime, AI-bővíthető (új nyelvek is)
  ///   2. Beépített offline készlet (codebaseTranslations) az aktív nyelven –
  ///      bejelentkezés előtt / hálózat nélkül is működik (pl. login, maintenance)
  ///   3. Inline fallback vagy maga a kulcs
  ///
  /// Usage:  context.t('auth.login')
  ///         context.t('ui.save', 'Mentés')
  String t(String key, [String? fallback]) {
    final state = read<TranslationCubit>().state;
    final lang = state is TranslationLoaded ? state.currentLang : 'hu';

    // 1. Backend érték (ha be van töltve és nem üres)
    if (state is TranslationLoaded) {
      final backendVal = state.dict[key];
      if (backendVal != null && backendVal.isNotEmpty) return backendVal;
    }

    // 2. Beépített offline készlet az aktív nyelven (hu-ra esik vissza)
    final cb = codebaseTranslations[key];
    if (cb != null) {
      final cbVal = cb[lang] ?? cb['hu'];
      if (cbVal != null && cbVal.isNotEmpty) return cbVal;
    }

    // 3. Inline fallback vagy a nyers kulcs
    return fallback ?? key;
  }

  /// Az aktuális UI nyelvkód ('hu', 'en', 'de', …).
  String get currentLang {
    final state = read<TranslationCubit>().state;
    return state is TranslationLoaded ? state.currentLang : 'hu';
  }
}
