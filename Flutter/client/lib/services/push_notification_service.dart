import 'dart:async';

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
//
// MEGJEGYZÉS (2026-06-06, min OS: iOS 18+ / Android API 29+):
// A modern push API-k (APNs token, runtime notification permission, FCM
// token refresh stream) garantáltan elérhetők ezeken a minimum verziókon –
// nincs szükség legacy verzió-elágazásokra (pl. `if (androidSdk < 33)`).
// ============================================================

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  // Background isolate – minimális logika
  debugPrint('[Push] bg message: ${message.messageId}');
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  // Lazy getter – Firebase.initializeApp() nélkül is biztonságos példányosítás.
  // Az exception csak az initialize() try-catch blokkján belül keletkezhet.
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final _localNotif = FlutterLocalNotificationsPlugin();

  static const _channelId   = 'default_channel';
  static const _channelName = 'Értesítések';

  bool _initialized = false;

  /// A token-frissítési listener leiratkozása minden új regisztráció előtt
  /// szükséges, különben újra-bejelentkezéskor több listener halmozódik fel
  /// és duplikált upsert hívásokat eredményez.
  StreamSubscription<String>? _tokenRefreshSub;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    try {
      // Engedélykérés
      final settings = await _messaging.requestPermission(
        alert: true, badge: true, sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        await _logError(
          type: 'push_permission_denied',
          message: 'A felhasználó elutasította az értesítési engedélyt.',
        );
      }

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
      await _logError(
        type: 'push_initialize_error',
        message: 'Push inicializálási hiba: $e',
      );
    }
  }

  Future<void> registerToken(String userId) async {
    if (kIsWeb) return;
    try {
      // iOS: az FCM token lekérése előtt meg kell várni az APNs tokent,
      // különben a getToken() null-lal vagy hibával térhet vissza (race
      // condition az APNs regisztráció és az FCM SDK között).
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        String? apnsToken;
        for (var i = 0; i < 10; i++) {
          apnsToken = await _messaging.getAPNSToken();
          if (apnsToken != null) break;
          await Future.delayed(const Duration(seconds: 1));
        }
        if (apnsToken == null) {
          await _logError(
            type: 'push_apns_token_timeout',
            message: 'Az APNs token nem érkezett meg 10 másodperc alatt.',
            context: {'user_id': userId},
          );
          return;
        }
      }

      final token = await _messaging.getToken();
      if (token == null) {
        await _logError(
          type: 'push_fcm_token_null',
          message: 'Az FCM token lekérése null értéket adott vissza.',
          context: {'user_id': userId},
        );
        return;
      }

      await _upsertToken(userId, token);
      debugPrint('[Push] token registered');

      // Token-frissítés figyelése: a régi feliratkozás leiratkoztatása,
      // majd újra feliratkozás – elkerülve a duplikált listenereket
      // ismételt bejelentkezés esetén.
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) async {
        try {
          await _upsertToken(userId, newToken);
          debugPrint('[Push] token refreshed & re-registered');
        } catch (e) {
          debugPrint('[Push] onTokenRefresh upsert error: $e');
          await _logError(
            type: 'push_token_refresh_error',
            message: 'Token frissítés utáni regisztráció sikertelen: $e',
            context: {'user_id': userId},
          );
        }
      });
    } catch (e) {
      debugPrint('[Push] registerToken error: $e');
      await _logError(
        type: 'push_register_token_error',
        message: 'Token regisztrációs hiba: $e',
        context: {'user_id': userId},
      );
    }
  }

  Future<void> unregisterToken(String userId) async {
    if (kIsWeb) return;
    try {
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = null;

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
      await _logError(
        type: 'push_unregister_token_error',
        message: 'Token leiratkozási hiba: $e',
        context: {'user_id': userId},
      );
    }
  }

  Future<void> _upsertToken(String userId, String token) async {
    await Supabase.instance.client.from('user_push_tokens').upsert(
      {
        'user_id':    userId,
        'token':      token,
        'platform':   defaultTargetPlatform.name.toLowerCase(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id,token',
    );
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

  /// Könnyűsúlyú hibanaplózás az `app_error_logs` táblába.
  ///
  /// A Skeletonban nincs központi LogService (ellentétben a KibbiAi
  /// `LogService`-szel) – ahelyett, hogy egy teljes többcélú naplózó
  /// osztályt portolnánk át (ami sok KibbiAi-specifikus hibakategóriát
  /// hordozna), egy minimális inline helper írja közvetlenül a már
  /// létező `app_error_logs` táblát (RLS: saját bejegyzés beszúrása
  /// engedélyezett `user_id = auth.uid()` esetén). Ez „fail open” módon
  /// fut – a naplózási hiba sosem akadályozza a push-funkció működését.
  Future<void> _logError({
    required String type,
    required String message,
    Map<String, dynamic>? context,
  }) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      await Supabase.instance.client.from('app_error_logs').insert({
        'app': 'client',
        'user_id': userId,
        'error_type': type,
        'error_message': message,
        'context': context ?? <String, dynamic>{},
      });
    } catch (e) {
      // Naplózási hiba nem szabad, hogy megszakítsa a push folyamatot.
      debugPrint('[Push] _logError insert failed: $e');
    }
  }
}
