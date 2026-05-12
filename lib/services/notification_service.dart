import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/remote/supabase_client.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages are shown automatically by FCM on Android.
  // No action needed here unless custom processing is required.
}

class NotificationService {
  static final _fcm   = FirebaseMessaging.instance;
  static final _local = FlutterLocalNotificationsPlugin();

  static const _channelId   = 'labtrack_alerts';
  static const _channelName = 'LabTrack Alerts';

  static Future<void> init() async {
    // Not supported on non-mobile platforms
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) return;

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    // Android notification channel
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Stock alerts and expiry warnings',
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Init local notifications (for foreground display)
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS:     DarwinInitializationSettings(),
      ),
    );

    // Show notification when app is in foreground
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _local.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority:   Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    });

    // Save token to Supabase
    await _saveToken();

    // Refresh token when it rotates
    _fcm.onTokenRefresh.listen(_upsertToken);
  }

  static Future<bool> isEnabled() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return false;
    final data = await supabase
        .from('fcm_tokens')
        .select('token')
        .eq('user_id', userId)
        .maybeSingle();
    return data != null;
  }

  static Future<void> disable() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    await _fcm.deleteToken();
    await supabase.from('fcm_tokens').delete().eq('user_id', userId);
  }

  static Future<void> _saveToken() async {
    final token = await _fcm.getToken();
    if (token != null) await _upsertToken(token);
  }

  static Future<void> _upsertToken(String token) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    await supabase.from('fcm_tokens').upsert(
      {'user_id': userId, 'token': token},
      onConflict: 'user_id,token',
    );
  }
}
