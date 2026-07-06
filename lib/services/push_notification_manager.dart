// lib/services/push_notification_manager.dart
//
// Wires up Firebase Cloud Messaging so the notification system that
// already exists on the backend (device_tokens table,
// pushNotificationService.js) can actually reach this app.
//
// IMPORTANT — this cannot fully work until three things are true, none of
// which this file can do on its own:
//   1. android/app/build.gradle.kts's applicationId is changed from the
//      placeholder "com.example.aquagas" to your real, final package name.
//   2. A real google-services.json (from the Firebase console, registered
//      under that exact applicationId) is placed in android/app/.
//   3. Firebase.initializeApp() (called from main.dart) succeeds — which
//      it can only do once #1 and #2 are in place.
//
// Everything below is written to fail safe: if Firebase isn't set up yet,
// initialize() just logs and returns instead of crashing the app, so it's
// safe to ship this now and finish the Firebase console side separately.
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_service.dart';

class PushNotificationManager {
  PushNotificationManager._();
  static final PushNotificationManager instance = PushNotificationManager._();

  final NotificationService _notificationService = NotificationService();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'aquagas_default',
    'AquaGas notifications',
    description: 'Order updates, delivery status, and account alerts',
    importance: Importance.high,
  );

  /// Call once the user is authenticated (right after login, and on app
  /// start if a session already exists) — registering a token requires the
  /// backend call to be authenticated.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      if (Firebase.apps.isEmpty) {
        // No google-services.json / Firebase.initializeApp() yet — see the
        // file header. Nothing to do until that's in place.
        debugPrint('⚠️ Firebase not initialized — push notifications disabled '
            'until google-services.json + applicationId are set up.');
        return;
      }

      await _setupLocalNotifications();

      final FirebaseMessaging messaging = FirebaseMessaging.instance;

      final NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('⚠️ Notification permission denied by user.');
        // Still mark initialized — nothing more to do until they change it
        // in system settings, and we don't want to re-prompt every launch.
        _initialized = true;
        return;
      }

      final String? token = await messaging.getToken();
      if (token != null) {
        await _notificationService.registerPushToken(
          token,
          platform: Platform.isIOS ? 'ios' : 'android',
        );
      }

      // Token can rotate — re-register whenever that happens.
      messaging.onTokenRefresh.listen((String newToken) {
        _notificationService.registerPushToken(
          newToken,
          platform: Platform.isIOS ? 'ios' : 'android',
        );
      });

      // FCM does not auto-display a notification while the app is in the
      // foreground — show one ourselves via flutter_local_notifications.
      FirebaseMessaging.onMessage.listen(_showForegroundNotification);

      _initialized = true;
      debugPrint('✅ Push notifications initialized, token registered.');
    } catch (e) {
      // Never let push-notification setup take the app down with it.
      debugPrint('⚠️ Push notification setup failed (non-fatal): $e');
    }
  }

  Future<void> _setupLocalNotifications() async {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();

    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  void _showForegroundNotification(RemoteMessage message) {
    final RemoteNotification? notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// Call on logout so this device stops receiving pushes meant for the
  /// account that just signed out.
  Future<void> unregister() async {
    if (!_initialized || Firebase.apps.isEmpty) return;
    try {
      final String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _notificationService.unregisterPushToken(token);
    } catch (_) {
      // Best-effort on logout.
    }
    _initialized = false;
  }
}
