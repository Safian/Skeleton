import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeleton_shared/skeleton_shared.dart';
import '../../repositories/translation_repository.dart';

abstract class TranslationState extends Equatable {
  const TranslationState();
  @override
  List<Object?> get props => [];
}

/// Context-free translation access for non-widget code (cubits, services) that
/// has no [BuildContext] and therefore cannot use the `context.t()` extension.
/// Kept in sync by [TranslationCubit] every time translations load.
class AppTr {
  AppTr._();

  static Map<String, String> _dict = const {};
  static String _lang = 'hu';

  /// Updated by [TranslationCubit.loadTranslations].
  static void sync(Map<String, String> dict, String lang) {
    _dict = dict;
    _lang = lang;
  }

  /// Look up a translation key. Falls back to [OfflineTranslations] then [fallback].
  static String t(String key, [String? fallback]) {
    return _dict[key] ?? OfflineTranslations.get(key, _lang) ?? fallback ?? key;
  }
}

class TranslationInitial extends TranslationState {}

class TranslationLoading extends TranslationState {}

class TranslationLoaded extends TranslationState {
  final Map<String, String> dict;
  final String currentLang;

  const TranslationLoaded(this.dict, this.currentLang);

  String translate(String key, [String? defaultValue]) {
    return dict[key] ?? OfflineTranslations.get(key, currentLang) ?? defaultValue ?? key;
  }

  @override
  List<Object?> get props => [dict, currentLang];
}

const _kLangPrefKey = 'skeleton_selected_language';

class TranslationCubit extends Cubit<TranslationState> {
  final TranslationRepository _repository;
  String _currentLang = 'hu';

  TranslationCubit({required TranslationRepository repository})
      : _repository = repository,
        super(TranslationInitial());

  String get currentLang => _currentLang;

  Future<void> loadTranslations(String lang) async {
    _currentLang = lang;
    emit(TranslationLoading());
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLangPrefKey, lang);
    } catch (_) {}
    final dict = await _repository.fetchTranslations(lang);
    AppTr.sync(dict, lang);
    emit(TranslationLoaded(dict, lang));
  }
}
