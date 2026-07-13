import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/app_state_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/contacts_provider.dart';
import 'providers/emergency_provider.dart';
import 'providers/notifications_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
