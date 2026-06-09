import 'package:skeleton_shared/skeleton_shared.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../repositories/admin_repository.dart';

abstract class AdminState extends Equatable {
  const AdminState();
  @override
  List<Object?> get props => [];
}

class AdminInitial extends AdminState {}

class AdminLoading extends AdminState {}

class AdminLoaded extends AdminState {
  final List<UserProfile> users;
  final List<TranslationEntry> translations;
  final List<LegalDocument> legalDocuments;

  const AdminLoaded({
    required this.users,
    required this.translations,
    required this.legalDocuments,
  });

  @override
  List<Object?> get props => [users, translations, legalDocuments];
}

class AdminError extends AdminState {
  final String message;
  const AdminError(this.message);
  @override
  List<Object?> get props => [message];
}

class AdminCubit extends Cubit<AdminState> {
  final AdminRepository _repository;

  AdminCubit({required AdminRepository repository})
      : _repository = repository,
        super(AdminInitial());

  Future<void> initAdmin() async {
    emit(AdminLoading());
    try {
      final results = await Future.wait([
        _repository.getAllUsers(),
        _repository.fetchAllTranslations(),
        _repository.fetchAllLegalDocuments(),
      ]);
      emit(AdminLoaded(
        users: results[0] as List<UserProfile>,
        translations: results[1] as List<TranslationEntry>,
        legalDocuments: results[2] as List<LegalDocument>,
      ));
    } catch (e) {
      emit(AdminError('Hiba az adatok betöltésekor: $e'));
    }
  }

  Future<void> createTranslation(TranslationEntry entry) async {
    try {
      await _repository.createTranslation(entry);
      await initAdmin();
    } catch (e) {
      emit(AdminError('Hiba a fordítás létrehozásakor: $e'));
    }
  }

  Future<void> updateTranslation(String oldKey, TranslationEntry entry) async {
    try {
      await _repository.updateTranslation(oldKey, entry);
      await initAdmin();
    } catch (e) {
      emit(AdminError('Hiba a fordítás frissítésekor: $e'));
    }
  }

  Future<void> deleteTranslation(String key) async {
    try {
      await _repository.deleteTranslation(key);
      await initAdmin();
    } catch (e) {
      emit(AdminError('Hiba a fordítás törlésekor: $e'));
    }
  }

  Future<void> updateLegalDocument(LegalDocument doc) async {
    try {
      await _repository.updateLegalDocument(doc);
      await initAdmin();
    } catch (e) {
      emit(AdminError('Hiba a dokumentum mentésekor: $e'));
    }
  }
}
