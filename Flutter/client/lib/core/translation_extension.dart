import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/translation/translation_cubit.dart';

extension TranslationExtension on BuildContext {
  /// Look up a translation key. Falls back to [fallback] or the raw key if not found.
  /// Usage:  context.t('auth.login_button')
  ///         context.t('ui.save', 'Mentés')
  String t(String key, [String? fallback]) {
    final state = read<TranslationCubit>().state;
    if (state is TranslationLoaded) {
      return state.translate(key, fallback);
    }
    return fallback ?? key;
  }

  /// Returns the currently active UI language code ('hu', 'en', 'de', …).
  String get currentLang {
    final state = read<TranslationCubit>().state;
    return state is TranslationLoaded ? state.currentLang : 'hu';
  }
}
