import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// PushNotificationService – FCM token regisztráció + értesítések
//
// ELŐFELTÉTEL (Firebase projekt konfig):
//   Android: android/app/google-services.json
//   iOS:     ios/Runner/GoogleService-Info.plist
//   Web:     firebase_options.dart + manifest VAPID key
//
// Inicializálás:
//   await PushNotificationService.instance.initialize();
// Login után:
//   await PushNotificationService.instance.registerToken(userId);
// Logout előtt:
//   await PushNotificationService.instance.unregisterToken(userId);
// ============================================================

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  // Background isolate – minimális logika
  debugPrint('[Push] bg message: ${message.messageId}');
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotif = FlutterLocalNotificationsPlugin();

  static const _channelId   = 'default_channel';
  static const _channelName = 'Értesítések';

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    try {
      // Engedélykérés
      await _messaging.requestPermission(
        alert: true, badge: true, sound: true,
      );

      // Lokális értesítő csatorna (Android 8+)
      const androidChannel = AndroidNotificationChannel(
        _channelId, _channelName,
        importance: Importance.high,
      );

      await _localNotif
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      await _localNotif.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS:     DarwinInitializationSettings(),
        ),
      );

      // Background handler
      FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

      // Foreground handler
      FirebaseMessaging.onMessage.listen(_showLocal);
    } catch (e) {
      debugPrint('[Push] initialize error: $e');
    }
  }

  Future<void> registerToken(String userId) async {
    if (kIsWeb) return;
    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      await Supabase.instance.client.from('user_push_tokens').upsert(
        {
          'user_id':    userId,
          'token':      token,
          'platform':   defaultTargetPlatform.name.toLowerCase(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,token',
      );

      debugPrint('[Push] token registered');
    } catch (e) {
      debugPrint('[Push] registerToken error: $e');
    }
  }

  Future<void> unregisterToken(String userId) async {
    if (kIsWeb) return;
    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      await Supabase.instance.client
          .from('user_push_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('token', token);

      await _messaging.deleteToken();
      debugPrint('[Push] token unregistered');
    } catch (e) {
      debugPrint('[Push] unregisterToken error: $e');
    }
  }

  void _showLocal(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;

    _localNotif.show(
      message.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: n.android?.imageUrl != null ? null : '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
