import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/api_client.dart';
import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notifications_provider.dart';

class SOSDetailScreen extends StatefulWidget {
  const SOSDetailScreen({super.key, required this.notification});

  final AppNotificationModel notification;

  @override
  State<SOSDetailScreen> createState() => _SOSDetailScreenState();
}

class _SOSDetailScreenState extends State<SOSDetailScreen> {
  bool _isLoading = false;
  String? _currentStatus;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.notification.incidentStatus;
    if (_currentStatus == null || _currentStatus!.isEmpty) {
      _currentStatus = 'Pending';
    }
  }

  Future<void> _updateStatus(String actionPath, String targetStatus) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient.instance.patch(
        '/api/sos/$actionPath/${widget.notification.incidentId}/',
        data: {},
      );

      if (response.statusCode == 200) {
        setState(() {
          _currentStatus = targetStatus;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('SOS status updated to $targetStatus successfully.'),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        // Refresh notifications to sync badge/counts
        context.read<NotificationsProvider>().pollGuardianNotifications();
      } else {
        setState(() {
          _errorMessage = response.data['detail']?.toString() ?? 'Failed to update status.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().contains('400')
            ? 'Invalid status transition.'
            : 'Error connecting to the server.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Accepted':
        return Colors.blue;
      case 'In Progress':
        return Colors.purple;
      case 'Resolved':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final role = user?.role ?? 'RESIDENT';
    final isGuardianOrStaff = role == 'ADMIN' || role == 'SECURITY' || role == 'SOCIETY_MANAGER' || role == 'STAFF';
    final isOwner = user != null && widget.notification.message.contains(user.fullName.split(' ').first);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'SOS Alert Details',
          style: GoogleFonts.outfit(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Status Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
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
                        'Incident Status',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentStatus!,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _getStatusColor(_currentStatus!),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _getStatusColor(_currentStatus!).withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Incident Details Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SOS Information',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const Divider(height: 30, color: Color(0xFFF1F5F9)),

                  _buildDetailRow(
                    label: 'Resident Name',
                    value: widget.notification.residentName.isNotEmpty
                        ? widget.notification.residentName
                        : 'Unknown Resident',
                    icon: Icons.person_rounded,
                  ),
                  _buildDetailRow(
                    label: 'Emergency Category',
                    value: widget.notification.emergencyCategory.isNotEmpty
                        ? widget.notification.emergencyCategory
                        : 'SOS Emergency',
                    icon: Icons.emergency_rounded,
                    iconColor: AppTheme.danger,
                  ),
                  _buildDetailRow(
                    label: 'Triggered Time',
                    value: DateFormat('dd MMM yyyy, hh:mm a').format(widget.notification.createdAt),
                    icon: Icons.access_time_filled_rounded,
                  ),
                  _buildDetailRow(
                    label: 'Location Coordinates',
                    value: widget.notification.location.isNotEmpty
                        ? widget.notification.location
                        : 'Lat 40.7128° N, Long 74.0060° W',
                    icon: Icons.my_location_rounded,
                  ),
                  _buildDetailRow(
                    label: 'Description Message',
                    value: widget.notification.incidentMessage.isNotEmpty
                        ? widget.notification.incidentMessage
                        : 'Immediate help requested.',
                    icon: Icons.chat_bubble_rounded,
                    isLast: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Text(
                  _errorMessage!,
                  style: GoogleFonts.inter(
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Action Buttons
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: AppTheme.danger),
              )
            else ...[
              // Guardian/Staff Actions: Accept, In Progress, Resolve
              if (isGuardianOrStaff) ...[
                if (_currentStatus == 'Pending')
                  ElevatedButton.icon(
                    onPressed: () => _updateStatus('accept', 'Accepted'),
                    icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                    label: Text(
                      'Accept SOS Alert',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                if (_currentStatus == 'Accepted')
                  ElevatedButton.icon(
                    onPressed: () => _updateStatus('in-progress', 'In Progress'),
                    icon: const Icon(Icons.pending_actions_rounded, color: Colors.white),
                    label: Text(
                      'Mark In Progress',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                if (_currentStatus == 'In Progress')
                  ElevatedButton.icon(
                    onPressed: () => _updateStatus('resolve', 'Resolved'),
                    icon: const Icon(Icons.done_all_rounded, color: Colors.white),
                    label: Text(
                      'Resolve SOS Alert',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                const SizedBox(height: 12),
              ],

              // Cancellation Action (Allowed for owner or guardians if not terminal)
              if ((isGuardianOrStaff || isOwner) && _currentStatus != 'Resolved' && _currentStatus != 'Cancelled')
                OutlinedButton.icon(
                  onPressed: () => _updateStatus('cancel', 'Cancelled'),
                  icon: const Icon(Icons.cancel_outlined, color: AppTheme.danger),
                  label: Text(
                    'Cancel SOS Alert',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    side: const BorderSide(color: AppTheme.danger, width: 1.5),
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    required IconData icon,
    Color? iconColor,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFF1F5F9),
              radius: 18,
              child: Icon(icon, color: iconColor ?? const Color(0xFF64748B), size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF334155),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!isLast) const Divider(height: 24, color: Color(0xFFF1F5F9)),
      ],
    );
  }
}
