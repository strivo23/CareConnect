import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../services/contacts_repository.dart';
import '../../models/contact_model.dart';
import '../../providers/auth_provider.dart';

// Local data model for Emergency Contacts
class LocalContact {
  final String id;
  final String name;
  final String relationship;
  final String phone;
  final bool isPrimary;
  final String category; // 'Family', 'Friends', 'Neighbours', 'Other'

  LocalContact({
    required this.id,
    required this.name,
    required this.relationship,
    required this.phone,
    required this.isPrimary,
    required this.category,
  });

  LocalContact copyWith({
    String? name,
    String? relationship,
    String? phone,
    bool? isPrimary,
    String? category,
  }) {
    return LocalContact(
      id: id,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      phone: phone ?? this.phone,
      isPrimary: isPrimary ?? this.isPrimary,
      category: category ?? this.category,
    );
  }
}

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> with SingleTickerProviderStateMixin {
  List<LocalContact> _contacts = [];
  bool _isLoading = false;
  final _contactsRepository = ContactsRepository();

  @override
  void initState() {
    super.initState();
    _loadContactsFromBackend();
  }

  Future<void> _loadContactsFromBackend() async {
    setState(() => _isLoading = true);
    try {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        final list = await _contactsRepository.fetchContacts(residentId: user.id);
        setState(() {
          _contacts = list.map((c) => LocalContact(
            id: c.id.toString(),
            name: c.name,
            relationship: c.relationshipName,
            phone: c.phone,
            isPrimary: c.isPrimary,
            category: _mapCategory(c.relationshipName),
          )).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading contacts: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _mapCategory(String relName) {
    final lower = relName.toLowerCase();
    if (lower.contains('father') || lower.contains('mother') || lower.contains('brother') || lower.contains('sister') || lower.contains('parent') || lower.contains('family')) {
      return 'Family';
    } else if (lower.contains('friend')) {
      return 'Friends';
    } else if (lower.contains('neighbour') || lower.contains('neighbor')) {
      return 'Neighbours';
    } else {
      return 'Other';
    }
  }

  Future<int?> _getOrCreateRelationshipId(String relName) async {
    try {
      final list = await _contactsRepository.fetchRelationships();
      final match = list.firstWhere(
        (r) => r.name.toLowerCase() == relName.toLowerCase(),
        orElse: () => RelationshipModel(id: -1, name: ''),
      );
      if (match.id != -1) {
        return match.id;
      }
      return list.isNotEmpty ? list.first.id : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _addContactBackend(LocalContact contact) async {
    setState(() => _isLoading = true);
    try {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        final relId = await _getOrCreateRelationshipId(contact.relationship.isNotEmpty ? contact.relationship : contact.category);
        await _contactsRepository.createContact({
          'resident': user.id,
          'name': contact.name,
          'phone': contact.phone,
          'relationship': relId,
          'is_primary': contact.isPrimary,
          'verified': false,
        });
        await _loadContactsFromBackend();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${contact.name} added successfully!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add contact.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editContactBackend(LocalContact contact) async {
    setState(() => _isLoading = true);
    try {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        final relId = await _getOrCreateRelationshipId(contact.relationship.isNotEmpty ? contact.relationship : contact.category);
        await _contactsRepository.updateContact(int.parse(contact.id), {
          'resident': user.id,
          'name': contact.name,
          'phone': contact.phone,
          'relationship': relId,
          'is_primary': contact.isPrimary,
          'verified': false,
        });
        await _loadContactsFromBackend();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${contact.name} updated successfully!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update contact.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteContactBackend(LocalContact contact) async {
    setState(() => _isLoading = true);
    try {
      await _contactsRepository.deleteContact(int.parse(contact.id));
      await _loadContactsFromBackend();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${contact.name} removed from contacts.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.grey.shade900,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete contact.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Search and Filtering State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = ['All', 'Family', 'Friends', 'Neighbours', 'Primary'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Filter and search logic
  List<LocalContact> get _filteredContacts {
    return _contacts.where((c) {
      // Category filter
      bool matchesCategory = true;
      if (_selectedCategory == 'Primary') {
        matchesCategory = c.isPrimary;
      } else if (_selectedCategory != 'All') {
        matchesCategory = c.category == _selectedCategory;
      }

      // Search query filter
      bool matchesSearch = c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.relationship.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.phone.contains(_searchQuery);

      return matchesCategory && matchesSearch;
    }).toList();
  }

  int get _totalContacts => _contacts.length;
  int get _primaryGuardians => _contacts.where((c) => c.isPrimary).length;

  // Show Bottom Sheet for Add/Edit Form
  void _showContactForm({LocalContact? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ContactFormSheet(
          existing: existing,
          onSubmit: (contact) {
            if (existing == null) {
              _addContactBackend(contact);
            } else {
              _editContactBackend(contact);
            }
          },
        );
      },
    );
  }

  // Delete Confirmation Dialog
  void _confirmDelete(LocalContact contact) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Contact',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete ${contact.name}? They will no longer receive immediate SOS alerts.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteContactBackend(contact);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredContacts;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
                onPressed: () => Navigator.maybePop(context),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Emergency Contacts',
              style: GoogleFonts.outfit(
                color: Colors.black87,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Manage your trusted emergency contacts.',
              style: GoogleFonts.inter(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        titleSpacing: Navigator.canPop(context) ? 0 : 20,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: () => _showContactForm(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showContactForm(),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: Column(
        children: [
          if (_isLoading)
            const LinearProgressIndicator(color: AppTheme.primary),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadContactsFromBackend,
              color: AppTheme.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              // Statistics Row
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Contacts',
                      value: _totalContacts.toString(),
                      icon: Icons.people_alt_rounded,
                      color: AppTheme.primary,
                      bgColor: AppTheme.primarySoft,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Primary',
                      value: _primaryGuardians.toString(),
                      icon: Icons.shield_rounded,
                      color: AppTheme.success,
                      bgColor: Colors.green.shade50,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search contacts...',
                    hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded, color: Colors.grey.shade600),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Filters Row
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = cat;
                          });
                        },
                        selectedColor: AppTheme.primarySoft,
                        backgroundColor: Colors.white,
                        labelStyle: GoogleFonts.inter(
                          color: isSelected ? AppTheme.primary : Colors.grey.shade700,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? AppTheme.primary.withValues(alpha: 0.3) : Colors.grey.shade200,
                          ),
                        ),
                        elevation: 0,
                        pressElevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Contact Cards Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Trusted Circle',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  if (filtered.isNotEmpty)
                    Text(
                      '${filtered.length} found',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Contact List or Empty State
              if (filtered.isEmpty)
                _buildEmptyState()
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final contact = filtered[index];
                    return _buildContactCard(contact);
                  },
                ),
              const SizedBox(height: 28),

              // Trusted Responders Section
              Text(
                'Trusted Emergency Services',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              _buildEmergencyServicesGrid(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
          ),
        ],
      ),
    );
  }

  // Statistics Card Builder
  Widget _buildPageStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: bgColor,
            radius: 22,
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Stat Card Alias to resolve name conflicts
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return _buildPageStatCard(title: title, value: value, icon: icon, color: color, bgColor: bgColor);
  }

  // Contact Card Builder
  Widget _buildContactCard(LocalContact contact) {
    final initials = contact.name.isNotEmpty
        ? contact.name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : '?';

    // Premium iOS style card
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showContactForm(existing: contact),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Avatar with initials
                CircleAvatar(
                  radius: 26,
                  backgroundColor: contact.isPrimary ? AppTheme.primarySoft : Colors.blue.shade50,
                  child: Text(
                    initials,
                    style: GoogleFonts.outfit(
                      color: contact.isPrimary ? AppTheme.primary : Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Details Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              contact.name,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (contact.isPrimary)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'PRIMARY',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              contact.relationship,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            contact.phone,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Action buttons (Edit & Delete)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 20),
                      onPressed: () => _showContactForm(existing: contact),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue.shade50.withValues(alpha: 0.5),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                      onPressed: () => _confirmDelete(contact),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.shade50.withValues(alpha: 0.5),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Trusted Emergency Services Grid Builder
  Widget _buildEmergencyServicesGrid() {
    final List<Map<String, dynamic>> services = [
      {'emoji': '🚑', 'name': 'Ambulance', 'number': '108', 'color': Colors.red},
      {'emoji': '🚓', 'name': 'Police', 'number': '112', 'color': Colors.blue},
      {'emoji': '🚒', 'name': 'Fire', 'number': '101', 'color': Colors.orange},
      {'emoji': '🏥', 'name': 'Hospital', 'number': 'Emergency', 'color': Colors.teal},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.55,
      ),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final svc = services[index];
        final serviceColor = svc['color'] as Color;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.grey.shade100),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    svc['emoji'] as String,
                    style: const TextStyle(fontSize: 22),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: serviceColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      svc['number'] as String,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: serviceColor,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      svc['name'] as String,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      debugPrint('Emergency Services trigger call: ${svc['name']} at ${svc['number']}');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Calling ${svc['name']} (${svc['number']})... (Simulated)'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: serviceColor,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.call_rounded, color: Colors.white, size: 14),
                    style: IconButton.styleFrom(
                      backgroundColor: serviceColor,
                      padding: const EdgeInsets.all(6),
                      minimumSize: const Size(28, 28),
                    ),
                  )
                ],
              )
            ],
          ),
        );
      },
    );
  }

  // Empty State Widget Builder
  Widget _buildEmptyState() {
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 300),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Large illustration icon
              Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_add_disabled_rounded,
                  color: AppTheme.primary,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No Emergency Contacts',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add trusted family members or friends.\nThey will receive SOS alerts instantly.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _showContactForm(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Contact'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Add/Edit Bottom Sheet Widget
class _ContactFormSheet extends StatefulWidget {
  final LocalContact? existing;
  final Function(LocalContact) onSubmit;

  const _ContactFormSheet({
    this.existing,
    required this.onSubmit,
  });

  @override
  State<_ContactFormSheet> createState() => _ContactFormSheetState();
}

class _ContactFormSheetState extends State<_ContactFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late String _name;
  late String _relationship;
  late String _phone;
  late bool _isPrimary;
  late String _category;

  final List<String> _categoryOptions = ['Family', 'Friends', 'Neighbours', 'Other'];

  @override
  void initState() {
    super.initState();
    _name = widget.existing?.name ?? '';
    _relationship = widget.existing?.relationship ?? '';
    _phone = widget.existing?.phone ?? '';
    _isPrimary = widget.existing?.isPrimary ?? false;
    _category = widget.existing?.category ?? 'Family';
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final contact = LocalContact(
        id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _name,
        relationship: _relationship,
        phone: _phone,
        isPrimary: _isPrimary,
        category: _category,
      );
      Navigator.pop(context);
      widget.onSubmit(contact);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bottom sheet handle/title
              Center(
                child: Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.existing == null ? 'Add Contact' : 'Edit Contact',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),

              // Full Name
              TextFormField(
                initialValue: _name,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  labelStyle: GoogleFonts.inter(color: Colors.grey.shade600),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a name' : null,
                onSaved: (val) => _name = val!.trim(),
              ),
              const SizedBox(height: 16),

              // Category & Relationship row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Dropdown
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _category,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        labelStyle: GoogleFonts.inter(color: Colors.grey.shade600),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      items: _categoryOptions.map((opt) {
                        return DropdownMenuItem(value: opt, child: Text(opt));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _category = val;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Relationship Text
                  Expanded(
                    child: TextFormField(
                      initialValue: _relationship,
                      decoration: InputDecoration(
                        labelText: 'Relation',
                        hintText: 'e.g. Father, Friend',
                        labelStyle: GoogleFonts.inter(color: Colors.grey.shade600),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'Enter relationship' : null,
                      onSaved: (val) => _relationship = val!.trim(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Phone Number
              TextFormField(
                initialValue: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  labelStyle: GoogleFonts.inter(color: Colors.grey.shade600),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Please enter a phone number' : null,
                onSaved: (val) => _phone = val!.trim(),
              ),
              const SizedBox(height: 12),

              // Primary Guardian Checkbox
              CheckboxListTile(
                value: _isPrimary,
                onChanged: (val) {
                  setState(() {
                    _isPrimary = val ?? false;
                  });
                },
                title: Text(
                  'Primary Guardian',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                subtitle: Text(
                  'They will receive immediate SOS alert calls and SMS.',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500),
                ),
                activeColor: AppTheme.primary,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
