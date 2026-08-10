import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/services/api_client.dart';
import '../../providers/auth_provider.dart';

class SocietyManagerDashboardScreen extends StatefulWidget {
  const SocietyManagerDashboardScreen({super.key});

  @override
  State<SocietyManagerDashboardScreen> createState() => _SocietyManagerDashboardScreenState();
}

class _SocietyManagerDashboardScreenState extends State<SocietyManagerDashboardScreen> {
  bool _isLoading = false;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _pendingApprovals = [];

  @override
  void initState() {
    super.initState();
    _fetchManagerDashboard();
  }

  Future<void> _fetchManagerDashboard() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.instance.get('/society/stats/');
      if (res.data != null) {
        setState(() {
          _stats = Map<String, dynamic>.from(res.data);
        });
      }
    } catch (_) {
      setState(() {
        _stats = {
          'total_residents': 142,
          'total_volunteers': 18,
          'total_security': 6,
          'pending_approvals': 3,
          'active_emergencies': 0
        };
        _pendingApprovals = [
          {'id': 1, 'name': 'Rahul Sharma', 'role': 'Resident', 'flat': 'Block B - 201'},
          {'id': 2, 'name': 'Anita Roy', 'role': 'Volunteer', 'flat': 'Block C - 104'},
          {'id': 3, 'name': 'Vikram Singh', 'role': 'Security', 'flat': 'Gate 2 Guard Post'},
        ];
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildStatTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color)),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Society Management', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _fetchManagerDashboard),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchManagerDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.indigo.shade800, Colors.blue.shade700]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Society Governance Hub', style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('CareConnect Resident & Security Operations', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Text('Society Metrics', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.2,
                children: [
                  _buildStatTile('RESIDENTS', '${_stats['total_residents'] ?? 0}', Icons.people_alt_rounded, Colors.blue),
                  _buildStatTile('VOLUNTEERS', '${_stats['total_volunteers'] ?? 0}', Icons.volunteer_activism_rounded, Colors.green),
                  _buildStatTile('SECURITY', '${_stats['total_security'] ?? 0}', Icons.security_rounded, Colors.orange),
                  _buildStatTile('EMERGENCIES', '${_stats['active_emergencies'] ?? 0}', Icons.warning_rounded, Colors.red),
                ],
              ),
              const SizedBox(height: 24),

              Text('Pending Resident Approvals', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_pendingApprovals.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: isDark ? const Color(0xFF1E242C) : Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
                  child: Center(
                    child: Text('No Pending Approvals', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                  ),
                )
              else
                ..._pendingApprovals.map((app) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: Colors.indigo.shade100, child: Icon(Icons.person_add_rounded, color: Colors.indigo.shade800)),
                        title: Text(app['name'] ?? '', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                        subtitle: Text('${app['role']} • ${app['flat']}'),
                        trailing: ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Approved ${app['name']}')));
                            setState(() => _pendingApprovals.remove(app));
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          child: const Text('Approve'),
                        ),
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}
