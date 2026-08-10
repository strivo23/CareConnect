import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/services/api_client.dart';
import 'response_coordination_screen.dart';

class SecurityDashboardScreen extends StatefulWidget {
  const SecurityDashboardScreen({super.key});

  @override
  State<SecurityDashboardScreen> createState() => _SecurityDashboardScreenState();
}

class _SecurityDashboardScreenState extends State<SecurityDashboardScreen> {
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _incidents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSecurityDashboard();
  }

  Future<void> _fetchSecurityDashboard() async {
    setState(() => _isLoading = true);
    try {
      final resSummary = await ApiClient.instance.get('/security/dashboard/');
      final resIncidents = await ApiClient.instance.get('/security/incidents/');

      if (resSummary.data != null) {
        _summary = resSummary.data['summary'];
      }
      if (resIncidents.data != null) {
        final List results = resIncidents.data['results'] ?? resIncidents.data ?? [];
        _incidents = results.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading security dashboard: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildMetricCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final sum = _summary ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('securityOperationsCommand'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchSecurityDashboard,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchSecurityDashboard,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Grid
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.6,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildMetricCard(loc.translate('activeEmergencies'), '${sum['active_incidents'] ?? 0}', Colors.red, Icons.warning_amber_rounded),
                        _buildMetricCard(loc.translate('assignedResponders'), '${sum['assigned_incidents'] ?? 0}', Colors.orange, Icons.people_outline_rounded),
                        _buildMetricCard(loc.translate('avgResponseTime'), '${sum['average_response_time_minutes'] ?? 4.2}m', Colors.blue, Icons.timer_outlined),
                        _buildMetricCard(loc.translate('resolvedToday'), '${sum['resolved_today'] ?? 0}', Colors.green, Icons.check_circle_outline_rounded),
                      ],
                    ),

                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(loc.translate('activeSecurityIncidents'), style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('${_incidents.length}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Active Incidents List
                    _incidents.isEmpty
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                            child: Center(child: Text(loc.translate('noActiveIncidents'), style: GoogleFonts.inter(color: Colors.grey))),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _incidents.length,
                            itemBuilder: (context, index) {
                              final item = _incidents[index];
                              final status = item['current_status'] ?? 'OPEN';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                child: ListTile(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (ctx) => ResponseCoordinationScreen(incidentData: item),
                                      ),
                                    );
                                  },
                                  title: Text(item['category_name'] ?? 'Emergency', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                                  subtitle: Text('${loc.translate('resident')}: ${item['resident_name'] ?? 'Unknown'}', style: GoogleFonts.inter(fontSize: 12)),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(status, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade900)),
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
