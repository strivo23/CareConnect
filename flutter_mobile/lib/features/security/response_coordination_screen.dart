import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/services/api_client.dart';
import '../chat/emergency_chat_screen.dart';
import '../feed/incident_response_feed_screen.dart';
import 'incident_resolution_screen.dart';

class ResponseCoordinationScreen extends StatefulWidget {
  final Map<String, dynamic> incidentData;

  const ResponseCoordinationScreen({
    super.key,
    required this.incidentData,
  });

  @override
  State<ResponseCoordinationScreen> createState() => _ResponseCoordinationScreenState();
}

class _ResponseCoordinationScreenState extends State<ResponseCoordinationScreen> {
  late Map<String, dynamic> _incident;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _incident = Map<String, dynamic>.from(widget.incidentData);
  }

  Future<void> _updateStatus(String actionStatus) async {
    setState(() => _isLoading = true);
    try {
      final incidentId = _incident['id'];
      final res = await ApiClient.instance.post('/security/incidents/$incidentId/status/', data: {
        'status': actionStatus,
      });

      if (res.data != null && res.data['success'] == true) {
        if (mounted) {
          final loc = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${loc.translate('statusUpdatedTo')} $actionStatus')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptIncident() async {
    setState(() => _isLoading = true);
    try {
      final incidentId = _incident['id'];
      final res = await ApiClient.instance.post('/sos/incidents/$incidentId/accept/');
      if (res.data != null) {
        setState(() {
          _incident['assigned_responder_name'] = res.data['assigned_responder_name'] ?? 'Security Staff';
          _incident['current_status'] = 'ACTIVE';
        });
        if (mounted) {
          final loc = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.translate('incidentAcceptedBySecurity'))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept incident: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _callPhone(String? phone) async {
    if (phone == null || phone.isEmpty || phone.contains('*')) {
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.translate('phoneMaskedNotice'))),
      );
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final incidentId = _incident['id'];
    final residentName = _incident['resident_name'] ?? 'Resident';
    final residentPhone = _incident['resident_phone'] ?? '';
    final categoryName = _incident['category_name'] ?? 'Emergency';
    final currentStatus = _incident['current_status'] ?? 'OPEN';
    final assignedResponder = _incident['assigned_responder_name'] ?? 'Unassigned';

    return Scaffold(
      appBar: AppBar(
        title: Text('${loc.translate('responseCoordination')} #$incidentId', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Incident Status Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(categoryName, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red.shade800)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(8)),
                          child: Text(currentStatus, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('${loc.translate('resident')}: $residentName', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${loc.translate('assignedResponder')}: $assignedResponder', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Responders Status Timeline
            Text(loc.translate('responderArrivalStatus'), style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            _buildStatusTile(loc.translate('resident'), residentName, Icons.person, Colors.blue),
            _buildStatusTile(loc.translate('guardianStatus'), loc.translate('guardianNotified'), Icons.shield_outlined, Colors.orange),
            _buildStatusTile(loc.translate('volunteerStatus'), loc.translate('volunteerAssigned'), Icons.volunteer_activism, Colors.teal),
            _buildStatusTile(loc.translate('securityStatus'), assignedResponder, Icons.shield, Colors.red),
            const SizedBox(height: 24),

            // Operational Action Buttons Grid
            Text(loc.translate('securityActions'), style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _acceptIncident,
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: Text(loc.translate('acceptIncident'), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _updateStatus('RESPONDING'),
                          icon: const Icon(Icons.directions_run_rounded, size: 18),
                          label: Text(loc.translate('markResponding'), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _updateStatus('ARRIVED'),
                          icon: const Icon(Icons.location_on_rounded, size: 18),
                          label: Text(loc.translate('markArrived'), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _updateStatus('REQUEST_BACKUP'),
                          icon: const Icon(Icons.sos_rounded, size: 18),
                          label: Text(loc.translate('requestBackup'), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    leading: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
                    title: Text(loc.translate('emergencyChat'), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text(loc.translate('emergencyChatSub'), style: GoogleFonts.inter(fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => EmergencyChatScreen(incidentData: _incident),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    leading: const Icon(Icons.history_toggle_off_rounded, color: Colors.teal),
                    title: Text(loc.translate('responseUpdates'), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text(loc.translate('responseUpdatesTimeline'), style: GoogleFonts.inter(fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => IncidentResponseFeedScreen(incidentData: _incident),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    leading: const Icon(Icons.phone_rounded, color: Colors.green),
                    title: Text('${loc.translate('callContact')}: $residentName', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                    trailing: const Icon(Icons.phone),
                    onTap: () => _callPhone(residentPhone),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final res = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => IncidentResolutionScreen(incidentData: _incident),
                          ),
                        );
                        if (res == true && mounted) {
                          Navigator.pop(context, true);
                        }
                      },
                      icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                      label: Text(loc.translate('resolveIncident'), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTile(String title, String status, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 20)),
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(status, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700)),
      ),
    );
  }
}
