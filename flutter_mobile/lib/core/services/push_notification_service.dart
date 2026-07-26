import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import '../../services/notification_repository.dart';

class PushNotificationService {
  PushNotificationService._privateConstructor();
  static final PushNotificationService instance = PushNotificationService._privateConstructor();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final NotificationRepository _notificationRepo = NotificationRepository();

  FirebaseMessaging? _messaging;
  bool _initialized = false;
  bool _supported = true;
  String? _fcmToken;

  Future<void> init() async {
    // Prevent duplicate initialization
    if (_initialized) {
      debugPrint('[PushNotificationService] Already initialized. Skipping.');
      return;
    }

    try {
      // Ensure Firebase app is initialized (guarantee max 1 call)
      if (Firebase.apps.isEmpty) {
        try {
          await Firebase.initializeApp();
          debugPrint('[PushNotificationService] Firebase initialized inside PushNotificationService.');
        } on FirebaseException catch (e) {
          debugPrint('[PushNotificationService] FirebaseException during initializeApp: ${e.code} - ${e.message}');
          if (kIsWeb) {
            _supported = false;
            _initialized = true;
            return;
          }
        } on PlatformException catch (e) {
          debugPrint('[PushNotificationService] PlatformException during initializeApp: ${e.code} - ${e.message}');
          if (kIsWeb) {
            _supported = false;
            _initialized = true;
            return;
          }
        } on Exception catch (e) {
          debugPrint('[PushNotificationService] Exception during initializeApp: $e');
          if (kIsWeb) {
            _supported = false;
            _initialized = true;
            return;
          }
        } catch (e) {
          debugPrint('[PushNotificationService] Error during initializeApp: $e');
          if (kIsWeb) {
            _supported = false;
            _initialized = true;
            return;
          }
        }
      }

      // Check if FirebaseMessaging is supported (especially on Web)
      if (kIsWeb) {
        try {
          final bool isSupported = await FirebaseMessagingPlatform.instance.isSupported();
          if (!isSupported) {
            debugPrint('[PushNotificationService] Warning: FirebaseMessagingPlatform.instance.isSupported() returned false on Web. Skipping FCM setup.');
            _supported = false;
            _initialized = true;
            return;
          }
        } on FirebaseException catch (e) {
          debugPrint('[PushNotificationService] Warning: FirebaseException checking web messaging support: ${e.code} - ${e.message}');
          _supported = false;
          _initialized = true;
          return;
        } on PlatformException catch (e) {
          debugPrint('[PushNotificationService] Warning: PlatformException checking web messaging support: ${e.code} - ${e.message}');
          _supported = false;
          _initialized = true;
          return;
        } on Exception catch (e) {
          debugPrint('[PushNotificationService] Warning: Exception checking web messaging support: $e');
          _supported = false;
          _initialized = true;
          return;
        } catch (e) {
          debugPrint('[PushNotificationService] Warning: Error checking web messaging support: $e');
          _supported = false;
          _initialized = true;
          return;
        }
      }

      // Lazily obtain FirebaseMessaging instance ONLY after confirming support & initialization
      try {
        _messaging = FirebaseMessaging.instance;
      } on FirebaseException catch (e) {
        debugPrint('[PushNotificationService] FirebaseException accessing FirebaseMessaging.instance: ${e.code} - ${e.message}');
        _supported = false;
        _initialized = true;
        return;
      } on PlatformException catch (e) {
        debugPrint('[PushNotificationService] PlatformException accessing FirebaseMessaging.instance: ${e.code} - ${e.message}');
        _supported = false;
        _initialized = true;
        return;
      } on Exception catch (e) {
        debugPrint('[PushNotificationService] Exception accessing FirebaseMessaging.instance: $e');
        _supported = false;
        _initialized = true;
        return;
      } catch (e) {
        debugPrint('[PushNotificationService] Error accessing FirebaseMessaging.instance: $e');
        _supported = false;
        _initialized = true;
        return;
      }

      // Only request permissions if supported
      await _requestPermissions();

      // Do NOT initialize flutter_local_notifications on Web
      if (!kIsWeb) {
        await _setupLocalNotifications();
      }

      await _setupInteractors();
      await _getToken();
      _setupTokenRefresh();

      _initialized = true;
      debugPrint('[PushNotificationService] PushNotificationService initialized successfully on ${kIsWeb ? "Web" : "Native"}.');
    } on FirebaseException catch (e) {
      debugPrint('[PushNotificationService] FirebaseException in init: ${e.code} - ${e.message}');
      _supported = false;
      _initialized = true;
    } on PlatformException catch (e) {
      debugPrint('[PushNotificationService] PlatformException in init: ${e.code} - ${e.message}');
      _supported = false;
      _initialized = true;
    } on Exception catch (e) {
      debugPrint('[PushNotificationService] Exception in init: $e');
      _supported = false;
      _initialized = true;
    } catch (e, stackTrace) {
      debugPrint('[PushNotificationService] Unexpected error in init: $e\n$stackTrace');
      _supported = false;
      _initialized = true;
    }
  }

