import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' as import_services;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/api_client.dart';
import '../../core/services/local_storage_service.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../services/contacts_repository.dart';

import '../../core/widgets/section_header.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final value = await LocalStorageService.instance.getString(AppConstants.profileImagePathKey);
    if (mounted) {
      setState(() => _imagePath = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final resident = context.watch<AppStateProvider>().residentProfile;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Edit Profile',
            onPressed: () => _showEditProfileDialog(context, auth),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const SectionHeader(title: 'Resident profile', subtitle: 'Cached resident identity and contact summary'),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 44,
                    backgroundImage: _imagePath != null ? FileImage(File(_imagePath!)) : null,
                    child: _imagePath == null ? Text(auth.user?.fullName.isNotEmpty == true ? auth.user!.fullName[0].toUpperCase() : '?') : null,
                  ),
                ),
                const SizedBox(height: 16),
                Text(auth.user?.fullName ?? 'Resident', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(auth.user?.phoneNumber ?? ''),
                if (auth.user?.email.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(auth.user!.email, style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600, fontSize: 13)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              children: [
                _row('Society', resident?.societyName ?? 'Unavailable'),
                _row('Block', resident?.blockName ?? 'Unavailable'),
                _row('Flat', resident?.flatNumber ?? 'Unavailable'),
                _row('Status', resident?.status ?? 'Pending'),
                _row('Approved by', resident?.approvedByName.isNotEmpty == true ? resident!.approvedByName : 'Not approved yet'),
                const Divider(color: Color(0xFF2E3D52)),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.language_rounded, color: AppTheme.primaryTeal),
                  title: const Text('Language Preference', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Selected: ${auth.languageCode.toUpperCase()}', style: const TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.bold, fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppTheme.textSecondary),
                  onTap: () => context.push('/language'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _GuardianCodeSection(),
        ],
      ),
    );
  }


  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(width: 12),
          Flexible(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image == null) return;
    await LocalStorageService.instance.saveString(AppConstants.profileImagePathKey, image.path);
    if (mounted) {
      setState(() => _imagePath = image.path);
    }
  }

  void _showEditProfileDialog(BuildContext context, AuthProvider auth) {
    final nameController = TextEditingController(text: auth.user?.fullName);
    final phoneController = TextEditingController(text: auth.user?.phoneNumber);
    final emailController = TextEditingController(text: auth.user?.email);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Profile Details'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  validator: (val) => val == null || val.isEmpty ? 'Enter full name' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                  validator: (val) => val == null || val.isEmpty ? 'Enter phone number' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email Address'),
                  validator: (val) => val == null || val.isEmpty ? 'Enter email address' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final success = await auth.updateProfile(
                  name: nameController.text.trim(),
                  email: emailController.text.trim(),
                  phoneNumber: phoneController.text.trim(),
                );
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Profile saved successfully!' : 'Failed to save profile.'),
                    backgroundColor: success ? AppTheme.success : AppTheme.danger,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _GuardianCodeSection extends StatefulWidget {
  const _GuardianCodeSection();

  @override
  State<_GuardianCodeSection> createState() => _GuardianCodeSectionState();
}

class _GuardianCodeSectionState extends State<_GuardianCodeSection> {
  String? _guardianCode;
  List<dynamic> _linkedResidents = [];
  List<dynamic> _pendingRequests = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchGuardianCodeInfo();
  }

  Future<void> _fetchGuardianCodeInfo() async {
    setState(() => _isLoading = true);
    try {
      final repo = ContactsRepository();
      final res = await repo.fetchMyGuardianCode();
      if (mounted) {
        setState(() {
          _guardianCode = res['guardian_code'] as String?;
          _linkedResidents = (res['linked_residents'] as List?) ?? [];
          _pendingRequests = (res['pending_requests'] as List?) ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error fetching guardian code info: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _respondLink(int linkId, String action) async {
    try {
      final repo = ContactsRepository();
      final res = await repo.respondGuardianLink(linkId: linkId, action: action);
      final msg = res['message'] as String? ?? (action == 'accept' ? 'Guardian connected successfully.' : 'Guardian request rejected.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: action == 'accept' ? AppTheme.success : AppTheme.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await _fetchGuardianCodeInfo();
    } catch (e) {
      if (mounted) {
        final errText = ApiClient.extractErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errText),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }


  void _copyCode() {
    if (_guardianCode != null && _guardianCode!.isNotEmpty) {
      import_services.Clipboard.setData(import_services.ClipboardData(text: _guardianCode!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guardian Code copied to clipboard!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('My Guardian Code', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: _fetchGuardianCodeInfo,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.blue.withOpacity(0.15) : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_rounded, color: AppTheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _guardianCode ?? 'CC-GD-XXXXXX',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: isDark ? Colors.white : Colors.blue.shade900,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _copyCode,
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            if (_pendingRequests.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Pending Link Requests', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800, fontSize: 13)),
              const SizedBox(height: 8),
              ..._pendingRequests.map((req) {
                final linkId = req['id'] as int;
                final resName = req['resident_name'] ?? 'Resident';
                final rel = req['relationship_name'] ?? 'Guardian';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(resName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('Wants to link as $rel', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
                        onPressed: () => _respondLink(linkId, 'accept'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel_rounded, color: Colors.red),
                        onPressed: () => _respondLink(linkId, 'reject'),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 16),
            Text('Residents Linked', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white70 : Colors.grey.shade700)),
            const SizedBox(height: 8),
            if (_linkedResidents.isEmpty)
              const Text('No residents linked yet.', style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic))
            else
              Column(
                children: _linkedResidents.map((item) {
                  final resName = item['resident_name'] ?? 'Resident';
                  final rel = item['relationship_name'] ?? 'Guardian';
                  final isPrimary = item['is_primary'] == true;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        const Icon(Icons.person_pin_rounded, size: 18, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text('$resName ($rel)', style: const TextStyle(fontWeight: FontWeight.w600))),
                        if (isPrimary)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(8)),
                            child: const Text('Primary', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ],
      ),
    );
  }
}

