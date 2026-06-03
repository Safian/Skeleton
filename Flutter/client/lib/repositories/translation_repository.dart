import 'package:supabase_flutter/supabase_flutter.dart';

class TranslationRepository {
  final SupabaseClient _supabaseClient;

  TranslationRepository({SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient ?? Supabase.instance.client;

  Future<Map<String, String>> fetchTranslations(String lang) async {
    try {
      final response = await _supabaseClient.from('translations').select('key, hu, locales');
      
      final Map<String, String> dict = {};
      for (final item in response as List) {
        final key = item['key'] as String;
        final hu = item['hu'] as String;
        final locales = item['locales'] as Map<String, dynamic>?;

        if (lang == 'hu') {
          dict[key] = hu;
        } else {
          dict[key] = locales?[lang] ?? locales?['en'] ?? hu;
        }
      }
      return dict;
    } catch (e) {
      return {};
    }
  }
}
