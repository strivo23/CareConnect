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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase if not already initialized
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp();
      debugPrint('[Firebase] Firebase.initializeApp() completed.');
    } on FirebaseException catch (e) {
      debugPrint('[Firebase] FirebaseException during initializeApp: ${e.code} - ${e.message}');
    } on PlatformException catch (e) {
      debugPrint('[Firebase] PlatformException during initializeApp: ${e.code} - ${e.message}');
    } on Exception catch (e) {
      debugPrint('[Firebase] Exception during initializeApp: $e');
    } catch (e) {
      debugPrint('[Firebase] Unexpected error during initializeApp: $e');
    }
  }

  // 2. Initialize PushNotificationService
  try {
    await PushNotificationService.instance.init();
  } on FirebaseException catch (e) {
    debugPrint('[PushNotificationService] FirebaseException in main: ${e.code} - ${e.message}');
  } on PlatformException catch (e) {
    debugPrint('[PushNotificationService] PlatformException in main: ${e.code} - ${e.message}');
  } on Exception catch (e) {
    debugPrint('[PushNotificationService] Exception in main: $e');
  } catch (e, stackTrace) {
    debugPrint('[PushNotificationService] Unexpected error in main: $e\n$stackTrace');
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
