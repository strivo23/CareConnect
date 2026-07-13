import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/notifications_provider.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> with SingleTickerProviderStateMixin {
  bool _isLocationRefreshing = false;
  late AnimationController _sosPulseController;

  @override
  void initState() {
    super.initState();
    _sosPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _sosPulseController.dispose();
    super.dispose();
  }

  // Refresh location logic (simulated)
  Future<void> _refreshLocation() async {
    setState(() {
      _isLocationRefreshing = true;
    });
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _isLocationRefreshing = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location details updated successfully.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  // SOS button trigger confirmation dialog
  void _confirmSOS() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 28),
            const SizedBox(width: 10),
            Text(
              'Confirm SOS Alert',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to send an emergency alert? This will immediately notify the Society Admin, Security Gate, and your primary Emergency Contacts.',
          style: GoogleFonts.inter(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _dispatchSOS();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(
              'Send SOS',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _dispatchSOS() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SOS Dispatch Sent! Help is on the way.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.danger,
        duration: Duration(seconds: 4),
      ),
    );
  }

  // Quick action confirmation dialog
  void _confirmQuickAction(String serviceName, IconData icon, Color color) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 10),
            Text(
              'Call $serviceName?',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Do you want to dispatch a request to $serviceName emergency services? (Simulation)',
          style: GoogleFonts.inter(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Simulated request sent to $serviceName!'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: color,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Call'),
          ),
        ],
      ),
    );
  }

  // Helper to copy text to clipboard
  void _copyToClipboard(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.grey.shade900,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<NotificationsProvider>().unreadCount;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alerts',
              style: GoogleFonts.outfit(
                color: Colors.black87,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Emergency Dispatch Center',
              style: GoogleFonts.inter(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        titleSpacing: 20,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.black87, size: 26),
                  onPressed: () {
                    // Navigate to notifications tab if dashboard shell index allows or show message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('You have $unreadCount unread notifications in the inbox.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.danger,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 800));
          setState(() {});
        },
        color: AppTheme.danger,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SECTION 1: EMERGENCY SOS
              _buildSOSSection(),
              const SizedBox(height: 20),

              // SECTION 2: CURRENT LOCATION
              _buildLocationSection(),
              const SizedBox(height: 20),

              // SECTION 3: QUICK EMERGENCY ACTIONS
              Text(
                'Quick Emergency Actions',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              _buildQuickActionsGrid(),
              const SizedBox(height: 24),

              // SECTION 4: RECENT ALERTS
              _buildRecentAlertsSection(),
              const SizedBox(height: 24),

              // SECTION 5: SOCIETY EMERGENCY NUMBERS
              Text(
                'Society Emergency Numbers',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              _buildSocietyNumbersSection(),
              const SizedBox(height: 24),

              // SECTION 6: SAFETY TIPS
              _buildSafetyTipsSection(),
              const SizedBox(height: 24),

              // SECTION 7: SOS HISTORY
              _buildSOSHistorySection(),
              const SizedBox(height: 24),

              // BOTTOM WARNING
              _buildBottomWarningSection(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // SOS Section Widget
  Widget _buildSOSSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.danger.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.red.shade50),
      ),
      child: Column(
        children: [
          Text(
            'Emergency SOS',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),

          // Large glowing red circular button
          Center(
            child: SizedBox(
              width: 170,
              height: 170,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer pulsing rings
                  AnimatedBuilder(
                    animation: _sosPulseController,
                    builder: (context, child) {
                      return Container(
                        width: 140 + (24 * _sosPulseController.value),
                        height: 140 + (24 * _sosPulseController.value),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withValues(alpha: 0.15 * (1.0 - _sosPulseController.value)),
                          shape: BoxShape.circle,
                        ),
                      );
                    },
                  ),
                  // Core Button
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF3B30), Color(0xFFC20000)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.danger.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _confirmSOS,
                        customBorder: const CircleBorder(),
                        child: Center(
                          child: Text(
                            'SOS',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // SOS Explanation text
          Text(
            'In a life-threatening emergency, tap SOS.\nYour alert, live location and user information will be instantly shared with:',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.grey.shade700,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          // Receivers list
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTargetBadge('Society Admin'),
              const SizedBox(width: 8),
              _buildTargetBadge('Security Gate'),
              const SizedBox(width: 8),
              _buildTargetBadge('Guardians'),
            ],
          ),
          const SizedBox(height: 16),

          // Small Warning Footer
          Text(
            'Use only for genuine emergencies.',
            style: GoogleFonts.inter(
              color: AppTheme.danger,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          color: AppTheme.danger,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Location Section Widget
  Widget _buildLocationSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue.shade50,
                radius: 22,
                child: const Icon(Icons.my_location_rounded, color: Color(0xFF2563EB), size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Green Heights Society',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'Block A, Flat A-203',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Live Location Enabled',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            onPressed: _isLocationRefreshing ? null : _refreshLocation,
            icon: _isLocationRefreshing
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                  )
                : const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB)),
            style: IconButton.styleFrom(
              backgroundColor: Colors.blue.shade50,
              padding: const EdgeInsets.all(10),
            ),
          )
        ],
      ),
    );
  }

  // Quick Emergency Actions Grid Builder
  Widget _buildQuickActionsGrid() {
    final List<Map<String, dynamic>> items = [
      {
        'emoji': '🚑',
        'icon': Icons.local_hospital_rounded,
        'title': 'Ambulance',
        'sub': 'Medical crisis',
        'color': Colors.red,
      },
      {
        'emoji': '🚒',
        'icon': Icons.fire_truck_rounded,
        'title': 'Fire Brigade',
        'sub': 'Fire hazards',
        'color': Colors.orange,
      },
      {
        'emoji': '👮',
        'icon': Icons.local_police_rounded,
        'title': 'Police',
        'sub': 'Security threats',
        'color': Colors.blue,
      },
      {
        'emoji': '⚡',
        'icon': Icons.flash_on_rounded,
        'title': 'Electrical',
        'sub': 'Short circuit / spark',
        'color': Colors.amber.shade700,
      },
      {
        'emoji': '🛡',
        'icon': Icons.security_rounded,
        'title': 'Security',
        'sub': 'Society patrol',
        'color': Colors.indigo,
      },
      {
        'emoji': '🏥',
        'icon': Icons.apartment_rounded,
        'title': 'Hospital',
        'sub': 'Emergency ward',
        'color': Colors.teal,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.55,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final act = items[index];
        final actionColor = act['color'] as Color;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _confirmQuickAction(act['title'] as String, act['icon'] as IconData, actionColor),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          act['emoji'] as String,
                          style: const TextStyle(fontSize: 22),
                        ),
                        CircleAvatar(
                          backgroundColor: actionColor.withValues(alpha: 0.1),
                          radius: 14,
                          child: Icon(act['icon'] as IconData, color: actionColor, size: 14),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          act['title'] as String,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          act['sub'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Recent Alerts Announcements Builder
  Widget _buildRecentAlertsSection() {
    final List<Map<String, dynamic>> alerts = [
      {
        'title': 'Water Supply Restored',
        'status': '🟢 Resolved',
        'time': 'Today, 8:30 AM',
        'icon': Icons.water_drop_rounded,
        'color': Colors.green,
      },
      {
        'title': 'Lift Maintenance',
        'status': '🟡 Upcoming',
        'time': 'Tomorrow, 10:00 AM',
        'icon': Icons.elevator_rounded,
        'color': Colors.amber.shade700,
      },
      {
        'title': 'Fire Drill Training',
        'status': '🔴 Schedule',
        'time': '15 July, 5:00 PM',
        'icon': Icons.local_fire_department_rounded,
        'color': Colors.red,
      },
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Alerts',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Icon(Icons.announcement_outlined, color: Colors.grey, size: 18),
            ],
          ),
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: alerts.length,
            separatorBuilder: (context, index) => const Divider(height: 24, color: Color(0xFFF1F5F9)),
            itemBuilder: (context, index) {
              final alt = alerts[index];
              final alertColor = alt['color'] as Color;
              return Row(
                children: [
                  CircleAvatar(
                    backgroundColor: alertColor.withValues(alpha: 0.1),
                    radius: 20,
                    child: Icon(alt['icon'] as IconData, color: alertColor, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alt['title'] as String,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          alt['time'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: alertColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      alt['status'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: alertColor,
                      ),
                    ),
                  )
                ],
              );
            },
          )
        ],
      ),
    );
  }

  // Society Emergency Contacts
  Widget _buildSocietyNumbersSection() {
    final List<Map<String, String>> contacts = [
      {'name': 'Security Gate', 'number': '+91 9876543210'},
      {'name': 'Maintenance Office', 'number': '+91 9876543211'},
      {'name': 'Society Head Office', 'number': '+91 9876543212'},
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final item = contacts[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name']!,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['number']!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Colors.blueAccent, size: 18),
                    onPressed: () => _copyToClipboard(item['name']!, item['number']!),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.blue.shade50.withValues(alpha: 0.5),
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(34, 34),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.call_rounded, color: Colors.green, size: 18),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Calling ${item['name']} (${item['number']})... (Simulated)'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.green.shade50,
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(34, 34),
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  // Safety Tips Info Card
  Widget _buildSafetyTipsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 22),
              const SizedBox(width: 10),
              Text(
                'Safety Tips',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildTipRow('Stay calm during emergencies.'),
          const SizedBox(height: 8),
          _buildTipRow('Share accurate location with guard personnel.'),
          const SizedBox(height: 8),
          _buildTipRow('Follow instructions from security personnel.'),
          const SizedBox(height: 8),
          _buildTipRow('Keep emergency contacts and phone numbers updated.'),
        ],
      ),
    );
  }

  Widget _buildTipRow(String tipText) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 3.0),
          child: Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            tipText,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
        )
      ],
    );
  }

  // SOS History Request Widget
  Widget _buildSOSHistorySection() {
    final List<Map<String, String>> history = [
      {'date': '12 Jul 2026, 4:12 PM', 'status': 'Resolved'},
      {'date': '05 Jul 2026, 9:30 AM', 'status': 'Cancelled'},
      {'date': '28 Jun 2026, 11:15 AM', 'status': 'Resolved'},
      {'date': '20 Jun 2026, 2:40 PM', 'status': 'Pending'},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Previous SOS Requests',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: history.length,
            separatorBuilder: (context, index) => const Divider(height: 20, color: Color(0xFFF1F5F9)),
            itemBuilder: (context, index) {
              final item = history[index];
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SOS Dispatch Alert',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['date']!,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  _buildHistoryStatusChip(item['status']!),
                ],
              );
            },
          )
        ],
      ),
    );
  }

  Widget _buildHistoryStatusChip(String status) {
    Color chipColor;
    Color textColor;
    switch (status) {
      case 'Resolved':
        chipColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        break;
      case 'Pending':
        chipColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
        break;
      default:
        chipColor = Colors.grey.shade100;
        textColor = Colors.grey.shade600;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  // Warning Section Builder
  Widget _buildBottomWarningSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFEF3C7), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_rounded, color: Color(0xFFD97706), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'False emergency alerts may result in action by society administration.',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF92400E),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
