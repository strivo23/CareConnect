import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/app_state_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/contacts_provider.dart';
import 'providers/emergency_provider.dart';
import 'providers/notifications_provider.dart';
import 'core/services/push_notification_service.dart';
import 'services/fcm_notification_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase if not already initialized
  if (Firebase.apps.isEmpty) {
    try {
      if (kIsWeb) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: "AIzaSyCareConnectDummyWebKey12345",
            appId: "1:1234567890:web:careconnectweb12345",
            messagingSenderId: "1234567890",
            projectId: "careconnect-app",
          ),
        );
      } else {
        await Firebase.initializeApp();
      }
      debugPrint('[Firebase] Firebase.initializeApp() completed.');
    } catch (e) {
      debugPrint('[Firebase] Error during initializeApp: $e');
    }
  }

  // 2. Initialize PushNotificationService & FCMNotificationService
  try {
    await PushNotificationService.instance.init();
  } catch (e) {
    debugPrint('[PushNotificationService] Error in main: $e');
  }

  try {
    await FCMNotificationService.instance.initialize();
  } catch (e) {
    debugPrint('[FCMNotificationService] Error in main: $e');
  }


  // 3. Run application
  runApp(const CareConnectBootstrap());
}

class CareConnectBootstrap extends StatelessWidget {
  const CareConnectBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => AppStateProvider()..init()),
        ChangeNotifierProvider(create: (_) => ContactsProvider()),
        ChangeNotifierProvider(create: (_) => EmergencyProvider()),
        ChangeNotifierProvider(create: (_) => NotificationsProvider()),
      ],
      child: const CareConnectApp(),
    );
  }
}
