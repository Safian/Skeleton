// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void clearSupabaseLocalStorageImpl() {
  try {
    final keys = html.window.localStorage.keys.toList();
    for (final key in keys) {
      if (key.startsWith('sb-') || key.contains('auth-token')) {
        html.window.localStorage.remove(key);
      }
    }
  } catch (_) {}
}
