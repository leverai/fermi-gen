import 'dart:async';

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
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSub;

  /// Initialize FCM and subscribe to DQ notifications topic.
  ///
  /// Should be called after Firebase.initializeApp() in main.dart.
  /// Initializes on Android and iOS (skips web).
  Future<void> initialize() async {
    if (_initialized) return;

    // Skip on web
    if (kIsWeb) {
      debugPrint('NotificationService: Skipping FCM init (web not supported)');
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
    _onMessageSub =
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app was in background/terminated
    _onMessageOpenedSub =
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

  /// Dispose subscriptions to prevent memory leaks.
  /// Should be called when the service is no longer needed (rarely needed for singleton).
  void dispose() {
    _onMessageSub?.cancel();
    _onMessageSub = null;
    _onMessageOpenedSub?.cancel();
    _onMessageOpenedSub = null;
  }
}
