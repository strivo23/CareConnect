import 'dart:async';
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
  final String email;
  final bool isPrimary;
  final bool verified;
  final String verificationStatus;
  final String category; // 'Family', 'Friends', 'Neighbours', 'Other'

  LocalContact({
    required this.id,
    required this.name,
    required this.relationship,
    required this.phone,
    required this.email,
    required this.isPrimary,
    required this.verified,
    required this.verificationStatus,
    required this.category,
  });

  LocalContact copyWith({
    String? name,
    String? relationship,
    String? phone,
    String? email,
    bool? isPrimary,
    bool? verified,
    String? verificationStatus,
    String? category,
  }) {
    return LocalContact(
      id: id,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      isPrimary: isPrimary ?? this.isPrimary,
      verified: verified ?? this.verified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
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
        List<LocalContact> guardianContacts = [];
        try {
          final rgList = await _contactsRepository.fetchResidentGuardians();
          guardianContacts = rgList.map((rg) => LocalContact(
            id: 'rg_${rg['id']}',
            name: rg['guardian_name'] ?? 'Guardian',
            relationship: rg['relationship_name'] ?? 'Guardian',
            phone: rg['guardian_phone'] ?? '',
            email: rg['guardian_email'] ?? '',
            isPrimary: rg['is_primary'] == true,
            verified: rg['status'] == 'Active',
            verificationStatus: rg['status'] == 'Active' ? 'Verified' : 'Pending',
            category: 'Family',
          )).toList();
        } catch (_) {}

        final mappedContacts = list.map((c) => LocalContact(
          id: c.id.toString(),
          name: c.name,
          relationship: c.relationshipName,
          phone: c.phone,
          email: c.email ?? '',
          isPrimary: c.isPrimary,
          verified: c.verified,
          verificationStatus: c.verificationStatus,
          category: _mapCategory(c.relationshipName),
        )).toList();

        setState(() {
          _contacts = [...guardianContacts, ...mappedContacts];
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
          'email': contact.email,
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
        SnackBar(
          content: Text('Failed to add contact: ${e.toString().contains("primary") ? "A resident can only have one primary guardian." : "Invalid details."}'),
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
          'email': contact.email,
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
        SnackBar(
          content: Text('Failed to update contact: ${e.toString().contains("primary") ? "A resident can only have one primary guardian." : "Invalid details."}'),
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

  // Show Link Guardian Form
  void _showLinkGuardianForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _LinkGuardianSheet(
          onSubmit: (code, relationship, isPrimary) async {
            final messenger = ScaffoldMessenger.of(context);
            final navigator = Navigator.of(context);
            try {
              await _contactsRepository.linkGuardian(
                guardianCode: code,
                relationship: relationship,
                isPrimary: isPrimary,
              );
              navigator.pop();
              await _loadContactsFromBackend();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Guardian link request sent! Awaiting guardian approval.'),
                  backgroundColor: AppTheme.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } catch (e) {
              String msg = 'Failed to connect guardian. Please verify code.';
              final errStr = e.toString();
              if (errStr.contains('Invalid Guardian Code')) {
                msg = 'Invalid Guardian Code. Please check code and try again.';
              } else if (errStr.contains('already linked')) {
                msg = 'This guardian is already linked or request is pending.';
              } else if (errStr.contains('yourself')) {
                msg = 'You cannot link yourself as a guardian.';
              }
              messenger.showSnackBar(
                SnackBar(
                  content: Text(msg),
                  backgroundColor: AppTheme.danger,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },

        );
      },
    );
  }



  // Show Bottom Sheet for Add/Edit Form
  void _showContactForm({LocalContact? existing}) {
    if (existing == null) {
      _showLinkGuardianForm();
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ContactFormSheet(
          existing: existing,
          onSubmit: (contact) {
            _editContactBackend(contact);
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
              if (contact.id.startsWith('rg_')) {
                final rgId = int.parse(contact.id.replaceFirst('rg_', ''));
                _contactsRepository.unlinkGuardian(rgId).then((_) => _loadContactsFromBackend());
              } else {
                _deleteContactBackend(contact);
              }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111418) : Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: Theme.of(context).colorScheme.onSurface, size: 20),
                onPressed: () => Navigator.maybePop(context),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Emergency Contacts',
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Manage your trusted emergency contacts.',
              style: GoogleFonts.inter(
                color: isDark ? Colors.white60 : Colors.grey.shade600,
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
              onPressed: () => _showLinkGuardianForm(),
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
        onPressed: () => _showLinkGuardianForm(),
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
                      bgColor: isDark ? const Color(0xFF0F2E1E) : Colors.green.shade50,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
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
                  style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search contacts...',
                    hintStyle: GoogleFonts.inter(color: isDark ? Colors.white38 : Colors.grey.shade400, fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.white38 : Colors.grey.shade400),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded, color: isDark ? Colors.white60 : Colors.grey.shade600),
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
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        labelStyle: GoogleFonts.inter(
                          color: isSelected ? AppTheme.primary : (isDark ? Colors.white60 : Colors.grey.shade700),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? AppTheme.primary.withValues(alpha: 0.3) : (isDark ? Colors.white10 : Colors.grey.shade200),
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
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (filtered.isNotEmpty)
                    Text(
                      '${filtered.length} found',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.grey.shade500,
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
                  color: Theme.of(context).colorScheme.onSurface,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
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
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.grey.shade500,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
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
                  backgroundColor: contact.isPrimary ? AppTheme.primarySoft : (isDark ? const Color(0xFF1E293B) : Colors.blue.shade50),
                  child: Text(
                    initials,
                    style: GoogleFonts.outfit(
                      color: contact.isPrimary ? AppTheme.primary : (isDark ? Colors.blue.shade300 : Colors.blue.shade700),
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
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (contact.isPrimary)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F2E1E) : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'PRIMARY',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFF4ADE80) : Colors.green.shade700,
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
                              color: isDark ? Colors.white10 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              contact.relationship,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white60 : Colors.grey.shade600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Verification Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: contact.verified
                                  ? (isDark ? const Color(0xFF0F2E1E) : Colors.green.shade50)
                                  : (isDark ? const Color(0xFF3B250F) : Colors.orange.shade50),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  contact.verified ? Icons.check_circle_rounded : Icons.pending_rounded,
                                  size: 10,
                                  color: contact.verified
                                      ? (isDark ? const Color(0xFF4ADE80) : Colors.green.shade700)
                                      : (isDark ? const Color(0xFFFBBF24) : Colors.orange.shade700),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  contact.verified ? 'Verified' : 'Unverified',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: contact.verified
                                        ? (isDark ? const Color(0xFF4ADE80) : Colors.green.shade700)
                                        : (isDark ? const Color(0xFFFBBF24) : Colors.orange.shade700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${contact.phone} • ${contact.email}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.grey.shade500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Action buttons (Verify, Edit & Delete)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!contact.verified) ...[
                      IconButton(
                        icon: const Icon(Icons.verified_user_rounded, color: Colors.orangeAccent, size: 20),
                        onPressed: () => _openContactVerificationDialog(contact),
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF3B250F) : Colors.orange.shade50.withValues(alpha: 0.5),
                          padding: const EdgeInsets.all(8),
                        ),
                        tooltip: 'Verify Contact',
                      ),
                      const SizedBox(width: 6),
                    ],
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 20),
                      onPressed: () => _showContactForm(existing: contact),
                      style: IconButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.blue.shade50.withValues(alpha: 0.5),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                      onPressed: () => _confirmDelete(contact),
                      style: IconButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF2E1112) : Colors.red.shade50.withValues(alpha: 0.5),
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

  void _openContactVerificationDialog(LocalContact contact) {
    // Automatically trigger OTP send on open
    final contactId = int.parse(contact.id);
    _contactsRepository.sendContactVerification(contactId: contactId).then((success) {
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Verification OTP code sent to ${contact.name}.'),
              backgroundColor: AppTheme.primary,
            ),
          );
        }
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: _ContactVerificationDialogBody(
            contact: contact,
            contactsRepository: _contactsRepository,
            onSuccess: () {
              _loadContactsFromBackend();
            },
          ),
        );
      },
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
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
                        color: Theme.of(context).colorScheme.onSurface,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 300),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
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
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add trusted family members or friends.\nThey will receive SOS alerts instantly.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.grey.shade500,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _showLinkGuardianForm(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Guardian'),
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
  late String _email;
  late bool _isPrimary;
  late String _category;

  final List<String> _categoryOptions = ['Family', 'Friends', 'Neighbours', 'Other'];

  @override
  void initState() {
    super.initState();
    _name = widget.existing?.name ?? '';
    _relationship = widget.existing?.relationship ?? '';
    _phone = widget.existing?.phone ?? '';
    _email = widget.existing?.email ?? '';
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
        email: _email,
        isPrimary: _isPrimary,
        verified: widget.existing?.verified ?? false,
        verificationStatus: widget.existing?.verificationStatus ?? 'Pending',
        category: _category,
      );
      Navigator.pop(context);
      widget.onSubmit(contact);
    }
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
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
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 20),

              // Full Name
              TextFormField(
                initialValue: _name,
                style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  labelStyle: GoogleFonts.inter(color: isDark ? Colors.white60 : Colors.grey.shade600),
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
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Category',
                        labelStyle: GoogleFonts.inter(color: isDark ? Colors.white60 : Colors.grey.shade600),
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
                      style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Relation',
                        hintText: 'e.g. Father, Friend',
                        labelStyle: GoogleFonts.inter(color: isDark ? Colors.white60 : Colors.grey.shade600),
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
                style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface),
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  labelStyle: GoogleFonts.inter(color: isDark ? Colors.white60 : Colors.grey.shade600),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Please enter a phone number' : null,
                onSaved: (val) => _phone = val!.trim(),
              ),
              const SizedBox(height: 16),

              // Email Address
              TextFormField(
                initialValue: _email,
                style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface),
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  labelStyle: GoogleFonts.inter(color: isDark ? Colors.white60 : Colors.grey.shade600),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixIcon: const Icon(Icons.mail_outline_rounded),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter an email';
                  if (!val.contains('@') || !val.contains('.')) return 'Please enter a valid email';
                  return null;
                },
                onSaved: (val) => _email = val!.trim(),
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
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                ),
                subtitle: Text(
                  'They will receive immediate SOS alert calls and SMS.',
                  style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey.shade500),
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

