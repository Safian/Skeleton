import 'package:bloc/bloc.dart';
import '../../repositories/admin_repository.dart';
import 'users_state.dart';

// ============================================================
// UsersCubit – felhasználólista + statisztikák kezelése
// ============================================================

class UsersCubit extends Cubit<UsersState> {
  final AdminRepository _repo;

  UsersCubit({required AdminRepository repository})
      : _repo = repository,
        super(UsersInitial());

  Future<void> load() async {
    emit(UsersLoading());
    try {
      // Párhuzamos indítás, erős típussal
      final usersFuture = _repo.getAllUsers();
      final statsFuture = _repo.getStats();
      final users = await usersFuture;
      final stats = await statsFuture;
      emit(UsersLoaded(users: users, stats: stats));
    } catch (e) {
      emit(UsersError('Nem sikerült betölteni: $e'));
    }
  }

  Future<void> refresh() => load();

  void search(String query) {
    final s = state;
    if (s is UsersLoaded) {
      emit(s.copyWith(searchQuery: query));
    }
  }

  Future<void> updateRole(String userId, String newRole) async {
    final s = state;
    if (s is! UsersLoaded) return;
    emit(UsersUpdating(users: s.users, stats: s.stats, searchQuery: s.searchQuery));
    try {
      await _repo.updateUserRole(userId, newRole);
      // Frissítjük a listát lokálisan
      final updated = s.users.map((u) =>
        u.id == userId ? u.copyWith(role: newRole) : u).toList();
      emit(s.copyWith(users: updated));
    } catch (e) {
      emit(UsersError('Szerepkör módosítás sikertelen: $e'));
      emit(s.copyWith()); // friss példány – Equatable dedup elkerülése
    }
  }
}
