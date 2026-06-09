// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';

Future<List<Map<String, dynamic>>> readPendingJsErrorsImpl() async {
  try {
    final raw = html.window.localStorage['skeleton_pending_js_errors'];
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.whereType<Map<String, dynamic>>().toList();
  } catch (_) {
    return [];
  }
}

Future<void> clearPendingJsErrorsImpl() async {
  try {
    html.window.localStorage.remove('skeleton_pending_js_errors');
  } catch (_) {}
}
