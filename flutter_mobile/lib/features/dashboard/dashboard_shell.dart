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
import 'volunteer_dashboard.dart';
import 'security_dashboard.dart';


import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

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
      await notificationsProvider.loadCachedGuardianNotifications();
      notificationsProvider.startGuardianPolling();

      // Setup mock notification permissions and token registration
      debugPrint('[NOTIFICATION SETUP] Requesting push notification permissions... Granted.');
      final mockToken = 'fcm_token_mock_${user?.id ?? "anonymous"}';
      debugPrint('[NOTIFICATION SETUP] Registered FCM token: $mockToken');
      await notificationsProvider.registerDeviceToken(mockToken);


      // Callback when new high priority emergency notification is received
      notificationsProvider.onNewEmergencyNotification = (notification) {
        // 1. Show Red Dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            backgroundColor: Colors.red.shade900,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                const Icon(Icons.emergency_rounded, color: Colors.white, size: 30),
                const SizedBox(width: 12),
                Text(
                  'EMERGENCY ALERT',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            content: Text(
              '${notification.message}\n\nResident: ${notification.residentName}\nCategory: ${notification.emergencyCategory}',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 15, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  context.read<NotificationsProvider>().markAsRead(notification.id);
                },
                child: Text(
                  'Dismiss',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
              ),
              if (notification.incidentId > 0)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    context.read<NotificationsProvider>().markAsRead(notification.id);
                    context.push('/sos-detail', extra: notification);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red.shade900,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'View Details',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        );

        // 2. Play notification sound
        SystemSound.play(SystemSoundType.alert);

        // 3. Display snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(notification.message),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'VIEW',
              textColor: Colors.white,
              onPressed: () {
                context.read<NotificationsProvider>().markAsRead(notification.id);
                if (notification.incidentId > 0) {
                  context.push('/sos-detail', extra: notification);
                }
              },
            ),
          ),
        );
      };
    });
  }

  @override
  void dispose() {
    context.read<NotificationsProvider>().stopGuardianPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<NotificationsProvider>().unreadCount;
    final role = context.watch<AuthProvider>().user?.role ?? 'RESIDENT';

    final pages = [
      role == 'VOLUNTEER'
          ? const VolunteerDashboardScreen()
          : role == 'SECURITY'
              ? const SecurityDashboardScreen()
              : const HomeScreen(),
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
