import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state_provider.dart';
import '../../providers/contacts_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notifications_provider.dart';
import '../contacts/contacts_screen.dart';
import '../dashboard/alerts_screen.dart';
import '../dashboard/home_screen.dart';
import '../notifications/notifications_screen.dart';
import '../settings/settings_screen.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      final appState = context.read<AppStateProvider>();
      final contactsProvider = context.read<ContactsProvider>();
      final notificationsProvider = context.read<NotificationsProvider>();
      final user = auth.user;
      if (user != null) {
        await appState.loadResidentByUserId(user.id);
        final resident = appState.residentProfile;
        if (resident != null) {
          await contactsProvider.loadForResident(resident.id);
        }
      }
      await notificationsProvider.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<NotificationsProvider>().unreadCount;

    final pages = [
      const HomeScreen(),
      const AlertsScreen(),
      const ContactsScreen(),
      const NotificationsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          const NavigationDestination(icon: Icon(Icons.warning_rounded), label: 'Alerts'),
          const NavigationDestination(icon: Icon(Icons.people_alt_rounded), label: 'Contacts'),
          NavigationDestination(
            icon: Badge(label: Text('$unreadCount'), isLabelVisible: unreadCount > 0, child: const Icon(Icons.notifications_rounded)),
            label: 'Notifications',
          ),
          const NavigationDestination(icon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}