class _ContactVerificationDialogBody extends StatefulWidget {
  final LocalContact contact;
  final ContactsRepository contactsRepository;
  final VoidCallback onSuccess;

  const _ContactVerificationDialogBody({
    required this.contact,
    required this.contactsRepository,
    required this.onSuccess,
  });

  @override
  State<_ContactVerificationDialogBody> createState() => _ContactVerificationDialogBodyState();
}

class _ContactVerificationDialogBodyState extends State<_ContactVerificationDialogBody> {
  final _otpController = TextEditingController();
  int _secondsRemaining = 60;
  Timer? _timer;
  bool _canResend = false;
  bool _isVerifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 60;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        setState(() {
          _canResend = true;
          _timer?.cancel();
        });
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  Future<void> _resendOTP() async {
    if (!_canResend) return;
    setState(() {
      _error = null;
    });
    final success = await widget.contactsRepository.resendContactVerification(
      contactId: int.parse(widget.contact.id),
    );
    if (success) {
      _startTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP code resent successfully.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } else {
      setState(() {
        _error = 'Failed to resend code.';
      });
    }
  }

  Future<void> _verify() async {
    final otp = _otpController.text.trim();
    if (otp.length < 6) {
      setState(() {
        _error = 'Please enter a 6-digit code.';
      });
      return;
    }
    setState(() {
      _isVerifying = true;
      _error = null;
    });
    try {
      final success = await widget.contactsRepository.verifyContactOTP(
        contactId: int.parse(widget.contact.id),
        otp: otp,
      );
      if (success) {
        widget.onSuccess();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.contact.name} verified successfully!'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } else {
        setState(() {
          _error = 'Invalid OTP. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Verification failed. Try again.';
      });
    } finally {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Verify Contact',
            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Enter the 6-digit OTP code sent to verify ${widget.contact.name}.',
            style: GoogleFonts.inter(color: isDark ? Colors.white60 : Colors.grey.shade600, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8, color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              hintText: '000000',
              hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.grey.shade300, letterSpacing: 8),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: GoogleFonts.inter(color: AppTheme.danger, fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Didn't receive code? ", style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey.shade600)),
              _canResend
                  ? GestureDetector(
                      onTap: _resendOTP,
                      child: Text('Resend', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                    )
                  : Text('Resend in ${_secondsRemaining}s', style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey.shade600, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isVerifying
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Verify', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LinkGuardianSheet extends StatefulWidget {
  final Future<void> Function(String code, String relationship, bool isPrimary) onSubmit;

  const _LinkGuardianSheet({required this.onSubmit});

  @override
  State<_LinkGuardianSheet> createState() => _LinkGuardianSheetState();
}

class _LinkGuardianSheetState extends State<_LinkGuardianSheet> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  String _relationship = 'Father';
  bool _isPrimary = false;
  bool _isConnecting = false;

  final List<String> _relationships = [
    'Father',
    'Mother',
    'Spouse',
    'Child',
    'Brother',
    'Sister',
    'Friend',
    'Neighbour',
    'Other'
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
              Center(
                child: Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Connect Guardian',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the unique Guardian Code (e.g. CC-GD-8F3K92) to establish a link.',
                style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white60 : Colors.grey.shade600),
              ),
              const SizedBox(height: 20),

              // Guardian Code
              TextFormField(
                controller: _codeController,
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Guardian Code',
                  hintText: 'CC-GD-XXXXXX',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixIcon: const Icon(Icons.verified_user_outlined),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter Guardian Code' : null,
              ),
              const SizedBox(height: 16),

              // Relationship Dropdown
              DropdownButtonFormField<String>(
                value: _relationship,
                dropdownColor: Theme.of(context).colorScheme.surface,
                style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Relationship',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixIcon: const Icon(Icons.people_outline_rounded),
                ),
                items: _relationships.map((rel) => DropdownMenuItem(value: rel, child: Text(rel))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _relationship = val);
                },
              ),
              const SizedBox(height: 16),

              // Primary Guardian Checkbox
              CheckboxListTile(
                value: _isPrimary,
                onChanged: (val) => setState(() => _isPrimary = val ?? false),
                title: Text(
                  'Primary Guardian',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                ),
                subtitle: Text(
                  'Primary guardian receives immediate high-priority SOS emergency escalation.',
                  style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey.shade500),
                ),
                activeColor: AppTheme.primary,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 24),

              // Connect Guardian Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isConnecting
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            setState(() => _isConnecting = true);
                            await widget.onSubmit(_codeController.text.trim(), _relationship, _isPrimary);
                            if (mounted) setState(() => _isConnecting = false);
                          }
                        },
                  icon: _isConnecting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.link_rounded),
                  label: Text(_isConnecting ? 'Connecting...' : 'Connect Guardian', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
