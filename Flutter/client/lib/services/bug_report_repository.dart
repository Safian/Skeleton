import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// BugReportRepository  [M4.1]
//
// Multipart upload a `bug-report` Edge Function-ra.
// Képet + JSON metaadatokat küld el.
// ============================================================

class BugReportRepository {
  BugReportRepository._();
  static final BugReportRepository instance = BugReportRepository._();

  Future<void> submit({
    required String title,
    required String description,
    required String priority,       // 'low' | 'medium' | 'high' | 'critical'
    required String routeName,
    required List<String> logs,
    required Map<String, String> deviceInfo,
    Uint8List? screenshotPng,
  }) async {
    try {
      final client = Supabase.instance.client;

      // Fájl nélküli path: JSON body
      final body = <String, dynamic>{
        'title':       title,
        'description': description,
        'priority':    priority,
        'route':       routeName,
        'logs':        logs,
        'device_info': deviceInfo,
      };

      if (screenshotPng != null) {
        // Az Edge Function multipart-ot vár, ha screenshot van.
        // A supabase_flutter .invoke() nem támogat natívan multipart-ot,
        // ezért az `http` csomag közvetlen hívással küldjük.
        await _uploadWithScreenshot(
          client: client,
          body: body,
          screenshotPng: screenshotPng,
        );
      } else {
        await client.functions.invoke('bug-report', body: body);
      }
    } catch (e) {
      debugPrint('[BugReport] submit error: $e');
      rethrow;
    }
  }

  Future<void> _uploadWithScreenshot({
    required SupabaseClient client,
    required Map<String, dynamic> body,
    required Uint8List screenshotPng,
  }) async {
    // Az Edge Function `/bug-report` végpontja a `Content-Type: application/json`
    // kéréseket fogadja – a screenshot Base64-ként utazik a body-ban.
    body['screenshot_base64'] = _base64Encode(screenshotPng);
    await client.functions.invoke('bug-report', body: body);
  }

  String _base64Encode(Uint8List data) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final output = StringBuffer();
    for (var i = 0; i < data.length; i += 3) {
      final b0 = data[i];
      final b1 = i + 1 < data.length ? data[i + 1] : 0;
      final b2 = i + 2 < data.length ? data[i + 2] : 0;
      output.write(chars[(b0 >> 2) & 0x3F]);
      output.write(chars[((b0 << 4) | (b1 >> 4)) & 0x3F]);
      output.write(i + 1 < data.length ? chars[((b1 << 2) | (b2 >> 6)) & 0x3F] : '=');
      output.write(i + 2 < data.length ? chars[b2 & 0x3F] : '=');
    }
    return output.toString();
  }
}
