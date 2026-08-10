import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/api_client.dart';
import '../../core/localization/app_localizations.dart';
import '../../providers/notifications_provider.dart';
import '../../services/location_service.dart';
import '../../models/notification_model.dart';

class VolunteerDashboardScreen extends StatefulWidget {
  const VolunteerDashboardScreen({super.key});

  @override
  State<VolunteerDashboardScreen> createState() => _VolunteerDashboardScreenState();
}

class _VolunteerDashboardScreenState extends State<VolunteerDashboardScreen> {
  bool _isOnline = true;
  bool _updatingPresence = false;
  double? _latitude;
  double? _longitude;
  String _locationStatus = 'No location registered';
  bool _loadingIncidents = false;
  List<dynamic> _nearbyIncidents = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _fetchNearbyIncidents();
  }

  Future<void> _loadProfile() async {
    try {
      final res = await ApiClient.instance.get('/api/accounts/me/');
      if (res.statusCode == 200 && res.data != null) {
        final profile = res.data['volunteer_profile'];
        if (profile != null) {
          setState(() {
            _isOnline = profile['is_online'] ?? true;
            if (profile['latitude'] != null) {
              _latitude = double.tryParse(profile['latitude'].toString());
              _longitude = double.tryParse(profile['longitude'].toString());
              _locationStatus = 'Lat: ${_latitude?.toStringAsFixed(4)}, Lon: ${_longitude?.toStringAsFixed(4)}';
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading volunteer profile: $e');
    }
  }

  Future<void> _fetchNearbyIncidents() async {
    setState(() => _loadingIncidents = true);
    try {
      final res = await ApiClient.instance.get('/api/sos/incidents/');
      if (res.statusCode == 200 && res.data != null) {
        final List list = res.data is List ? res.data : (res.data['results'] is List ? res.data['results'] : []);
        setState(() {
          // Filter to show active (Pending/Accepted) incidents
          _nearbyIncidents = list.where((inc) => inc['status'] == 'Pending' || inc['status'] == 'Accepted').toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching nearby incidents: $e');
    } finally {
      setState(() => _loadingIncidents = false);
    }
  }

  Future<void> _togglePresence(bool value) async {
    setState(() {
      _updatingPresence = true;
    });

    try {
      final Map<String, dynamic> data = {
        'is_online': value,
      };

      if (value) {
        // If turning online, grab coordinates automatically
        final loc = LocationService();
        final pos = await loc.getCurrentLocation();
        if (pos != null) {
          data['latitude'] = pos.latitude;
          data['longitude'] = pos.longitude;
          _latitude = pos.latitude;
          _longitude = pos.longitude;
          _locationStatus = 'Lat: ${pos.latitude.toStringAsFixed(4)}, Lon: ${pos.longitude.toStringAsFixed(4)}';
        }
      }

      final res = await ApiClient.instance.patch('/api/accounts/me/', data: data);
      await ApiClient.instance.patch('/api/accounts/volunteer/availability/', data: {
        'is_online': value,
        'availability_status': value ? 'ONLINE' : 'OFFLINE',
        if (data.containsKey('latitude')) 'latitude': data['latitude'],
        if (data.containsKey('longitude')) 'longitude': data['longitude'],
      });

      if (res.statusCode == 200) {
        setState(() {
          _isOnline = value;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(value ? 'Presence set to Online. GPS captured.' : 'Presence set to Offline.'),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update presence: $e'),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() {
        _updatingPresence = false;
      });
    }
  }

  int? _acceptingIncidentId;

  Future<void> _acceptIncident(Map<String, dynamic> item) async {
    final incidentId = item['id'];
    if (incidentId == null) return;

    setState(() {
      _acceptingIncidentId = incidentId;
    });

    try {
      final res = await ApiClient.instance.post('/api/sos/incidents/$incidentId/accept/');

      if (res.statusCode == 200 && res.data != null && res.data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SOS Incident accepted successfully!'),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
          final incidentObj = res.data['incident'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(res.data['incident'])
              : Map<String, dynamic>.from(item);

          context.push('/assigned-incident', extra: incidentObj);
        }
        await _fetchNearbyIncidents();
      } else {
        final msg = res.data?['message'] ?? res.data?['detail'] ?? 'Failed to accept incident.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg.toString()),
              backgroundColor: AppTheme.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      String msg = 'Failed to accept incident.';
      if (e.toString().contains('409') || e.toString().contains('already assigned')) {
        msg = 'This incident has already been assigned.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _acceptingIncidentId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111418) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        title: Text(
          'Volunteer Dashboard',
          style: GoogleFonts.outfit(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadProfile();
          await _fetchNearbyIncidents();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Online availability state card
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: _isOnline ? Colors.green.shade50 : Colors.grey.shade100,
                        child: Icon(
                          _isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                          color: _isOnline ? Colors.green : Colors.grey,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isOnline ? 'Online & Available' : 'Offline / Unavailable',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _locationStatus,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_updatingPresence)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                        )
                      else
                        Switch(
                          value: _isOnline,
                          onChanged: _togglePresence,
                          activeColor: Colors.green,
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Active Nearby Incidents',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    onPressed: _fetchNearbyIncidents,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_loadingIncidents)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  ),
                )
              else if (_nearbyIncidents.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, color: Colors.green.shade300, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'All Quiet! No active incidents nearby.',
                          style: GoogleFonts.inter(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _nearbyIncidents.length,
                  itemBuilder: (context, index) {
                    final item = _nearbyIncidents[index];
                    final isAccepting = _acceptingIncidentId == item['id'];
                    final isAssigned = item['status'] == 'Assigned' || item['status'] == 'Accepted';
                    final assignedResponder = item['assigned_responder_name'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: Theme.of(context).colorScheme.surface,
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.red.shade50,
                                  child: const Icon(Icons.emergency_rounded, color: Colors.red),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['category_name']?.toString() ?? 'Emergency Alert',
                                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Resident: ${item['resident_name'] ?? 'Unknown'}',
                                        style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (isAssigned ? Colors.blue : Colors.orange).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    item['status'] ?? 'Pending',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isAssigned ? Colors.blue : Colors.orange,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Message: ${item['message'] ?? 'Immediate assistance requested'}',
                              style: GoogleFonts.inter(fontSize: 13),
                            ),
                            if (assignedResponder != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Assigned to: $assignedResponder',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: (isAccepting || (isAssigned && assignedResponder != null))
                                        ? null
                                        : () => _acceptIncident(item),
                                    icon: isAccepting
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.check_circle_outline_rounded, size: 18),
                                    label: Text(
                                      isAssigned ? 'Assigned' : 'Accept Incident',
                                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isAssigned ? Colors.grey : Colors.green.shade700,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () {
                                    if (isAssigned) {
                                      context.push('/assigned-incident', extra: Map<String, dynamic>.from(item));
                                    } else {
                                      final fakeNotif = {
                                        'id': 'inc_${item['id']}',
                                        'title': 'Emergency SOS',
                                        'message': '${item['resident_name']} needs help.',
                                        'category': 'sos',
                                        'is_read': false,
                                        'created_at': item['created_at'],
                                        'priority': item['priority'] ?? 'HIGH',
                                        'location': item['address'] ?? '',
                                        'incident': item['id'],
                                        'resident_name': item['resident_name'] ?? '',
                                        'emergency_category': item['category_name'] ?? '',
                                        'incident_message': item['message'] ?? '',
                                        'incident_status': item['status'] ?? 'Pending',
                                      };
                                      final notificationModel = context.read<NotificationsProvider>().notifications.firstWhere(
                                            (notif) => notif.incidentId == item['id'],
                                            orElse: () => context.read<NotificationsProvider>().guardianNotifications.firstWhere(
                                                  (notif) => notif.incidentId == item['id'],
                                                  orElse: () => AppNotificationModel.fromJson(fakeNotif),
                                                ),
                                          );
                                      context.push('/sos-detail', extra: notificationModel);
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('View'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
