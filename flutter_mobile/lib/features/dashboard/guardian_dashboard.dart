import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/api_client.dart';
import '../../core/localization/app_localizations.dart';

import 'dart:async';

class GuardianDashboardScreen extends StatefulWidget {
  const GuardianDashboardScreen({super.key});

  @override
  State<GuardianDashboardScreen> createState() => _GuardianDashboardScreenState();
}

class _GuardianDashboardScreenState extends State<GuardianDashboardScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _activeAlerts = [];
  List<Map<String, dynamic>> _linkedResidents = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchGuardianDashboard();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _fetchGuardianDashboard(showLoading: false);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchGuardianDashboard({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _isLoading = true);
    try {
      dynamic resData;
      try {
        final res = await ApiClient.instance.get('/api/guardian/dashboard/');
        resData = res.data;
      } catch (_) {
        final res = await ApiClient.instance.get('/api/emergency/guardians/dashboard/');
        resData = res.data;
      }

      if (resData != null && resData is Map) {
        final List alerts = resData['active_alerts'] is List ? resData['active_alerts'] as List : [];
        final List residents = resData['linked_residents'] is List ? resData['linked_residents'] as List : [];
        if (mounted) {
          setState(() {
            _activeAlerts = alerts.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            _linkedResidents = residents.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading guardian dashboard: $e');
    } finally {
      if (showLoading && mounted) setState(() => _isLoading = false);
    }
  }


  void _showGuardianRejectionDialog(int incidentId) {
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
                'Rejecting will automatically escalate this SOS alert to the next emergency tier.',
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
                final finalReason = reasonController.text.trim().isNotEmpty
                    ? '$selectedReason: ${reasonController.text.trim()}'
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
                    _fetchGuardianDashboard(showLoading: false);
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

  Future<void> _makeCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Guardian Command', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchGuardianDashboard,
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchGuardianDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade800, Colors.orange.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: Colors.white, size: 28),
                        const SizedBox(width: 10),
                        Text('Guardian Monitor', style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Monitoring ${_linkedResidents.length} Linked Ward(s)', style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Active Resident Emergencies
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Active Ward Emergencies', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: _activeAlerts.isEmpty ? Colors.green.shade100 : Colors.red.shade100, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      _activeAlerts.isEmpty ? 'All Safe' : '${_activeAlerts.length} Active',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _activeAlerts.isEmpty ? Colors.green.shade800 : Colors.red.shade800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_activeAlerts.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: isDark ? const Color(0xFF1E242C) : Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, color: Colors.green.shade600, size: 48),
                      const SizedBox(height: 12),
                      Text('No Active Emergencies', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Your wards are currently safe.', style: GoogleFonts.inter(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                )
              else
                ..._activeAlerts.map((alert) {
                  final incidentId = alert['id'];
                  final statusStr = alert['status']?.toString() ?? 'Pending';
                  final isAccepted = statusStr == 'Accepted' || statusStr == 'Assigned' || statusStr == 'In Progress';

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: isAccepted ? Colors.green.shade100 : Colors.red.shade100,
                                child: Icon(
                                  isAccepted ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                                  color: isAccepted ? Colors.green : Colors.red,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(alert['resident_name'] ?? 'Ward', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text('${alert['category']} • ${alert['flat']}', style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isAccepted ? Colors.green.shade600 : Colors.red.shade600,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isAccepted ? 'ACCEPTED' : 'EMERGENCY',
                                  style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          if (alert['address'] != null && alert['address'].toString().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text('📍 ${alert['address']}', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700)),
                          ],
                          const Divider(height: 24),
                          // Action buttons controlled by backend permission flags
                          Row(
                            children: [
                              if (alert['can_accept'] == true) ...[
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      try {
                                        await ApiClient.instance.post('/api/sos/incidents/$incidentId/accept/');
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Accepted SOS Alert! Assigned as Guardian.'), backgroundColor: Colors.green),
                                          );
                                          _fetchGuardianDashboard(showLoading: false);
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.check_circle, size: 16),
                                    label: const Text('Accept'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (alert['can_decline'] == true) ...[
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showGuardianRejectionDialog(incidentId),
                                    icon: const Icon(Icons.cancel, size: 16),
                                    label: const Text('Reject'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (alert['can_call'] == true) ...[
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _makeCall(alert['phone'] ?? ''),
                                    icon: const Icon(Icons.phone, size: 16),
                                    label: const Text('Call'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (alert['can_chat'] == true) ...[
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => context.push('/assigned-incident', extra: alert),
                                    icon: const Icon(Icons.chat, size: 16),
                                    label: const Text('View & Chat'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 24),

              // Ward Health & Details
              Text('Linked Ward Medical Profiles', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._linkedResidents.map((res) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E242C) : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(res['name'] ?? '', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.blue.shade600, borderRadius: BorderRadius.circular(6)),
                              child: Text('Blood: ${res['blood_group'] ?? 'N/A'}', style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Flat: ${res['flat'] ?? ''} • Relation: ${res['relation'] ?? ''}', style: GoogleFonts.inter(color: Colors.grey.shade700, fontSize: 13)),
                        const SizedBox(height: 6),
                        Text('Medical Notes: ${res['medical_conditions'] ?? 'None recorded'}', style: GoogleFonts.inter(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
