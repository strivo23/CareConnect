import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../core/services/api_client.dart';

// Background message handler for FCM (Android only)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kIsWeb) return;
  try {
    await Firebase.initializeApp();
    debugPrint('FCM Background message received: ${message.messageId}');
  } catch (e) {
    debugPrint('Error handling background FCM: $e');
  }
}

class FCMNotificationService {
  FCMNotificationService._();
  static final FCMNotificationService instance = FCMNotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  String? _fcmToken;
  GlobalKey<NavigatorState>? _navigatorKey;

  String? get fcmToken => _fcmToken;

  /// Initialize FCM, request permissions, configure local notifications & listeners (Android platform only).
  Future<void> initialize({GlobalKey<NavigatorState>? navigatorKey}) async {
    if (_isInitialized) return;
    _navigatorKey = navigatorKey;

    // Ignore Web as explicitly requested
    if (kIsWeb) {
      debugPrint('FCM configuration skipped on Web platform.');
      return;
    }

    try {
      // 1. Register background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 2. Request Notification Permission
      final NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('FCM Notification permission status: ${settings.authorizationStatus}');

      // 3. Initialize Flutter Local Notifications for Android
      const AndroidInitializationSettings androidInitSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings = InitializationSettings(android: androidInitSettings);

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // Create Android Notification Channel
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'careconnect_emergency_channel',
        'Emergency SOS Alerts',
        description: 'High priority notifications for emergency SOS incidents and community broadcasts.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // 4. Generate FCM Token & Send to Backend
      await _generateAndSendToken();

      // Listen to token refreshes
      _fcm.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        sendTokenToBackend(newToken);
      });

      // 5. Setup Foreground Notification Listener
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 6. Setup Background & Terminated Notification Tap Handlers
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // Handle launch from terminated state
      final RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }

      _isInitialized = true;
      debugPrint('FCM Notification Service initialized successfully.');
    } catch (e) {
      debugPrint('Failed to initialize FCM Notification Service: $e');
    }
  }

  /// Generate FCM Token and upload to backend database.
  Future<void> _generateAndSendToken() async {
    try {
      _fcmToken = await _fcm.getToken();
      if (_fcmToken != null && _fcmToken!.isNotEmpty) {
        debugPrint('Generated FCM Device Token: $_fcmToken');
        await sendTokenToBackend(_fcmToken!);
      }
    } catch (e) {
      debugPrint('Error generating FCM token: $e');
    }
  }

  /// Send token to backend API: POST /api/notifications/devices/ or /register-token/
  Future<bool> sendTokenToBackend(String token) async {
    try {
      final response = await ApiClient.instance.post(
        '/api/notifications/devices/',
        data: {'token': token},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('FCM Device token registered with backend successfully.');
        return true;
      }
    } catch (e) {
      debugPrint('Error registering FCM token with backend: $e');
    }
    return false;
  }

  /// Handle foreground messages by rendering notification in Android Notification Center.
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Foreground FCM message received: ${message.notification?.title}');

    final notification = message.notification;
    final data = message.data;

    final title = notification?.title ?? data['title'] ?? 'CareConnect Alert';
    final body = notification?.body ?? data['body'] ?? 'New notification received';

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'careconnect_emergency_channel',
      'Emergency SOS Alerts',
      channelDescription: 'High priority notifications for emergency SOS incidents',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      color: Color(0xFFEF4444),
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: platformDetails,
      payload: jsonEncode(data),
    );
  }


  /// Handle tap on notification in Android Notification Center.
  void _onNotificationTap(NotificationResponse response) {
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        final Map<String, dynamic> data = jsonDecode(response.payload!);
        _navigateToIncidentDetails(data);
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }
  }

  /// Handle tap when app is opened from FCM background state.
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('FCM Notification tapped: ${message.data}');
    _navigateToIncidentDetails(message.data);
  }

  /// Navigate to incident details screen when notification is clicked.
  void _navigateToIncidentDetails(Map<String, dynamic> data) {
    final incidentIdStr = data['incident_id'] ?? data['incidentId'] ?? data['id'];
    if (incidentIdStr != null) {
      final incidentId = int.tryParse(incidentIdStr.toString());
      if (incidentId != null && _navigatorKey?.currentContext != null) {
        final context = _navigatorKey!.currentContext!;
        GoRouter.of(context).push('/sos-message', extra: {
          'incidentId': incidentId,
        });
      }
    }
  }
}
