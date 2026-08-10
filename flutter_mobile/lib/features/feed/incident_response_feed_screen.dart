import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/api_client.dart';

class IncidentResponseFeedScreen extends StatefulWidget {
  final Map<String, dynamic> incidentData;

  const IncidentResponseFeedScreen({
    super.key,
    required this.incidentData,
  });

  @override
  State<IncidentResponseFeedScreen> createState() => _IncidentResponseFeedScreenState();
}

class _IncidentResponseFeedScreenState extends State<IncidentResponseFeedScreen> {
  late Map<String, dynamic> _incident;
  final List<Map<String, dynamic>> _updates = [];
  final TextEditingController _msgController = TextEditingController();
  bool _isLoading = true;
  String _selectedUpdateType = 'NOTE';

  bool get _isClosed => ['CLOSED', 'Closed'].contains(_incident['current_status'] ?? _incident['status']);

  @override
  void initState() {
    super.initState();
    _incident = Map<String, dynamic>.from(widget.incidentData);
    _fetchUpdates();
  }

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  Future<void> _fetchUpdates() async {
    final incidentId = _incident['id'];
    if (incidentId == null) return;

    try {
      final res = await ApiClient.instance.get('/api/sos/incidents/$incidentId/updates/');
      if (res.data != null) {
        final List results = res.data['results'] ?? res.data ?? [];
        setState(() {
          _updates.clear();
          _updates.addAll(results.cast<Map<String, dynamic>>());
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _postUpdate() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _isClosed) return;

    try {
      final incidentId = _incident['id'];
      await ApiClient.instance.post('/api/sos/incidents/$incidentId/updates/', data: {
        'message': text,
        'update_type': _selectedUpdateType,
        'visibility': 'PUBLIC',
      });
      _msgController.clear();
      _fetchUpdates();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post update: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Response Feed #${_incident['id']}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchUpdates,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isClosed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: Colors.grey.shade300,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock, size: 16, color: Colors.black87),
                  const SizedBox(width: 8),
                  Text('Incident is Closed. Feed is read-only.', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
            ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _updates.isEmpty
                    ? Center(child: Text('No response updates recorded yet.', style: GoogleFonts.inter(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _updates.length,
                        itemBuilder: (context, index) {
                          final item = _updates[index];
                          final author = item['author_name'] ?? 'SYSTEM';
                          final role = item['role'] ?? 'SYSTEM';
                          final type = item['update_type'] ?? 'TEXT';
                          final msg = item['message'] ?? '';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
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
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade100,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(type, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(author, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                                      ],
                                    ),
                                    Text(
                                      item['created_at'] != null ? item['created_at'].toString().split('T')[0] : '',
                                      style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(msg, style: GoogleFonts.inter(fontSize: 14)),
                                if (item['latitude'] != null) ...[
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () => launchUrl(Uri.parse('https://maps.google.com/?q=${item['latitude']},${item['longitude']}')),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.location_on, color: Colors.red, size: 16),
                                        const SizedBox(width: 4),
                                        Text('View Location Card', style: GoogleFonts.inter(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
          ),

          if (!_isClosed)
            SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: Colors.white,
                child: Row(
                  children: [
                    DropdownButton<String>(
                      value: _selectedUpdateType,
                      underline: const SizedBox(),
                      items: ['NOTE', 'ARRIVAL', 'SECURITY', 'MEDICAL', 'STATUS'].map((t) {
                        return DropdownMenuItem(value: t, child: Text(t, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedUpdateType = val);
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        decoration: InputDecoration(
                          hintText: 'Post response update...',
                          hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: Colors.red.shade700,
                      child: IconButton(
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                        onPressed: _postUpdate,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
