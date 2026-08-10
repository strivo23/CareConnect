import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/api_client.dart';
import '../../core/localization/app_localizations.dart';
import '../../services/location_service.dart';
import '../../models/sos_incident_model.dart';
import '../chat/emergency_chat_screen.dart';
import '../feed/incident_response_feed_screen.dart';
import '../security/incident_resolution_screen.dart';
import 'widgets/emergency_location_widget.dart';
import 'widgets/sender_incident_view.dart';
import 'widgets/responder_incident_view.dart';

class AssignedIncidentScreen extends StatefulWidget {
  const AssignedIncidentScreen({
    super.key,
    required this.incidentData,
  });

  /// Map containing incident details returned by backend API
  final Map<String, dynamic> incidentData;

  @override
  State<AssignedIncidentScreen> createState() => _AssignedIncidentScreenState();
}

class _AssignedIncidentScreenState extends State<AssignedIncidentScreen> {
  late Map<String, dynamic> _incident;
  bool _isLoading = false;
  String? _errorMessage;
  double? _userLat;
  double? _userLon;
  String _calculatedDistance = 'Calculating...';

  @override
  void initState() {
    super.initState();
    _incident = Map<String, dynamic>.from(widget.incidentData);
    _getUserLocationAndDistance();
    _fetchLatestDetails();
  }

  Future<void> _fetchLatestDetails() async {
    final incidentId = _incident['id'];
    if (incidentId == null) return;

    try {
      final res = await ApiClient.instance.get('/api/sos/incidents/$incidentId/');
      if (res.statusCode == 200 && res.data != null) {
        setState(() {
          _incident = Map<String, dynamic>.from(res.data);
        });
        _calculateDistance();
      }
    } catch (e) {
      debugPrint('[AssignedIncidentScreen] Failed to refresh incident: $e');
    }
  }

  Future<void> _getUserLocationAndDistance() async {
    try {
      final loc = LocationService();
      final pos = await loc.getCurrentLocation();
      if (pos != null) {
        setState(() {
          _userLat = pos.latitude;
          _userLon = pos.longitude;
        });
        _calculateDistance();
      }
    } catch (e) {
      debugPrint('[AssignedIncidentScreen] Location error: $e');
      setState(() {
        _calculatedDistance = 'Distance unavailable';
      });
    }
  }

  void _calculateDistance() {
    final incLatStr = _incident['latitude']?.toString();
    final incLonStr = _incident['longitude']?.toString();

    if (incLatStr == null || incLonStr == null) {
      setState(() {
        _calculatedDistance = 'Location coords missing';
      });
      return;
    }

    final incLat = double.tryParse(incLatStr);
    final incLon = double.tryParse(incLonStr);

    if (incLat == null || incLon == null) {
      setState(() {
        _calculatedDistance = 'Invalid coordinates';
      });
      return;
    }

    if (_userLat != null && _userLon != null) {
      final distanceInMeters = Geolocator.distanceBetween(_userLat!, _userLon!, incLat, incLon);
      if (distanceInMeters >= 1000) {
        final km = (distanceInMeters / 1000).toStringAsFixed(1);
        setState(() {
          _calculatedDistance = '$km km away';
        });
      } else {
        final meters = distanceInMeters.round();
        setState(() {
          _calculatedDistance = '$meters m away';
        });
      }
    } else {
      setState(() {
        _calculatedDistance = 'Location pending';
      });
    }
  }

  Future<void> _callResident() async {
    final phone = _incident['resident_phone']?.toString() ??
        _incident['phone_number']?.toString() ??
        _incident['resident_email']?.toString() ??
        '';

    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isNotEmpty) {
      final Uri uri = Uri.parse('tel:$cleanPhone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Initiating direct call to ${phone.isEmpty ? "Resident" : phone}...'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _navigateToLocation() async {
    final incLatStr = _incident['latitude']?.toString();
    final incLonStr = _incident['longitude']?.toString();
    final address = _incident['address']?.toString() ?? _incident['resolved_address']?.toString() ?? '';

    String mapUrl = 'https://www.google.com/maps/search/?api=1&query=';
    if (incLatStr != null && incLonStr != null) {
      mapUrl += '$incLatStr,$incLonStr';
    } else if (address.isNotEmpty) {
      mapUrl += Uri.encodeComponent(address);
    } else {
      mapUrl += 'Emergency+Location';
    }

    final Uri uri = Uri.parse(mapUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch maps navigation.')),
        );
      }
    }
  }

