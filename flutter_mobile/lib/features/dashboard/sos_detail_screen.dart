import 'dart:async' as java_timer;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/api_client.dart';
import '../../models/notification_model.dart';
import '../../models/sos_incident_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notifications_provider.dart';

import 'widgets/emergency_location_widget.dart';
import 'widgets/sender_incident_view.dart';
import 'widgets/responder_incident_view.dart';

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

  Map<String, dynamic> _incidentData = {};

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

    _incidentData = {
      'id': widget.notification.incidentId,
      'resident_name': widget.notification.residentName,
      'category_name': widget.notification.emergencyCategory,
      'message': widget.notification.incidentMessage,
      'status': _currentStatus,
      'latitude': widget.notification.latitude,
      'longitude': widget.notification.longitude,
      'address': widget.notification.address,
      'created_at': widget.notification.createdAt.toIso8601String(),
    };

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
          _incidentData = Map<String, dynamic>.from(data);
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

  List<Map<String, dynamic>> _timelineItems = [];

  Future<void> _fetchTimeline() async {
    final incidentId = widget.notification.incidentId;
    if (incidentId <= 0) return;
    try {
      dynamic resData;
      try {
        final res = await ApiClient.instance.get('/api/incident/$incidentId/timeline/');
        resData = res.data;
      } catch (_) {
        final res = await ApiClient.instance.get('/api/sos/incidents/$incidentId/timeline/');
        resData = res.data;
      }

      if (resData != null && resData['timeline'] is List) {
        final List items = resData['timeline'];
        if (mounted) {
          setState(() {
            _timelineItems = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _handleRejectIncident() async {
    final reasonController = TextEditingController();
    final String? reason = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Reject Emergency Alert', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please provide a reason for being unable to respond. It will immediately escalate to the next responder/security.',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Reason (e.g. Out of town, In a meeting)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, null), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final text = reasonController.text.trim();
              Navigator.pop(dialogCtx, text.isNotEmpty ? text : 'Unable to respond');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Reject & Escalate', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (reason == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient.instance.post(
        '/api/sos/incidents/${widget.notification.incidentId}/reject/',
        data: {'reason': reason},
      );

      if (response.statusCode == 200) {
        setState(() {
          _isEscalated = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SOS alert rejected. Immediate escalation triggered.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        await _fetchTimeline();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error rejecting SOS: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Accepted':
      case 'Active':
      case 'Assigned':
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


  Future<void> _cancelSOS() async {
    final incidentId = widget.notification.incidentId;
    if (incidentId <= 0) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel SOS Emergency', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to cancel your SOS emergency alert?', style: GoogleFonts.inter(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No, keep active')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel SOS'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await ApiClient.instance.patch(
          '/api/sos/incidents/$incidentId/cancel/',
          data: {'remarks': 'Cancelled by resident'},
        );
        await _fetchFullIncidentDetails();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Emergency SOS cancelled.'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cancel error: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _declineSOS() async {
    final incidentId = widget.notification.incidentId;
    if (incidentId <= 0) return;
    final reasonCtrl = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Decline SOS Alert', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Declining will escalate this alert to the next emergency tier.', style: GoogleFonts.inter(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Reason (Optional)', hintText: 'Unable to respond...'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Decline SOS'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await ApiClient.instance.post(
          '/api/sos/incidents/$incidentId/reject/',
          data: {'reason': reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : 'Unable to respond'},
        );
        await _fetchFullIncidentDetails();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SOS Alert declined.'), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Decline error: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToChat() {
    final incidentId = widget.notification.incidentId;
    if (incidentId > 0) {
      context.push('/emergency-chat', extra: {'id': incidentId});
    }
  }

  void _shareLocation() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sharing emergency location with responders...'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final model = SOSIncidentModel.fromJson(_incidentData);

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
          model.isSender ? 'My Emergency SOS' : 'SOS Alert Details',
          style: GoogleFonts.outfit(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchFullIncidentDetails,
        child: model.isSender
            ? SenderIncidentView(
                incident: model,
                onCancelSOS: _cancelSOS,
                onRefresh: _fetchFullIncidentDetails,
              )
            : ResponderIncidentView(
                incident: model,
                onAccept: _handleAcceptWithETA,
                onDecline: _declineSOS,
                onChat: _navigateToChat,
                onCall: _callResident,
                onNavigate: _navigateToLocation,
                onShareLocation: _shareLocation,
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
