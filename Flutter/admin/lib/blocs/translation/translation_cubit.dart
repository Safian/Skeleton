import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../repositories/translation_repository.dart';

abstract class TranslationState extends Equatable {
  const TranslationState();
  @override
  List<Object?> get props => [];
}

class TranslationInitial extends TranslationState {}

class TranslationLoading extends TranslationState {}

class TranslationLoaded extends TranslationState {
  final Map<String, String> dict;
  final String currentLang;

  const TranslationLoaded(this.dict, this.currentLang);

  String translate(String key, [String? defaultValue]) {
    return dict[key] ?? defaultValue ?? key;
  }

  @override
  List<Object?> get props => [dict, currentLang];
}

class TranslationCubit extends Cubit<TranslationState> {
  final TranslationRepository _repository;

  TranslationCubit({required TranslationRepository repository})
      : _repository = repository,
        super(TranslationInitial());

  Future<void> loadTranslations(String lang) async {
    emit(TranslationLoading());
    final dict = await _repository.fetchTranslations(lang);
    emit(TranslationLoaded(dict, lang));
  }
}
