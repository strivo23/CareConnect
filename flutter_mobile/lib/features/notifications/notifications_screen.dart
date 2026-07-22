import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/notifications_provider.dart';

// Local data model for Notification Center
class LocalNotification {
  final String id;
  final String title;
  final String message;
  final String time;
  final String category; // 'Emergency', 'Security', 'Approval', 'Announcement', 'Maintenance', 'Visitor', 'SOS'
  final bool isRead;
  final String dateGroup; // 'Today', 'Yesterday', 'Older'

  LocalNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.category,
    required this.isRead,
    required this.dateGroup,
  });

  LocalNotification copyWith({
    String? title,
    String? message,
    String? time,
    String? category,
    bool? isRead,
    String? dateGroup,
  }) {
    return LocalNotification(
      id: id,
      title: title ?? this.title,
      message: message ?? this.message,
      time: time ?? this.time,
      category: category ?? this.category,
      isRead: isRead ?? this.isRead,
      dateGroup: dateGroup ?? this.dateGroup,
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<LocalNotification> _notifications = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotifications();
    });
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final provider = context.read<NotificationsProvider>();
      await provider.load();
      _syncFromProvider();
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _syncFromProvider() {
    final provider = context.read<NotificationsProvider>();
    setState(() {
      _notifications = provider.notifications.map((n) {
        return LocalNotification(
          id: n.id,
          title: n.title,
          message: n.message,
          time: _formatDate(n.createdAt),
          category: n.category,
          isRead: n.isRead,
          dateGroup: _getDateGroup(n.createdAt),
        );
      }).toList();
    });
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minutes ago';
    } else if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today, ${_pad(dt.hour)}:${_pad(dt.minute)}';
    } else if (dt.year == now.year && dt.month == now.month && dt.day == now.day - 1) {
      return 'Yesterday, ${_pad(dt.hour)}:${_pad(dt.minute)}';
    } else {
      return '${dt.day} ${_getMonthName(dt.month)}, ${_pad(dt.hour)}:${_pad(dt.minute)}';
    }
  }

  String _getDateGroup(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today';
    } else if (dt.year == now.year && dt.month == now.month && dt.day == now.day - 1) {
      return 'Yesterday';
    } else {
      return 'Older';
    }
  }

  String _pad(int v) => v.toString().padLeft(2, '0');

  String _getMonthName(int month) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[month - 1];
  }

  // Search and Filtering State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All',
    'Emergency',
    'Announcements',
    'Approvals',
    'Maintenance',
    'Security',
    'SOS',
    'Unread'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Filter & Search Logic
  List<LocalNotification> get _filteredNotifications {
    return _notifications.where((n) {
      // Filter Chip Match
      bool matchesFilter = true;
      if (_selectedFilter == 'Unread') {
        matchesFilter = !n.isRead;
      } else if (_selectedFilter == 'Emergency') {
        matchesFilter = n.category.toLowerCase() == 'emergency';
      } else if (_selectedFilter == 'Announcements') {
        matchesFilter = n.category.toLowerCase() == 'announcement' || n.category.toLowerCase() == 'announcements';
      } else if (_selectedFilter == 'Approvals') {
        matchesFilter = n.category.toLowerCase() == 'approval' || n.category.toLowerCase() == 'approvals';
      } else if (_selectedFilter == 'Maintenance') {
        matchesFilter = n.category.toLowerCase() == 'maintenance';
      } else if (_selectedFilter == 'Security') {
        matchesFilter = n.category.toLowerCase() == 'security';
      } else if (_selectedFilter == 'SOS') {
        matchesFilter = n.category.toLowerCase() == 'sos' || n.category.toLowerCase() == 'emergency';
      }

      // Search Match
      bool matchesSearch = n.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          n.message.toLowerCase().contains(_searchQuery.toLowerCase());

      return matchesFilter && matchesSearch;
    }).toList();
  }

  // Dynamic Statistics
  int get _unreadCount => _notifications.where((n) => !n.isRead).length;
  int get _todayCount => _notifications.where((n) => n.dateGroup == 'Today').length;
  int get _weekCount => _notifications.length;

  // Mark single notification as read
  Future<void> _markAsRead(LocalNotification notification) async {
    if (notification.isRead) return;
    await context.read<NotificationsProvider>().markAsRead(notification.id);
    _syncFromProvider();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${notification.title}" marked as read.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // Mark all notifications as read
  Future<void> _markAllRead() async {
    await context.read<NotificationsProvider>().markAllAsRead();
    _syncFromProvider();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All notifications marked as read.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  // Delete notification
  Future<void> _deleteNotification(LocalNotification notification) async {
    await context.read<NotificationsProvider>().deleteNotification(notification.id);
    _syncFromProvider();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Notification deleted.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.grey.shade900,
      ),
    );
  }

  // Resolve Icons for categories
  IconData _iconForCategory(String category) {
    switch (category) {
      case 'Emergency':
      case 'SOS':
        return Icons.emergency_rounded;
      case 'Security':
        return Icons.security_rounded;
      case 'Approval':
        return Icons.verified_rounded;
      case 'Announcement':
        return Icons.campaign_rounded;
      case 'Maintenance':
        return Icons.build_circle_rounded;
      case 'Visitor':
        return Icons.person_add_alt_1_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  // Resolve Colors for categories
  Color _colorForCategory(String category) {
    switch (category) {
      case 'Emergency':
      case 'SOS':
        return AppTheme.danger;
      case 'Security':
        return AppTheme.warning;
      case 'Approval':
        return AppTheme.success;
      case 'Announcement':
        return const Color(0xFF2563EB); // Primary blue color
      case 'Maintenance':
        return Colors.amber.shade700;
      case 'Visitor':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredNotifications;

    // Grouping by date
    final todayAlerts = filtered.where((n) => n.dateGroup == 'Today').toList();
    final yesterdayAlerts = filtered.where((n) => n.dateGroup == 'Yesterday').toList();
    final olderAlerts = filtered.where((n) => n.dateGroup == 'Older').toList();

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
              'Notifications',
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Stay updated with society activities and alerts.',
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
          IconButton(
            icon: const Icon(Icons.done_all_rounded, color: Color(0xFF2563EB)),
            tooltip: 'Mark All Read',
            onPressed: _markAllRead,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: IconButton(
              icon: Icon(Icons.filter_list_rounded, color: Theme.of(context).colorScheme.onSurface),
              tooltip: 'Filter Options',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Scroll category chips below to filter by alerts.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            const LinearProgressIndicator(color: Color(0xFF2563EB)),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadNotifications,
              color: const Color(0xFF2563EB),
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
                      title: 'Unread',
                      value: _unreadCount.toString(),
                      icon: Icons.mark_chat_unread_rounded,
                      color: AppTheme.danger,
                      bgColor: AppTheme.primarySoft,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Today',
                      value: _todayCount.toString(),
                      icon: Icons.today_rounded,
                      color: const Color(0xFF2563EB),
                      bgColor: isDark ? const Color(0xFF1E293B) : Colors.blue.shade50,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      title: 'This Week',
                      value: _weekCount.toString(),
                      icon: Icons.date_range_rounded,
                      color: Colors.purple,
                      bgColor: isDark ? const Color(0xFF2E1B3B) : Colors.purple.shade50,
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
                    hintText: 'Search notifications...',
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

              // Filter Chips
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  itemBuilder: (context, index) {
                    final item = _filters[index];
                    final isSelected = _selectedFilter == item;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(item),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedFilter = item;
                          });
                        },
                        selectedColor: isDark ? const Color(0xFF1E293B) : Colors.blue.shade50,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        labelStyle: GoogleFonts.inter(
                          color: isSelected ? const Color(0xFF2563EB) : (isDark ? Colors.white60 : Colors.grey.shade700),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFF2563EB).withValues(alpha: 0.3) : (isDark ? Colors.white10 : Colors.grey.shade200),
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

              // Grouped Notifications List
              if (filtered.isEmpty)
                _buildEmptyState()
              else ...[
                if (todayAlerts.isNotEmpty) ...[
                  _buildSectionHeader('TODAY'),
                  const SizedBox(height: 8),
                  ...todayAlerts.map((n) => _buildDismissibleCard(n)),
                  const SizedBox(height: 16),
                ],
                if (yesterdayAlerts.isNotEmpty) ...[
                  _buildSectionHeader('YESTERDAY'),
                  const SizedBox(height: 8),
                  ...yesterdayAlerts.map((n) => _buildDismissibleCard(n)),
                  const SizedBox(height: 16),
                ],
                if (olderAlerts.isNotEmpty) ...[
                  _buildSectionHeader('OLDER'),
                  const SizedBox(height: 8),
                  ...olderAlerts.map((n) => _buildDismissibleCard(n)),
                  const SizedBox(height: 16),
                ],
              ],
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
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              CircleAvatar(
                backgroundColor: bgColor,
                radius: 14,
                child: Icon(icon, color: color, size: 14),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: isDark ? Colors.white60 : Colors.grey.shade500,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Section Header
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.grey.shade400,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  // Swipe Action Dismissible Card Builder
  Widget _buildDismissibleCard(LocalNotification n) {
    return Dismissible(
      key: Key(n.id),
      // Left-to-right swipe (Green checkmark for "Mark Read")
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.success,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          children: [
            Icon(Icons.done_rounded, color: Colors.white),
            SizedBox(width: 10),
            Text('Mark Read', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      // Right-to-left swipe (Red bin for "Delete")
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.danger,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(width: 10),
            Icon(Icons.delete_outline_rounded, color: Colors.white),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _markAsRead(n);
          return false; // Do not dismiss (remove) from the list!
        } else {
          return true; // Dismiss (remove) from list
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          _deleteNotification(n);
        }
      },
      child: _buildNotificationCard(n),
    );
  }

  // Notification Card Item
  Widget _buildNotificationCard(LocalNotification n) {
    final catColor = _colorForCategory(n.category);
    final catIcon = _iconForCategory(n.category);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _markAsRead(n),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Unread blue dot indicator
                Padding(
                  padding: const EdgeInsets.only(top: 14.0, right: 10.0),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: n.isRead ? Colors.transparent : const Color(0xFF2563EB),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

                // Category Circle Icon
                CircleAvatar(
                  backgroundColor: catColor.withValues(alpha: 0.1),
                  radius: 20,
                  child: Icon(catIcon, color: catColor, size: 20),
                ),
                const SizedBox(width: 14),

                // Details Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              n.title,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          Text(
                            n.time,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: isDark ? Colors.white38 : Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        n.message,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Category Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          n.category.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: catColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Empty State Widget Builder
  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Notification bell illustration icon
            Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFF2563EB),
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Notifications Yet',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'ll receive emergency alerts, announcements, approvals and important society updates here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.grey.shade500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {});
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
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
    );
  }
}