  Future<void> _requestPermissions() async {
    if (_messaging == null || !_supported) return;

    try {
      NotificationSettings settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('[PushNotificationService] User granted notification permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('[PushNotificationService] User granted provisional permission');
      } else {
        debugPrint('[PushNotificationService] User declined or has not accepted notification permission');
      }
    } on FirebaseException catch (e) {
      debugPrint('[PushNotificationService] FirebaseException requesting permissions: ${e.code} - ${e.message}');
    } on PlatformException catch (e) {
      debugPrint('[PushNotificationService] PlatformException requesting permissions: ${e.code} - ${e.message}');
    } on Exception catch (e) {
      debugPrint('[PushNotificationService] Exception requesting permissions: $e');
    } catch (e) {
      debugPrint('[PushNotificationService] Error requesting permissions: $e');
    }
  }

  Future<void> _setupLocalNotifications() async {
    if (kIsWeb) return; // Do not initialize flutter_local_notifications on Web

    try {
      const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
      const InitializationSettings initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null) {
            try {
              final payload = jsonDecode(response.payload!);
              _handleNotificationTap(payload);
            } catch (e) {
              debugPrint('[PushNotificationService] Error parsing local notification payload: $e');
            }
          }
        },
      );
    } on PlatformException catch (e) {
      debugPrint('[PushNotificationService] PlatformException setting up local notifications: ${e.code} - ${e.message}');
    } on Exception catch (e) {
      debugPrint('[PushNotificationService] Exception setting up local notifications: $e');
    } catch (e) {
      debugPrint('[PushNotificationService] Error setting up local notifications: $e');
    }
  }

  Future<void> _setupInteractors() async {
    if (_messaging == null || !_supported) return;

    try {
      // Handle messages when app is in foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[PushNotificationService] Got a message in the foreground: ${message.messageId}');
        if (!kIsWeb) {
          _showLocalNotification(message);
        }
      });

      // Handle messages when app is in background or terminated
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[PushNotificationService] Notification clicked from background/terminated');
        _handleNotificationTap(message.data);
      });

      // Handle initial notification when app is launched from terminated state
      final RemoteMessage? initialMessage = await _messaging!.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage.data);
      }
    } on FirebaseException catch (e) {
      debugPrint('[PushNotificationService] FirebaseException setting up interactors: ${e.code} - ${e.message}');
    } on PlatformException catch (e) {
      debugPrint('[PushNotificationService] PlatformException setting up interactors: ${e.code} - ${e.message}');
    } on Exception catch (e) {
      debugPrint('[PushNotificationService] Exception setting up interactors: $e');
    } catch (e) {
      debugPrint('[PushNotificationService] Error setting up interactors: $e');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    if (kIsWeb) return;

    try {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
          'careconnect_channel',
          'CareConnect Notifications',
          channelDescription: 'Notifications from CareConnect',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        );
        const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);

        await _localNotifications.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: notificationDetails,
          payload: jsonEncode(message.data),
        );
      }
    } catch (e) {
      debugPrint('[PushNotificationService] Error showing local notification: $e');
    }
  }


  void _handleNotificationTap(Map<String, dynamic> data) {
    debugPrint('[PushNotificationService] Handling notification tap: $data');
  }

  Future<void> _getToken() async {
    if (_messaging == null || !_supported) return;

    try {
      _fcmToken = await _messaging!.getToken();
      if (_fcmToken != null) {
        debugPrint('[PushNotificationService] FCM Token: $_fcmToken');
        await _notificationRepo.registerDeviceToken(_fcmToken!);
      }
    } on FirebaseException catch (e) {
      debugPrint('[PushNotificationService] FirebaseException getting FCM token: ${e.code} - ${e.message}');
    } on PlatformException catch (e) {
      debugPrint('[PushNotificationService] PlatformException getting FCM token: ${e.code} - ${e.message}');
    } on Exception catch (e) {
      debugPrint('[PushNotificationService] Exception getting FCM token: $e');
    } catch (e) {
      debugPrint('[PushNotificationService] Error getting FCM token: $e');
    }
  }

  void _setupTokenRefresh() {
    if (_messaging == null || !_supported) return;

    try {
      _messaging!.onTokenRefresh.listen((newToken) {
        debugPrint('[PushNotificationService] FCM Token refreshed: $newToken');
        _fcmToken = newToken;
        _notificationRepo.registerDeviceToken(newToken);
      }, onError: (e) {
        debugPrint('[PushNotificationService] Error in token refresh stream: $e');
      });
    } on FirebaseException catch (e) {
      debugPrint('[PushNotificationService] FirebaseException setting up token refresh: ${e.code} - ${e.message}');
    } on PlatformException catch (e) {
      debugPrint('[PushNotificationService] PlatformException setting up token refresh: ${e.code} - ${e.message}');
    } on Exception catch (e) {
      debugPrint('[PushNotificationService] Exception setting up token refresh: $e');
    } catch (e) {
      debugPrint('[PushNotificationService] Error setting up token refresh: $e');
    }
  }
}