  Future<void> _shareLocation() async {
    final incLatStr = _incident['latitude']?.toString();
    final incLonStr = _incident['longitude']?.toString();
    final address = _incident['address']?.toString() ?? _incident['resolved_address']?.toString() ?? '';
    final residentName = _incident['resident_name']?.toString() ?? 'Resident';

    String shareText = 'Emergency SOS Location for $residentName:\n';
    if (address.isNotEmpty) shareText += 'Address: $address\n';
    if (incLatStr != null && incLonStr != null) {
      shareText += 'Coordinates: $incLatStr, $incLonStr\n';
      shareText += 'Map: https://maps.google.com/?q=$incLatStr,$incLonStr';
    }

    await Clipboard.setData(ClipboardData(text: shareText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency location copied to clipboard!'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _viewTimeline() async {
    final incidentId = _incident['id'];
    if (incidentId == null) return;

    try {
      final res = await ApiClient.instance.get('/api/sos/incidents/$incidentId/timeline/');
      if (res.statusCode == 200 && res.data != null) {
        final List timeline = res.data['timeline'] ?? [];
        if (mounted) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (ctx) => Container(
              padding: const EdgeInsets.all(20),
              height: MediaQuery.of(context).size.height * 0.65,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Incident Lifecycle Timeline', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: timeline.isEmpty
                        ? const Center(child: Text('No timeline events recorded yet.'))
                        : ListView.builder(
                            itemCount: timeline.length,
                            itemBuilder: (context, idx) {
                              final item = timeline[idx];
                              final String statusStr = item['status']?.toString() ?? 'EVENT';
                              final String userName = item['user_name']?.toString() ?? 'System';
                              final String roleStr = item['role']?.toString() ?? '';
                              final String remarks = item['remarks']?.toString() ?? '';
                              final String timeStr = item['time'] != null ? DateFormat.jm().add_yMMMd().format(DateTime.parse(item['time'])) : '';

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: statusStr == 'ESCALATED' ? AppTheme.error.withOpacity(0.15) : AppTheme.primary.withOpacity(0.15),
                                  child: Icon(
                                    statusStr == 'CLOSED' ? Icons.check_circle_outline : Icons.timeline_rounded,
                                    color: statusStr == 'ESCALATED' ? AppTheme.error : AppTheme.primary,
                                  ),
                                ),
                                title: Text('$statusStr - $userName ($roleStr)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (remarks.isNotEmpty) Text(remarks, style: GoogleFonts.inter(fontSize: 12)),
                                    if (timeStr.isNotEmpty) Text(timeStr, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.primary)),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[ViewTimeline] Error: $e');
    }
  }

  Future<void> _transitionLifecycleStatus(String targetStatus) async {
    final incidentId = _incident['id'];
    if (incidentId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient.instance.post(
        '/api/sos/incidents/$incidentId/status/',
        data: {'status': targetStatus, 'remarks': 'Status transition to $targetStatus from Mobile App'},
      );

      if (res.statusCode == 200 && res.data != null) {
        setState(() {
          _incident = Map<String, dynamic>.from(res.data['incident'] ?? _incident);
          _incident['current_status'] = targetStatus;
          _incident['status'] = targetStatus;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lifecycle Status updated to "$targetStatus"'),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = res.data['error']?.toString() ?? 'Failed to update status.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error updating status: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showClosureDialog() async {
    final TextEditingController summaryCtrl = TextEditingController();
    final TextEditingController notesCtrl = TextEditingController();
    String reason = 'Issue Resolved';

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Document Incident Closure', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: summaryCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Resolution Summary *',
                    hintText: 'Brief description of actions taken...',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: reason,
                  decoration: const InputDecoration(labelText: 'Closure Reason *'),
                  items: const [
                    DropdownMenuItem(value: 'Issue Resolved', child: Text('Issue Resolved')),
                    DropdownMenuItem(value: 'False Alarm', child: Text('False Alarm')),
                    DropdownMenuItem(value: 'Handed over to Authorities', child: Text('Handed over to Authorities')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => reason = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Closure Notes',
                    hintText: 'Additional notes or handover details...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (summaryCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Resolution summary is required.')),
                  );
                  return;
                }
                Navigator.pop(dialogCtx, true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
              child: const Text('Confirm & Close'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && summaryCtrl.text.trim().isNotEmpty) {
      final incidentId = _incident['id'];
      setState(() {
        _isLoading = true;
      });

      try {
        final res = await ApiClient.instance.post(
          '/api/sos/incidents/$incidentId/closure/',
          data: {
            'resolution_summary': summaryCtrl.text.trim(),
            'closure_reason': reason,
            'closure_notes': notesCtrl.text.trim(),
          },
        );

        if (res.statusCode == 200 && res.data != null) {
          setState(() {
            _incident = Map<String, dynamic>.from(res.data['incident'] ?? _incident);
            _incident['current_status'] = 'CLOSED';
            _incident['status'] = 'Closed';
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Incident formally closed with documentation.'),
                backgroundColor: AppTheme.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('[ClosureError] $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error closing incident: $e')),
          );
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _reportIssue() async {
    final TextEditingController noteController = TextEditingController();
    final bool? submitted = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Report Issue', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Describe the issue encountered at emergency site:', style: GoogleFonts.inter(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. Resident unreachable, wrong address...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Submit Report', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (submitted == true && noteController.text.trim().isNotEmpty) {
      final incidentId = _incident['id'];
      try {
        await ApiClient.instance.post(
          '/api/sos/$incidentId/message/',
          data: {'message': '[REPORT ISSUE] ${noteController.text.trim()}'},
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Issue reported to dispatch & admins.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        debugPrint('[ReportIssue] Error: $e');
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Accepted':
      case 'Assigned':
        return Colors.blue;
      case 'In Progress':
        return Colors.purple;
      case 'Resolved':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  Future<void> _acceptSOS() async {
    final incidentId = _incident['id'];
    if (incidentId == null) return;
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.instance.post('/api/sos/incidents/$incidentId/accept/');
      if (res.statusCode == 200) {
        await _fetchLatestDetails();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SOS Incident Accepted successfully.'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Accept error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _declineSOS() async {
    final incidentId = _incident['id'];
    if (incidentId == null) return;
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
        await _fetchLatestDetails();
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

  Future<void> _cancelSOS() async {
    final incidentId = _incident['id'];
    if (incidentId == null) return;
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
        await _fetchLatestDetails();
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

  void _navigateToChat() {
    final incidentId = _incident['id'];
    if (incidentId != null) {
      context.push('/emergency-chat', extra: {'id': incidentId});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final model = SOSIncidentModel.fromJson(_incident);

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
          model.isSender ? 'My Emergency SOS' : 'Assigned SOS Incident',
          style: GoogleFonts.outfit(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchLatestDetails,
        child: model.isSender
            ? SenderIncidentView(
                incident: model,
                onCancelSOS: _cancelSOS,
                onRefresh: _fetchLatestDetails,
              )
            : ResponderIncidentView(
                incident: model,
                onAccept: _acceptSOS,
                onDecline: _declineSOS,
                onChat: _navigateToChat,
                onCall: _callResident,
                onNavigate: _navigateToLocation,
                onShareLocation: _shareLocation,
                onViewTimeline: _viewTimeline,
              ),
      ),
    );
  }

  Widget _buildRow(IconData icon, String label, String value, {Color? iconColor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            child: Icon(icon, size: 18, color: iconColor ?? (isDark ? Colors.white60 : Colors.grey.shade600)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
