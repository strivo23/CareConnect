import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/api_client.dart';

class ContactDirectoryScreen extends StatefulWidget {
  const ContactDirectoryScreen({super.key});

  @override
  State<ContactDirectoryScreen> createState() => _ContactDirectoryScreenState();
}

class _ContactDirectoryScreenState extends State<ContactDirectoryScreen> {
  final List<Map<String, dynamic>> _contacts = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String _selectedRole = 'ALL';
  bool _onlyAvailable = false;
  bool _onlyEmergency = false;

  @override
  void initState() {
    super.initState();
    _fetchDirectory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchDirectory() async {
    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> queryParams = {};
      if (_selectedRole != 'ALL') queryParams['role'] = _selectedRole;
      if (_onlyAvailable) queryParams['available'] = 'true';
      if (_onlyEmergency) queryParams['is_emergency_contact'] = 'true';
      if (_searchController.text.trim().isNotEmpty) queryParams['search'] = _searchController.text.trim();

      final res = await ApiClient.instance.get('/api/directory/', queryParameters: queryParams);
      if (res.data != null) {
        final List results = res.data['results'] ?? res.data ?? [];
        setState(() {
          _contacts.clear();
          _contacts.addAll(results.cast<Map<String, dynamic>>());
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load directory: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _callPhone(String? phone) async {
    if (phone == null || phone.contains('*') || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number is masked due to privacy settings.')),
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Society Contact Directory', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchDirectory,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _fetchDirectory(),
                  decoration: InputDecoration(
                    hintText: 'Search by name, role, phone...',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _fetchDirectory();
                      },
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['ALL', 'VOLUNTEER', 'SECURITY', 'RESIDENT', 'GUARDIAN'].map((role) {
                      final isSelected = _selectedRole == role;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(role, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87)),
                          selected: isSelected,
                          selectedColor: Colors.red.shade700,
                          backgroundColor: Colors.grey.shade200,
                          onSelected: (val) {
                            setState(() => _selectedRole = role);
                            _fetchDirectory();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Contacts List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _contacts.isEmpty
                    ? Center(
                        child: Text('No directory contacts found.', style: GoogleFonts.inter(color: Colors.grey)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _contacts.length,
                        itemBuilder: (context, index) {
                          final item = _contacts[index];
                          final isEmergency = item['is_emergency_contact'] == true;
                          final isMasked = item['is_masked'] == true;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.red.shade100,
                                    child: Text(
                                      (item['full_name'] ?? 'U')[0].toUpperCase(),
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.red.shade900),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(item['full_name'] ?? 'User', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade50,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(item['role'] ?? '', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                                            ),
                                            if (isEmergency) ...[
                                              const SizedBox(width: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                decoration: BoxDecoration(color: Colors.red.shade700, borderRadius: BorderRadius.circular(4)),
                                                child: Text('SOS', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text('Phone: ${item['phone_number'] ?? 'N/A'}', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700)),
                                        if (item['society_name'] != null)
                                          Text('Society: ${item['society_name']}', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      isMasked ? Icons.phone_locked_rounded : Icons.phone_rounded,
                                      color: isMasked ? Colors.grey : Colors.green.shade700,
                                    ),
                                    onPressed: () => _callPhone(item['phone_number']),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
