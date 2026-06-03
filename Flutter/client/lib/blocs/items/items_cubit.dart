import 'package:bloc/bloc.dart';
import '../../repositories/items_repository.dart';
import 'items_state.dart';

// ============================================================
// ItemsCubit – lista betöltése / frissítése
// ============================================================

class ItemsCubit extends Cubit<ItemsState> {
  final ItemsRepository _repo;

  ItemsCubit({required ItemsRepository repository})
      : _repo = repository,
        super(ItemsInitial());

  Future<void> loadItems() async {
    emit(ItemsLoading());
    try {
      final items = await _repo.fetchItems();
      emit(ItemsLoaded(items));
    } catch (e) {
      emit(ItemsError('Nem sikerült betölteni az elemeket: $e'));
    }
  }

  Future<void> refresh() => loadItems();
}
