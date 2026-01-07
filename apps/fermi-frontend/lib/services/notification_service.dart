import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

/// Service for handling push notifications via Firebase Cloud Messaging.
///
/// Subscribes to the `dq_notifications` topic to receive Daily Question
/// notifications (activation at 12PM UTC, results at 2AM UTC).
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  /// Topic for Daily Question notifications.
  static const String _dqTopic = 'dq_notifications';

  bool _initialized = false;

  /// Initialize FCM and subscribe to DQ notifications topic.
  ///
  /// Should be called after Firebase.initializeApp() in main.dart.
  /// Only initializes on Android (skips web and iOS for now).
  Future<void> initialize() async {
    if (_initialized) return;

    // Only initialize on Android for now
    if (kIsWeb || !Platform.isAndroid) {
      debugPrint('NotificationService: Skipping FCM init (not Android)');
      return;
    }

    final messaging = FirebaseMessaging.instance;

    // Request permission (Android 13+ requires this)
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('NotificationService: Permission denied');
      return;
    }

    // Subscribe to DQ notifications topic
    await messaging.subscribeToTopic(_dqTopic);
    debugPrint('NotificationService: Subscribed to $_dqTopic');

    // Handle foreground messages (show as snackbar or ignore)
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app was in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened via notification tap (cold start)
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    _initialized = true;
    debugPrint('NotificationService: Initialized');
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint(
      'NotificationService: Foreground message: ${message.notification?.title}',
    );
    // Foreground notifications are shown automatically on Android
    // No additional handling needed
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint(
      'NotificationService: Notification tapped: ${message.data}',
    );
    // Navigation is handled by deep links or the app's natural flow
    // The user will land on the main screen which shows DQ status
  }
}
