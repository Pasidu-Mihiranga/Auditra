import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'firebase_service.dart';
import 'firebase_user_service.dart';
import 'api_service.dart';

/// Service for handling push notifications
class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseService.messaging;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static BuildContext? _context;

  /// Initialize notification service
  static Future<void> initialize(BuildContext? context) async {
    _context = context;

    // Request permissions
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted notification permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('User granted provisional notification permission');
    } else {
      print('User declined or has not accepted notification permission');
    }

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'chat_messages',
      'Chat Messages',
      description: 'Notifications for new chat messages',
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Get FCM token
    String? token = await _messaging.getToken();
    if (token != null) {
      await _saveFCMToken(token);
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      _saveFCMToken(newToken);
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages (when app is in background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
  }

  /// Save FCM token to Firestore
  static Future<void> _saveFCMToken(String token) async {
    try {
      final userId = await ApiService.getUserId();
      if (userId != null) {
        await FirebaseUserService.updateFCMToken(userId, token);
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  /// Handle foreground message (app is open)
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Foreground message received: ${message.messageId}');

    // Show local notification
    if (message.notification != null) {
      await _showLocalNotification(
        message.notification!.title ?? 'New Message',
        message.notification!.body ?? '',
        message.data,
      );
    }
  }

  /// Handle background message (app was opened from notification)
  static void _handleBackgroundMessage(RemoteMessage message) {
    print('Background message opened: ${message.messageId}');
    // Navigation will be handled by the app
    _navigateToChat(message.data);
  }

  /// Show local notification
  static Future<void> _showLocalNotification(
    String title,
    String body,
    Map<String, dynamic> data,
  ) async {
    const androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'Chat Messages',
      channelDescription: 'Notifications for new chat messages',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      notificationDetails,
      payload: data.toString(),
    );
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      // Parse payload and navigate to chat
      // This will be handled by the app's navigation system
      print('Notification tapped: ${response.payload}');
    }
  }

  /// Navigate to chat screen based on notification data
  static void _navigateToChat(Map<String, dynamic> data) {
    if (_context == null) return;

    final chatId = data['chatId'];
    if (chatId != null) {
      // Navigation will be handled by the app
      // This is a placeholder - actual navigation depends on app structure
      print('Navigate to chat: $chatId');
    }
  }

  /// Background message handler (must be top-level function)
  static Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    print('Background message: ${message.messageId}');
    // Handle background message
    // This is called when app is in background
  }
}

