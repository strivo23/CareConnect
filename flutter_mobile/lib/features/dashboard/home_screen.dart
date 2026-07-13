import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/offline_banner.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/emergency_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _callEmergency() async {
    final uri = Uri.parse('tel:112');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final appState = context.watch<AppStateProvider>();
    final emergency = context.watch<EmergencyProvider>();
    final resident = appState.residentProfile;

    // Determine location string
    final societyText = resident?.societyName.isNotEmpty == true ? resident!.societyName : 'Your Society';
    final blockText = resident?.blockName.isNotEmpty == true ? resident!.blockName : '';
    final flatText = resident?.flatNumber.isNotEmpty == true ? resident!.flatNumber : '';
    final locationParts = [societyText, if (blockText.isNotEmpty) blockText, if (flatText.isNotEmpty) flatText].join(', ');
    final fullAddress = locationParts;

    // User greeting
    final userName = auth.user?.fullName.isNotEmpty == true
        ? auth.user!.fullName.split(' ').first
        : (auth.user?.email.split('@').first ?? 'Resident');

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          final user = auth.user;
          if (user != null) {
            await context.read<AppStateProvider>().loadResidentByUserId(user.id);
          }
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            if (appState.isOffline) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: OfflineBanner(message: 'Offline mode active. Showing cached resident details.'),
              ),
              const SizedBox(height: 12),
            ],

            // Custom Premium Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // Back arrow (clears state or goes back if possible)
                  InkWell(
                    onTap: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'SOS Emergency',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  // Call 112 outline button
                  InkWell(
                    onTap: _callEmergency,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.phone_rounded, color: Color(0xFFEF4444), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Call 112',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFEF4444),
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Warning Alert Text Banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_rounded, color: Color(0xFFEF4444), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        text: 'Hi $userName! For any life-threatening emergency, ',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF475569),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        children: [
                          TextSpan(
                            text: 'press the SOS button.',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFEF4444),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // Central Pulsing SOS Button
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Glow Ring 1
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.03),
                      shape: BoxShape.circle,
                    ),
                  ),
                  // Outer Glow Ring 2
                  Container(
                    width: 210,
                    height: 210,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                  ),
                  // Inner Glowing Container
                  Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: emergency.isLoading
                            ? null
                            : () async {
                                final success = await context.read<EmergencyProvider>().triggerSOS();
                                if (!context.mounted) return;
                                _showResult(context, success, context.read<EmergencyProvider>().lastMessage ?? 'SOS Dispatched');
                              },
                        customBorder: const CircleBorder(),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (emergency.isLoading)
                              const SizedBox(
                                height: 32,
                                width: 32,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3.5,
                                  color: Colors.white,
                                ),
                              )
                            else ...[
                              const Icon(
                                Icons.phone_in_talk_rounded,
                                color: Colors.white,
                                size: 36,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'SOS',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'TAP TO ALERT',
                                style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // Dispatch Information Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2), // Soft pink matching mockup
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFE4E6), width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'What happens after you press SOS?',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your alert will be sent to security, admin and emergency contacts immediately.',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B), size: 22),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Your Location Card Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 20),
                      const SizedBox(width: 6),
                      Text(
                        'Your Location',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const Spacer(),
                      // Refresh button
                      InkWell(
                        onTap: () => context.read<AppStateProvider>().loadResidentByUserId(auth.user?.id ?? 0),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.refresh_rounded, color: Color(0xFF64748B), size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'Refresh',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8F8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFEE2E2), width: 1.5),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Red pin inside soft-red container
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullAddress,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E293B),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Lat 40.7128° N, Long 74.0060° W',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quick Actions Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Quick Actions',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'View All >',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF2563EB),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Horizontal list of quick actions
                  SizedBox(
                    height: 96,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: emergency.quickActions.length,
                      itemBuilder: (context, index) {
                        final action = emergency.quickActions[index];
                        final details = _resolveActionStyle(action.slug);
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: InkWell(
                            onTap: () async {
                              final success = await context.read<EmergencyProvider>().triggerAction(action);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? '${action.label} alert dispatched successfully'
                                        : 'Failed to dispatch ${action.label} alert',
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 82,
                              decoration: BoxDecoration(
                                color: details.backgroundColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: details.backgroundColor.withValues(alpha: 0.15), width: 1.5),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(details.icon, color: details.accentColor, size: 28),
                                  const SizedBox(height: 8),
                                  Text(
                                    action.label,
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: details.accentColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResult(BuildContext context, bool success, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.error_rounded,
              color: success ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
            ),
            const SizedBox(width: 8),
            Text(success ? 'SOS Dispatched' : 'SOS Failed', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primary)),
          )
        ],
      ),
    );
  }

  _ActionStyle _resolveActionStyle(String slug) {
    switch (slug) {
      case 'ambulance':
        return _ActionStyle(
          icon: Icons.local_hospital_rounded,
          accentColor: const Color(0xFFEF4444),
          backgroundColor: const Color(0xFFFFF1F2),
        );
      case 'fire':
        return _ActionStyle(
          icon: Icons.local_fire_department_rounded,
          accentColor: const Color(0xFFF97316),
          backgroundColor: const Color(0xFFFFF7ED),
        );
      case 'police':
        return _ActionStyle(
          icon: Icons.local_police_rounded,
          accentColor: const Color(0xFF3B82F6),
          backgroundColor: const Color(0xFFEFF6FF),
        );
      case 'electrical':
        return _ActionStyle(
          icon: Icons.flash_on_rounded,
          accentColor: const Color(0xFFEAB308),
          backgroundColor: const Color(0xFFFEFCE8),
        );
      case 'security':
        return _ActionStyle(
          icon: Icons.shield_rounded,
          accentColor: const Color(0xFF10B981),
          backgroundColor: const Color(0xFFECFDF5),
        );
      case 'hospital':
        return _ActionStyle(
          icon: Icons.medical_services_rounded,
          accentColor: const Color(0xFF8B5CF6),
          backgroundColor: const Color(0xFFF5F3FF),
        );
      default:
        return _ActionStyle(
          icon: Icons.warning_rounded,
          accentColor: const Color(0xFF64748B),
          backgroundColor: const Color(0xFFF8FAFC),
        );
    }
  }
}

class _ActionStyle {
  _ActionStyle({required this.icon, required this.accentColor, required this.backgroundColor});
  final IconData icon;
  final Color accentColor;
  final Color backgroundColor;
}
