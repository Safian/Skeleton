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

  Future<void> deleteItem(String id) async {
    try {
      await _repo.deleteItem(id);
      final s = state;
      if (s is ItemsLoaded) {
        emit(ItemsLoaded(s.items.where((i) => i.id != id).toList()));
      }
    } catch (e) {
      emit(ItemsError('Törlés sikertelen: $e'));
      await loadItems();
    }
  }

  Future<void> updateItem(String id, {String? title, String? description}) async {
    try {
      await _repo.updateItem(id, title: title, description: description);
      await loadItems();
    } catch (e) {
      emit(ItemsError('Módosítás sikertelen: $e'));
    }
  }
}
