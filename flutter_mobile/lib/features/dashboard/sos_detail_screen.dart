import 'dart:async' as java_timer;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/api_client.dart';
import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notifications_provider.dart';

import 'widgets/emergency_location_widget.dart';

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

  String? _residentName;
  String? _categoryName;
  String? _message;
  double? _latitude;
  double? _longitude;
  String? _address;
  DateTime? _createdAt;

  String? _priority;
  String? _residentPhone;
  int _escalationSecondsRemaining = 300;
  bool _isEscalated = false;
  java_timer.Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.notification.incidentStatus;
    if (_currentStatus == null || _currentStatus!.isEmpty) {
      _currentStatus = 'Pending';
    }
    _residentName = widget.notification.residentName;
    _categoryName = widget.notification.emergencyCategory;
    _message = widget.notification.incidentMessage;
    _latitude = widget.notification.latitude;
    _longitude = widget.notification.longitude;
    _address = widget.notification.address;
    _createdAt = widget.notification.createdAt;

    _startEscalationTimer();
    _fetchFullIncidentDetails();
  }

  void _startEscalationTimer() {
    if (_currentStatus != 'Pending') return;
    _timer?.cancel();
    _timer = java_timer.Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_escalationSecondsRemaining > 0) {
        setState(() {
          _escalationSecondsRemaining--;
        });
      } else {
        setState(() {
          _isEscalated = true;
        });
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchFullIncidentDetails() async {
    final incidentId = widget.notification.incidentId;
    if (incidentId <= 0) return;

    try {
      final response = await ApiClient.instance.get('/api/sos/incidents/$incidentId/');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        setState(() {
          _residentName = data['resident_name']?.toString() ?? _residentName;
          _categoryName = data['category_name']?.toString() ?? _categoryName;
          _message = data['message']?.toString() ?? _message;
          _currentStatus = data['status']?.toString() ?? _currentStatus;
          _priority = data['priority']?.toString() ?? 'HIGH';
          _address = data['resolved_address']?.toString() ?? data['address']?.toString() ?? _address;
          if (data['latitude'] != null) {
            _latitude = double.tryParse(data['latitude'].toString());
          }
          if (data['longitude'] != null) {
            _longitude = double.tryParse(data['longitude'].toString());
          }
          if (data['created_at'] != null) {
            _createdAt = DateTime.tryParse(data['created_at'].toString()) ?? _createdAt;
          }
        });
      }

      // Fetch escalation details if available
      try {
        final escRes = await ApiClient.instance.get('/api/sos/incidents/$incidentId/escalation/');
        if (escRes.statusCode == 200 && escRes.data != null) {
          final escData = escRes.data as Map<String, dynamic>;
          final history = escData['escalation_history'] as List?;
          if (history != null && history.any((item) => item['status'] == 'TRIGGERED' && item['step'] != 'Primary Guardian')) {
            setState(() {
              _isEscalated = true;
            });
          }
        }
      } catch (_) {}

    } catch (e) {
      debugPrint('[SOSDetailScreen] Failed to fetch incident details: $e');
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

  Future<void> _handleAcceptWithETA() async {
    final String? eta = await showDialog<String>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(
            'Confirm Acceptance & ETA',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please select your estimated time of arrival (ETA) to assist:',
                style: GoogleFonts.inter(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['5 mins', '10 mins', '15 mins', '30 mins'].map((timeStr) {
                  return ElevatedButton(
                    onPressed: () => Navigator.pop(dialogCtx, timeStr),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(timeStr),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, null),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
            ),
          ],
        );
      },
    );

    if (eta == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient.instance.post(
        '/api/sos/incidents/${widget.notification.incidentId}/accept/',
        data: {},
      );

      if (response.statusCode == 200) {
        try {
          await ApiClient.instance.post(
            '/api/sos/${widget.notification.incidentId}/message/',
            data: {'message': 'Accepted. ETA: $eta.'},
          );
        } catch (_) {}

        setState(() {
          _currentStatus = 'Accepted';
          _isEscalated = false;
        });
        _timer?.cancel();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Accepted SOS alert successfully. Escalation stopped.'),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        context.read<NotificationsProvider>().pollGuardianNotifications();
      } else {
        setState(() {
          _errorMessage = response.data['detail']?.toString() ?? 'Failed to accept SOS.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error accepting SOS alert: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRejectIncident() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Reject Emergency Alert', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to reject this SOS? It will escalate immediately to the next guardian or emergency contact.',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Reject & Escalate', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient.instance.post(
        '/api/sos/incidents/${widget.notification.incidentId}/reject/',
        data: {'reason': 'Rejected by guardian'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _isEscalated = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SOS alert rejected. Escalated immediately.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error rejecting SOS: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _callResident() async {
    final phone = _residentPhone ?? '911';
    final Uri uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Initiating call to resident ($phone)...')),
        );
      }
    }
  }

  Future<void> _navigateToLocation() async {
    String mapUrl = 'https://www.google.com/maps/search/?api=1&query=';
    if (_latitude != null && _longitude != null) {
      mapUrl += '$_latitude,$_longitude';
    } else if (_address != null && _address!.isNotEmpty) {
      mapUrl += Uri.encodeComponent(_address!);
    } else {
      mapUrl += 'Emergency+Location';
    }

    final Uri uri = Uri.parse(mapUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open map application.')),
        );
      }
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
    final isGuardianOrStaff = role == 'ADMIN' || role == 'SECURITY' || role == 'GUARDIAN' || role == 'SOCIETY_MANAGER' || role == 'STAFF' || role == 'VOLUNTEER';
    final isOwner = user != null && widget.notification.message.contains(user.fullName.split(' ').first);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final mins = _escalationSecondsRemaining ~/ 60;
    final secs = _escalationSecondsRemaining % 60;
    final timeStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111418) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'SOS Alert Details',
          style: GoogleFonts.outfit(
            color: Theme.of(context).colorScheme.onSurface,
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
            // Escalation Timeout Banner if escalated
            if (_isEscalated || _escalationSecondsRemaining == 0) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade400, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This incident has been escalated.',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.brown.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_currentStatus == 'Pending') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, color: Colors.blue, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Auto-escalation timer:',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.blue.shade900),
                        ),
                      ],
                    ),
                    Text(
                      timeStr,
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                    ),
                  ],
                ),
              ),
            ],

            // Current Status Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
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
                          color: isDark ? Colors.white38 : Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentStatus!,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
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
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SOS Information',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _priority ?? 'HIGH',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.danger),
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 30, color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)),

                  _buildDetailRow(
                    label: 'Resident Name',
                    value: (_residentName != null && _residentName!.isNotEmpty)
                        ? _residentName!
                        : 'Unknown Resident',
                    icon: Icons.person_rounded,
                  ),
                  _buildDetailRow(
                    label: 'Emergency Category',
                    value: (_categoryName != null && _categoryName!.isNotEmpty)
                        ? _categoryName!
                        : 'SOS Emergency',
                    icon: Icons.emergency_rounded,
                    iconColor: AppTheme.danger,
                  ),
                  _buildDetailRow(
                    label: 'Triggered Time',
                    value: DateFormat('dd MMM yyyy, hh:mm a').format(_createdAt ?? widget.notification.createdAt),
                    icon: Icons.access_time_filled_rounded,
                  ),
                  _buildDetailRow(
                    label: 'Description Message',
                    value: (_message != null && _message!.isNotEmpty)
                        ? _message!
                        : 'Immediate help requested.',
                    icon: Icons.chat_bubble_rounded,
                    isLast: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Emergency Location Widget
            EmergencyLocationWidget(
              latitude: _latitude ?? widget.notification.latitude,
              longitude: _longitude ?? widget.notification.longitude,
              address: _address ?? widget.notification.address,
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
              // Primary Guardian & Responder Action Grid: Accept, Reject, Call Resident, Navigate
              if (isGuardianOrStaff && _currentStatus == 'Pending') ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _handleAcceptWithETA(),
                        icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                        label: Text('Accept', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _handleRejectIncident(),
                        icon: const Icon(Icons.cancel_outlined, color: Colors.white, size: 20),
                        label: Text('Reject', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _callResident(),
                        icon: const Icon(Icons.phone_in_talk_rounded, size: 20),
                        label: Text('Call Resident', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _navigateToLocation(),
                        icon: const Icon(Icons.near_me_rounded, size: 20),
                        label: Text('Navigate', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              if (isGuardianOrStaff && _currentStatus == 'Accepted') ...[
                ElevatedButton.icon(
                  onPressed: () => _updateStatus('in-progress', 'In Progress'),
                  icon: const Icon(Icons.pending_actions_rounded, color: Colors.white),
                  label: Text('Mark In Progress', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              if (isGuardianOrStaff && _currentStatus == 'In Progress') ...[
                ElevatedButton.icon(
                  onPressed: () => _updateStatus('resolve', 'Resolved'),
                  icon: const Icon(Icons.done_all_rounded, color: Colors.white),
                  label: Text('Resolve SOS Alert', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
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

              if ((isGuardianOrStaff || isOwner) && _currentStatus != 'Resolved' && _currentStatus != 'Cancelled')
                OutlinedButton.icon(
                  onPressed: () => _updateStatus('cancel', 'Cancelled'),
                  icon: const Icon(Icons.cancel_outlined, color: AppTheme.danger),
                  label: Text('Cancel SOS Alert', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              radius: 18,
              child: Icon(icon, color: iconColor ?? (isDark ? Colors.white60 : const Color(0xFF64748B)), size: 18),
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
                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!isLast) Divider(height: 24, color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
      ],
    );
  }
}
