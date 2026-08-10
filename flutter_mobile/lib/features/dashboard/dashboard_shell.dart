import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state_provider.dart';
import '../../providers/contacts_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../contacts/contacts_screen.dart';
import '../dashboard/alerts_screen.dart';
import '../dashboard/home_screen.dart';
import '../notifications/notifications_screen.dart';
import '../settings/settings_screen.dart';
import 'volunteer_dashboard.dart';
import 'security_dashboard.dart';
import 'guardian_dashboard.dart';
import 'society_manager_dashboard.dart';
import 'admin_dashboard.dart';
import '../directory/contact_directory_screen.dart';


import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/api_client.dart';
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
        if (notification.isSender == true || notification.canAccept == false) {
          debugPrint('[DASHBOARD SHELL] Suppressing responder popup because user is sender or cannot accept.');
          return;
        }
        _showGuardianEmergencyDialog(context, notification);
        SystemSound.play(SystemSoundType.alert);
      };
    });
  }

  void _showGuardianEmergencyDialog(BuildContext context, dynamic notification) {
    if (notification.isSender == true) return;
    final incidentId = notification.incidentId;
    final residentName = notification.residentName.isNotEmpty ? notification.residentName : 'Resident';
    final category = notification.emergencyCategory.isNotEmpty ? notification.emergencyCategory : 'SOS Emergency';
    final priority = notification.priority.isNotEmpty ? notification.priority : 'HIGH';
    final address = notification.address.isNotEmpty ? notification.address : (notification.location.isNotEmpty ? notification.location : 'Address unavailable');
    final message = notification.message.isNotEmpty ? notification.message : 'Immediate assistance requested!';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.red.shade900, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EMERGENCY SOS ALERT',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'Priority: $priority',
                        style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 24),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Resident info tile
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.redAccent,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(residentName, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(category, style: GoogleFonts.inter(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      address,
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  message,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Column(
            children: [
              Row(
                children: [
                  // ACCEPT BUTTON
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(dialogCtx);
                        context.read<NotificationsProvider>().markAsRead(notification.id);
                        if (incidentId > 0) {
                          try {
                            await ApiClient.instance.post('/api/sos/incidents/$incidentId/accept/');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('SOS Alert Accepted! Incident assigned to you as Guardian.'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              context.push('/sos-detail', extra: {'id': incidentId});
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Acceptance error: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        }
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text('ACCEPT'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // REJECT BUTTON
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(dialogCtx);
                        _showRejectionReasonDialog(context, incidentId, notification.id);
                      },
                      icon: const Icon(Icons.cancel_rounded, size: 18),
                      label: const Text('REJECT'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // EMERGENCY CHAT BUTTON
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(dialogCtx);
                        context.read<NotificationsProvider>().markAsRead(notification.id);
                        if (incidentId > 0) {
                          context.push('/emergency-chat', extra: {'id': incidentId});
                        }
                      },
                      icon: const Icon(Icons.chat_bubble_rounded, size: 16, color: Colors.lightBlueAccent),
                      label: Text('Chat', style: GoogleFonts.inter(color: Colors.white)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.lightBlueAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // VIEW DETAILS BUTTON
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(dialogCtx);
                        context.read<NotificationsProvider>().markAsRead(notification.id);
                        if (incidentId > 0) {
                          context.push('/sos-detail', extra: {'id': incidentId});
                        }
                      },
                      icon: const Icon(Icons.visibility_rounded, size: 16, color: Colors.white70),
                      label: Text('Details', style: GoogleFonts.inter(color: Colors.white)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white38),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRejectionReasonDialog(BuildContext context, int incidentId, String notificationId) {
    final reasonController = TextEditingController();
    String selectedReason = 'Unable to respond immediately';

    showDialog(
      context: context,
      builder: (rejCtx) => StatefulBuilder(
        builder: (context, setRejState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Reason for Rejection', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Rejecting will automatically escalate this SOS alert to the next emergency tier (Secondary Guardians / Security / Volunteers).',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: [
                  'Unable to respond immediately',
                  'Away from location',
                  'Occupied with emergency',
                  'Other'
                ].map((r) => ChoiceChip(
                  label: Text(r, style: GoogleFonts.inter(fontSize: 12)),
                  selected: selectedReason == r,
                  onSelected: (val) {
                    if (val) setRejState(() => selectedReason = r);
                  },
                )).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Additional Notes (Optional)',
                  hintText: 'Enter reason details...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(rejCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(rejCtx);
                context.read<NotificationsProvider>().markAsRead(notificationId);
                final finalReason = reasonController.text.trim().isNotEmpty
                    ? '${selectedReason}: ${reasonController.text.trim()}'
                    : selectedReason;

                try {
                  await ApiClient.instance.post(
                    '/api/sos/incidents/$incidentId/reject/',
                    data: {'reason': finalReason},
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('SOS Alert rejected. Escalated to next tier immediately.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Rejection error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Submit Rejection'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    context.read<NotificationsProvider>().stopGuardianPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<NotificationsProvider>().unreadCount;
    final user = context.watch<AuthProvider>().user;
    final role = user?.role ?? 'RESIDENT';

    final loc = AppLocalizations.of(context);

    List<Widget> pages = [];
    List<NavigationDestination> destinations = [];

    if (role == 'GUARDIAN') {
      pages = [
        const GuardianDashboardScreen(),
        const AlertsScreen(),
        const ContactDirectoryScreen(),
        const NotificationsScreen(),
        const SettingsScreen(),
      ];
      destinations = [
        NavigationDestination(icon: const Icon(Icons.shield_rounded), label: loc.translate('guardianDashboard')),
        NavigationDestination(icon: const Icon(Icons.warning_rounded), label: loc.translate('alerts')),
        NavigationDestination(icon: const Icon(Icons.contact_phone_rounded), label: loc.translate('emergencyContact')),
        NavigationDestination(
          icon: Badge(label: Text('$unreadCount'), isLabelVisible: unreadCount > 0, child: const Icon(Icons.notifications_rounded)),
          label: loc.translate('alerts'),
        ),
        NavigationDestination(icon: const Icon(Icons.settings_rounded), label: loc.translate('settings')),
      ];
    } else if (role == 'VOLUNTEER') {
      pages = [
        const VolunteerDashboardScreen(),
        const AlertsScreen(),
        const ContactDirectoryScreen(),
        const NotificationsScreen(),
        const SettingsScreen(),
      ];
      destinations = [
        NavigationDestination(icon: const Icon(Icons.volunteer_activism_rounded), label: loc.translate('volunteerDashboard')),
        NavigationDestination(icon: const Icon(Icons.assignment_rounded), label: loc.translate('alerts')),
        NavigationDestination(icon: const Icon(Icons.contact_phone_rounded), label: loc.translate('emergencyContact')),
        NavigationDestination(
          icon: Badge(label: Text('$unreadCount'), isLabelVisible: unreadCount > 0, child: const Icon(Icons.notifications_rounded)),
          label: loc.translate('alerts'),
        ),
        NavigationDestination(icon: const Icon(Icons.settings_rounded), label: loc.translate('settings')),
      ];
    } else if (role == 'SECURITY') {
      pages = [
        const SecurityDashboardScreen(),
        const AlertsScreen(),
        const ContactDirectoryScreen(),
        const NotificationsScreen(),
        const SettingsScreen(),
      ];
      destinations = [
        NavigationDestination(icon: const Icon(Icons.security_rounded), label: loc.translate('securityDashboard')),
        NavigationDestination(icon: const Icon(Icons.warning_amber_rounded), label: loc.translate('alerts')),
        NavigationDestination(icon: const Icon(Icons.contact_phone_rounded), label: loc.translate('emergencyContact')),
        NavigationDestination(
          icon: Badge(label: Text('$unreadCount'), isLabelVisible: unreadCount > 0, child: const Icon(Icons.notifications_rounded)),
          label: loc.translate('alerts'),
        ),
        NavigationDestination(icon: const Icon(Icons.settings_rounded), label: loc.translate('settings')),
      ];
    } else if (role == 'SOCIETY_MANAGER' || role == 'MANAGER') {
      pages = [
        const SocietyManagerDashboardScreen(),
        const ContactDirectoryScreen(),
        const NotificationsScreen(),
        const SettingsScreen(),
      ];
      destinations = [
        NavigationDestination(icon: const Icon(Icons.apartment_rounded), label: loc.translate('societyManager')),
        NavigationDestination(icon: const Icon(Icons.contact_phone_rounded), label: loc.translate('emergencyContact')),
        NavigationDestination(
          icon: Badge(label: Text('$unreadCount'), isLabelVisible: unreadCount > 0, child: const Icon(Icons.notifications_rounded)),
          label: loc.translate('alerts'),
        ),
        NavigationDestination(icon: const Icon(Icons.settings_rounded), label: loc.translate('settings')),
      ];
    } else if (role == 'ADMIN') {
      pages = [
        const AdminDashboardScreen(),
        const ContactDirectoryScreen(),
        const NotificationsScreen(),
        const SettingsScreen(),
      ];
      destinations = [
        NavigationDestination(icon: const Icon(Icons.admin_panel_settings_rounded), label: loc.translate('adminDashboard')),
        NavigationDestination(icon: const Icon(Icons.contact_phone_rounded), label: loc.translate('emergencyContact')),
        NavigationDestination(
          icon: Badge(label: Text('$unreadCount'), isLabelVisible: unreadCount > 0, child: const Icon(Icons.notifications_rounded)),
          label: loc.translate('alerts'),
        ),
        NavigationDestination(icon: const Icon(Icons.settings_rounded), label: loc.translate('settings')),
      ];
    } else {
      // RESIDENT (Default)
      pages = [
        const HomeScreen(),
        const AlertsScreen(),
        const ContactsScreen(),
        const NotificationsScreen(),
        const SettingsScreen(),
      ];
      destinations = [
        NavigationDestination(icon: const Icon(Icons.home_rounded), label: loc.translate('home')),
        NavigationDestination(icon: const Icon(Icons.warning_rounded), label: loc.translate('alerts')),
        NavigationDestination(icon: const Icon(Icons.people_alt_rounded), label: loc.translate('emergencyContact')),
        NavigationDestination(
          icon: Badge(label: Text('$unreadCount'), isLabelVisible: unreadCount > 0, child: const Icon(Icons.notifications_rounded)),
          label: loc.translate('alerts'),
        ),
        NavigationDestination(icon: const Icon(Icons.settings_rounded), label: loc.translate('settings')),
      ];
    }

    final safeIndex = _index < pages.length ? _index : 0;

    return Scaffold(
      body: IndexedStack(index: safeIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: destinations,
      ),
    );
  }
}
