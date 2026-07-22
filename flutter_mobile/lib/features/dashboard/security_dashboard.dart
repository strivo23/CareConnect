import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../models/notification_model.dart';

class SecurityDashboardScreen extends StatefulWidget {
  const SecurityDashboardScreen({super.key});

  @override
  State<SecurityDashboardScreen> createState() => _SecurityDashboardScreenState();
}

class _SecurityDashboardScreenState extends State<SecurityDashboardScreen> with TickerProviderStateMixin {
  bool _loadingIncidents = false;
  List<dynamic> _allIncidents = [];
  List<dynamic> _filteredIncidents = [];
  String _searchQuery = '';
  String _selectedFilter = 'All';
  late TabController _tabController;

  final List<String> _filters = ['All', 'Pending', 'Accepted', 'In Progress', 'Resolved', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filters.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedFilter = _filters[_tabController.index];
          _applyFilters();
        });
      }
    });
    _fetchIncidents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchIncidents() async {
    setState(() => _loadingIncidents = true);
    try {
      final res = await ApiClient.instance.get('/api/sos/incidents/');
      if (res.statusCode == 200 && res.data != null) {
        final List list = res.data is List ? res.data : (res.data['results'] is List ? res.data['results'] : []);
        setState(() {
          _allIncidents = list;
          _applyFilters();
        });
      }
    } catch (e) {
      debugPrint('Error fetching incidents: $e');
    } finally {
      setState(() => _loadingIncidents = false);
    }
  }

  void _applyFilters() {
    var filtered = _allIncidents;

    if (_selectedFilter != 'All') {
      filtered = filtered.where((inc) => inc['status'] == _selectedFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((inc) {
        final residentName = inc['resident_name']?.toString().toLowerCase() ?? '';
        final categoryName = inc['category_name']?.toString().toLowerCase() ?? '';
        final message = inc['message']?.toString().toLowerCase() ?? '';
        final address = inc['address']?.toString().toLowerCase() ?? '';
        return residentName.contains(query) || categoryName.contains(query) || message.contains(query) || address.contains(query);
      }).toList();
    }

    setState(() {
      _filteredIncidents = filtered;
    });
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
        return Colors.grey;
      default:
        return Colors.grey;
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
          'Security Dashboard',
          style: GoogleFonts.outfit(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _filters.map((filter) => Tab(text: filter)).toList(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search incidents...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _applyFilters();
                });
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchIncidents,
              child: _loadingIncidents
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(color: AppTheme.primary),
                      ),
                    )
                  : _filteredIncidents.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              children: [
                                Icon(Icons.check_circle_outline_rounded, color: Colors.green.shade300, size: 48),
                                const SizedBox(height: 12),
                                Text(
                                  'No incidents found for this filter.',
                                  style: GoogleFonts.inter(color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredIncidents.length,
                          itemBuilder: (context, index) {
                            final item = _filteredIncidents[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              color: Theme.of(context).colorScheme.surface,
                              elevation: 0,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                leading: CircleAvatar(
                                  backgroundColor: _getStatusColor(item['status']).withOpacity(0.1),
                                  child: Icon(Icons.emergency_rounded, color: _getStatusColor(item['status'])),
                                ),
                                title: Text(
                                  item['category_name']?.toString() ?? 'Emergency Alert',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text('Resident: ${item['resident_name'] ?? 'Unknown'}'),
                                    const SizedBox(height: 2),
                                    Text('Priority: ${item['priority'] ?? 'Medium'}'),
                                    if (item['address'] != null) ...[
                                      const SizedBox(height: 2),
                                      Text('Address: ${item['address']}'),
                                    ],
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(item['status']).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        item['status'] ?? 'Unknown',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: _getStatusColor(item['status']),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      height: 32,
                                      child: ElevatedButton(
                                        onPressed: () {
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
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red.shade900,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                        ),
                                        child: const Text('View', style: TextStyle(fontSize: 12)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
