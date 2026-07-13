import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/local_storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
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
                  Text(auth.user!.email, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
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
              ],
            ),
          ),
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
