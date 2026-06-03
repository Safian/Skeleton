import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/item.dart';

// ============================================================
// ItemsRepository – demo CRUD a lista képernyőhöz
// Projektenként cseréld le a valódi repository-ra.
// ============================================================

class ItemsRepository {
  final SupabaseClient _db;

  ItemsRepository({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  Future<List<Item>> fetchItems() async {
    final res = await _db
        .from('items')
        .select()
        .order('created_at', ascending: false);
    return (res as List).map((j) => Item.fromJson(j)).toList();
  }

  Future<Item?> fetchItem(String id) async {
    try {
      final res = await _db.from('items').select().eq('id', id).single();
      return Item.fromJson(res);
    } catch (_) {
      return null;
    }
  }

  Future<void> createItem({
    required String title,
    String? description,
    String? category,
  }) async {
    await _db.from('items').insert({
      'title':       title,
      'description': description,
      'category':    category,
      'is_active':   true,
    });
  }

  Future<void> updateItem(String id, {
    String? title,
    String? description,
    bool? isActive,
  }) async {
    await _db.from('items').update({
      if (title != null)       'title':       title,
      if (description != null) 'description': description,
      if (isActive != null)    'is_active':   isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deleteItem(String id) async {
    await _db.from('items').delete().eq('id', id);
  }
}
