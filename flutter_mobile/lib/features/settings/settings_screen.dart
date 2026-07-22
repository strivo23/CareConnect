import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_state_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Local Settings States
  bool _pushNotifications = true;
  bool _locationSharing = true;
  String _themeMode = 'System'; // 'System', 'Light', 'Dark'

  // Confirm logout dialog
  void _confirmLogout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: AppTheme.danger, size: 24),
            const SizedBox(width: 10),
            Text(
              'Logout',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out of CareConnect?',
          style: GoogleFonts.inter(
            height: 1.4,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final auth = context.read<AuthProvider>();
              final router = GoRouter.of(context);
              await auth.logout();
              router.go('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Logout',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // Confirm delete account dialog
  void _confirmDeleteAccount() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            const Icon(Icons.report_gmailerrorred_rounded, color: AppTheme.danger, size: 26),
            const SizedBox(width: 10),
            Text(
              'Delete Account',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: Text(
          'WARNING: This action is permanent and cannot be undone. All your profile details, emergency contacts, and logs will be permanently deleted from the society system.',
          style: GoogleFonts.inter(
            height: 1.4,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account deletion request submitted to Society Administrator.'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppTheme.danger,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Delete Permanently',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // Show Bottom Sheet for Language Picker
  Future<void> _showLanguagePicker() async {
    final auth = context.read<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 36,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Select Application Language',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              _buildLanguageTile(context, 'English', 'en', auth.languageCode),
              _buildLanguageTile(context, 'Hindi (हिंदी)', 'hi', auth.languageCode),
              _buildLanguageTile(context, 'Marathi (मराठी)', 'mr', auth.languageCode),
            ],
          ),
        ),
      ),
    );

    if (selected != null && mounted) {
      await auth.setLanguage(selected);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Language updated to ${selected.toUpperCase()}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  Widget _buildLanguageTile(BuildContext context, String title, String code, String activeCode) {
    final isActive = code == activeCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? AppTheme.primary : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
        trailing: isActive ? const Icon(Icons.check_circle_rounded, color: AppTheme.primary) : null,
        onTap: () => Navigator.pop(context, code),
      ),
    );
  }

  // Show Bottom Sheet for Theme Picker
  Future<void> _showThemePicker() async {
    final auth = context.read<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentMode = auth.themeModeString;
    final activeThemeModeLabel = currentMode == 'dark' ? 'Dark' : (currentMode == 'light' ? 'Light' : 'System');

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 36,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Select App Theme Mode',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              _buildThemeTile(context, 'System Default', 'System', activeThemeModeLabel),
              _buildThemeTile(context, 'Light Theme', 'Light', activeThemeModeLabel),
              _buildThemeTile(context, 'Dark Theme', 'Dark', activeThemeModeLabel),
            ],
          ),
        ),
      ),
    );

    if (selected != null && mounted) {
      if (selected == 'Dark') {
        await auth.setThemeMode('dark');
      } else if (selected == 'Light') {
        await auth.setThemeMode('light');
      } else {
        await auth.setThemeMode('system');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Theme Mode changed to $selected'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  Widget _buildThemeTile(BuildContext context, String title, String mode, String activeMode) {
    final isActive = mode == activeMode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? AppTheme.primary : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
        trailing: isActive ? const Icon(Icons.check_circle_rounded, color: AppTheme.primary) : null,
        onTap: () => Navigator.pop(context, mode),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final appState = context.watch<AppStateProvider>();
    final resident = appState.residentProfile;
    final user = auth.user;

    final currentMode = auth.themeModeString;
    final displayThemeMode = currentMode == 'dark' ? 'Dark' : (currentMode == 'light' ? 'Light' : 'System');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white10 : const Color(0xFFF1F5F9);

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
        title: Text(
          'Settings',
          style: GoogleFonts.outfit(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        titleSpacing: Navigator.canPop(context) ? 0 : 20,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 600));
          setState(() {});
        },
        color: AppTheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER CARD: PROFILE OVERVIEW
              _buildProfileHeader(context),
              const SizedBox(height: 20),

              // ACCOUNT SECTION
              _buildSectionTitle('ACCOUNT'),
              _buildGroupCard(
                children: [
                  _buildListTile(
                    icon: Icons.person_outline_rounded,
                    title: 'Profile',
                    subtitle: 'View and edit personal information',
                    onTap: () => context.go('/profile'),
                  ),
                  Divider(height: 1, color: dividerColor),
                  _buildListTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Change Password',
                    subtitle: 'Update your account password',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password change feature is handled via backend auth reset flow.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, color: dividerColor),
                  _buildListTile(
                    icon: Icons.phone_android_rounded,
                    title: 'Linked Mobile',
                    subtitle: user?.phoneNumber.isNotEmpty == true ? user!.phoneNumber : '—',
                    trailing: Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white38 : Colors.grey),
                    onTap: () => context.go('/profile'),
                  ),
                  Divider(height: 1, color: dividerColor),
                  _buildListTile(
                    icon: Icons.mail_outline_rounded,
                    title: 'Email',
                    subtitle: user?.email.isNotEmpty == true ? user!.email : '—',
                    trailing: Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white38 : Colors.grey),
                    onTap: () => context.go('/profile'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // APPLICATION SECTION
              _buildSectionTitle('APPLICATION'),
              _buildGroupCard(
                children: [
                  SwitchListTile.adaptive(
                    value: auth.useDarkTheme,
                    onChanged: (val) {
                      auth.toggleTheme(val);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(val ? 'Dark mode enabled' : 'Light mode enabled'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    secondary: Icon(Icons.dark_mode_outlined, color: isDark ? Colors.blue.shade300 : Colors.blueAccent),
                    title: Text('Dark Mode', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                    activeColor: AppTheme.primary,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  ),
                  Divider(height: 1, color: dividerColor),
                  _buildListTile(
                    icon: Icons.language_rounded,
                    title: 'Language',
                    subtitle: auth.languageCode == 'en'
                        ? 'English'
                        : auth.languageCode == 'hi'
                            ? 'Hindi (हिंदी)'
                            : 'Marathi (मराठी)',
                    onTap: _showLanguagePicker,
                  ),
                  Divider(height: 1, color: dividerColor),
                  SwitchListTile.adaptive(
                    value: _pushNotifications,
                    onChanged: (val) {
                      setState(() {
                        _pushNotifications = val;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(val ? 'Push notifications enabled' : 'Push notifications disabled'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    secondary: const Icon(Icons.notifications_active_outlined, color: Colors.teal),
                    title: Text('Notifications', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                    activeColor: AppTheme.primary,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  ),
                  Divider(height: 1, color: dividerColor),
                  _buildListTile(
                    icon: Icons.location_on_outlined,
                    title: 'Location Access',
                    subtitle: 'Always Allowed',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Manage precise system location permissions in App Info settings.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, color: dividerColor),
                  _buildListTile(
                    icon: Icons.palette_outlined,
                    title: 'Theme',
                    subtitle: displayThemeMode,
                    onTap: _showThemePicker,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // EMERGENCY SECTION
              _buildSectionTitle('EMERGENCY SETTINGS'),
              _buildGroupCard(
                children: [
                  _buildListTile(
                    icon: Icons.people_alt_outlined,
                    title: 'Emergency Contacts',
                    subtitle: 'Manage emergency contacts',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Select the Contacts tab in the bottom bar to manage guardians.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, color: dividerColor),
                  _buildListTile(
                    icon: Icons.sos_rounded,
                    title: 'SOS Settings',
                    subtitle: 'Configure emergency alert preferences',
                    onTap: () {},
                  ),
                  Divider(height: 1, color: dividerColor),
                  SwitchListTile.adaptive(
                    value: _locationSharing,
                    onChanged: (val) {
                      setState(() {
                        _locationSharing = val;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(val ? 'Automatic SOS live tracking enabled' : 'SOS live tracking disabled'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    secondary: const Icon(Icons.share_location_rounded, color: AppTheme.danger),
                    title: Text('Location Sharing', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('Automatically share live location during SOS', style: GoogleFonts.inter(fontSize: 11)),
                    activeColor: AppTheme.primary,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // SOCIETY INFORMATION
              _buildSectionTitle('SOCIETY INFORMATION'),
              _buildGroupCard(
                children: [
                  _buildListTile(
                    icon: Icons.apartment_rounded,
                    title: 'Society Details',
                    subtitle: resident?.societyName.isNotEmpty == true ? resident!.societyName : 'Not linked',
                    onTap: () => context.go('/society'),
                  ),
                  Divider(height: 1, color: dividerColor),
                  _buildListTile(
                    icon: Icons.meeting_room_outlined,
                    title: 'Block & Flat',
                    subtitle: (resident != null && (resident.blockName.isNotEmpty || resident.flatNumber.isNotEmpty))
                        ? '${resident.blockName}, ${resident.flatNumber}'
                        : 'Not assigned',
                    onTap: () {},
                  ),
                  Divider(height: 1, color: dividerColor),
                  _buildListTile(
                    icon: Icons.shield_outlined,
                    title: 'Security Contacts',
                    subtitle: 'Society Gate security numbers',
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // SUPPORT
              _buildSectionTitle('SUPPORT'),
              _buildGroupCard(
                children: [
                  _buildListTile(
                    icon: Icons.help_outline_rounded,
                    title: 'Help Center',
                    onTap: () {},
                  ),
                  Divider(height: 1, color: dividerColor),
                  _buildListTile(
                    icon: Icons.phone_in_talk_outlined,
                    title: 'Contact Support',
                    onTap: () {},
                  ),
                  Divider(height: 1, color: dividerColor),
                  _buildListTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    onTap: () {},
                  ),
                  Divider(height: 1, color: dividerColor),
                  _buildListTile(
                    icon: Icons.gavel_rounded,
                    title: 'Terms & Conditions',
                    onTap: () {},
                  ),
                  Divider(height: 1, color: dividerColor),
                  _buildListTile(
                    icon: Icons.info_outline_rounded,
                    title: 'About CareConnect',
                    subtitle: 'Version 1.0.0',
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ACCOUNT ACTIONS
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmLogout(context),
                      icon: const Icon(Icons.logout_rounded, color: AppTheme.danger, size: 20),
                      label: Text('Logout', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.danger,
                        side: const BorderSide(color: AppTheme.danger, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _confirmDeleteAccount,
                      icon: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 20),
                      label: Text('Delete Account', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.danger,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // BOTTOM INFORMATION
              Center(
                child: Column(
                  children: [
                    Text(
                      'CareConnect',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade400,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Version 1.0.0',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Made with ', style: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 11)),
                        const Icon(Icons.favorite_rounded, color: AppTheme.danger, size: 12),
                        Text(' for safer communities.', style: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // Profile Header Builder
  Widget _buildProfileHeader(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final appState = context.watch<AppStateProvider>();
    final user = auth.user;
    final resident = appState.residentProfile;

    final displayName = user?.fullName.isNotEmpty == true ? user!.fullName : (user?.email ?? 'Resident');
    final initials = displayName.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
    final societyLine = resident != null
        ? '${resident.societyName.isNotEmpty ? resident.societyName : 'Society'} • ${resident.flatNumber.isNotEmpty ? resident.flatNumber : 'Flat'}'.trim()
        : 'No society linked';
    final isVerified = resident?.status == 'Approved';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade100),
      ),
      child: Row(
        children: [
          // Circular Profile Pic with dynamic initials
          Hero(
            tag: 'profile-pic',
            child: CircleAvatar(
              radius: 34,
              backgroundColor: isDark ? Colors.blue.shade900 : Colors.blue.shade100,
              child: Text(
                initials.isNotEmpty ? initials : '?',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.blue.shade200 : const Color(0xFF2563EB),
                ),
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
                    Flexible(
                      child: Text(
                        displayName,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Verified / Pending badge
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isVerified ? AppTheme.success : Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isVerified ? Icons.check_rounded : Icons.hourglass_top_rounded,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  user?.role ?? 'Resident',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  societyLine,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Edit Profile Icon
          IconButton(
            icon: Icon(Icons.edit_note_rounded, color: isDark ? Colors.blue.shade300 : const Color(0xFF2563EB), size: 26),
            onPressed: () => context.go('/profile'),
            style: IconButton.styleFrom(
              backgroundColor: isDark ? Colors.blue.shade900.withValues(alpha: 0.3) : Colors.blue.shade50.withValues(alpha: 0.5),
              padding: const EdgeInsets.all(10),
            ),
          ),
        ],
      ),
    );
  }

  // Section Title
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 6.0, bottom: 8.0),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Colors.grey.shade400,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  // Rounded Card Container
  Widget _buildGroupCard({required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade100),
        ),
        child: Column(
          children: children,
        ),
      ),
    );
  }


  // List Tile item template
  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: isDark ? Colors.blue.shade300 : Colors.blue.shade700, size: 22),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: isDark ? Colors.white60 : Colors.grey.shade500,
                ),
              )
            : null,
        trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white38 : Colors.grey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        onTap: onTap,
      ),
    );

  }
}
