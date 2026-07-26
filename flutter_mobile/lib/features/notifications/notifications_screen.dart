import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/notification_model.dart';
import '../../providers/notifications_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();

  bool _isMultiSelectMode = false;
  final Set<String> _selectedNotificationIds = {};

  final List<String> _categories = [
    'All',
    'Emergency',
    'Guardian',
    'Volunteer',
    'Security',
    'Announcements',
  ];

  final List<String> _sortOptions = [
    'Newest',
    'Priority',
    'Unread',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<NotificationsProvider>();
      provider.load(refresh: true);
      provider.startRealtimePolling();

      provider.onNewEmergencyNotification = (newAlert) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New Emergency Alert Received',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        newAlert.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'VIEW',
              textColor: Colors.yellowAccent,
              onPressed: () {
                if (newAlert.incidentId > 0) {
                  context.push('/sos-message', extra: {'incidentId': newAlert.incidentId});
                }
              },
            ),
          ),
        );
      };
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<NotificationsProvider>().loadMore();
    }
  }

  void _toggleSelectNotification(String id) {
    setState(() {
      if (_selectedNotificationIds.contains(id)) {
        _selectedNotificationIds.remove(id);
        if (_selectedNotificationIds.isEmpty) {
          _isMultiSelectMode = false;
        }
      } else {
        _selectedNotificationIds.add(id);
      }
    });
  }

  void _exitMultiSelect() {
    setState(() {
      _isMultiSelectMode = false;
      _selectedNotificationIds.clear();
    });
  }

  Future<void> _handleBatchDelete() async {
    if (_selectedNotificationIds.isEmpty) return;
    final ids = _selectedNotificationIds.toList();
    _exitMultiSelect();
    await context.read<NotificationsProvider>().deleteMultiple(ids);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${ids.length} notifications deleted')),
      );
    }
  }

  Future<void> _handleBatchMarkRead() async {
    if (_selectedNotificationIds.isEmpty) return;
    final ids = _selectedNotificationIds.toList();
    _exitMultiSelect();
    await context.read<NotificationsProvider>().markMultipleRead(ids);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${ids.length} notifications marked read')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: _isMultiSelectMode
            ? Text(
                '${_selectedNotificationIds.length} Selected',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              )
            : Row(
                children: [
                  Text(
                    'Notification Center',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                  if (provider.unreadCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${provider.unreadCount}',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
        actions: [
          if (_isMultiSelectMode) ...[
            IconButton(
              icon: const Icon(Icons.mark_email_read_outlined),
              tooltip: 'Mark Selected Read',
              onPressed: _handleBatchMarkRead,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete Selected',
              onPressed: _handleBatchDelete,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _exitMultiSelect,
            ),
          ] else ...[
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort_rounded),
              tooltip: 'Sort Notifications',
              onSelected: (sort) => provider.setSortOption(sort),
              itemBuilder: (context) => _sortOptions.map((s) {
                final isSelected = provider.selectedSort == s;
                return PopupMenuItem<String>(
                  value: s,
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        size: 18,
                        color: isSelected ? AppTheme.primary : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text('Sort by $s'),
                    ],
                  ),
                );
              }).toList(),
            ),
            IconButton(
              icon: const Icon(Icons.done_all_rounded),
              tooltip: 'Mark All Read',
              onPressed: () async {
                await provider.markAllAsRead();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All notifications marked as read')),
                  );
                }
              },
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = provider.selectedCategory.toLowerCase() == cat.toLowerCase();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: AppTheme.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => provider.setCategoryFilter(cat),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),

          // Main List View
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => provider.refresh(),
              child: provider.isLoading && provider.notifications.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : provider.notifications.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.notifications_none_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                'No notifications found',
                                style: GoogleFonts.inter(fontSize: 16, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(12),
                          itemCount: provider.notifications.length + (provider.isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == provider.notifications.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              );
                            }

                            final notif = provider.notifications[index];
                            final isSelected = _selectedNotificationIds.contains(notif.id);

                            return Dismissible(
                              key: Key(notif.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade600,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Icon(Icons.delete_forever, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              onDismissed: (_) async {
                                await provider.deleteNotification(notif.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Notification deleted')),
                                  );
                                }
                              },
                              child: Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: isSelected
                                      ? const BorderSide(color: AppTheme.primary, width: 2)
                                      : BorderSide.none,
                                ),
                                color: notif.isRead
                                    ? (isDark ? Colors.grey.shade900 : Colors.white)
                                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF)),
                                elevation: notif.isRead ? 1 : 3,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onLongPress: () {
                                    setState(() {
                                      _isMultiSelectMode = true;
                                      _toggleSelectNotification(notif.id);
                                    });
                                  },
                                  onTap: () {
                                    if (_isMultiSelectMode) {
                                      _toggleSelectNotification(notif.id);
                                    } else {
                                      if (!notif.isRead) {
                                        provider.markAsRead(notif.id);
                                      }
                                      if (notif.incidentId > 0) {
                                        context.push('/sos-message', extra: {'incidentId': notif.incidentId});
                                      }
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (_isMultiSelectMode) ...[
                                          Checkbox(
                                            value: isSelected,
                                            onChanged: (_) => _toggleSelectNotification(notif.id),
                                          ),
                                          const SizedBox(width: 8),
                                        ],

                                        // Category Icon Container
                                        _buildCategoryIcon(notif.category, notif.priority),

                                        const SizedBox(width: 12),

                                        // Card Content
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      notif.title,
                                                      style: GoogleFonts.inter(
                                                        fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                                                        fontSize: 15,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  _buildPriorityBadge(notif.priority),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                notif.message,
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  color: isDark ? Colors.white70 : Colors.black87,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Icon(Icons.access_time, size: 12, color: Colors.grey.shade600),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    _formatTimestamp(notif.createdAt),
                                                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                                                  ),
                                                  if (notif.location.isNotEmpty) ...[
                                                    const SizedBox(width: 12),
                                                    Icon(Icons.location_on_outlined, size: 12, color: Colors.grey.shade600),
                                                    const SizedBox(width: 2),
                                                    Expanded(
                                                      child: Text(
                                                        notif.location,
                                                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildCategoryIcon(String category, String priority) {
    IconData iconData = Icons.notifications;
    Color color = Colors.blue;

    final catLower = category.toLowerCase();
    if (catLower == 'sos' || catLower == 'emergency' || priority == 'CRITICAL') {
      iconData = Icons.warning_amber_rounded;
      color = const Color(0xFFEF4444);
    } else if (catLower == 'guardian') {
      iconData = Icons.family_restroom;
      color = const Color(0xFF8B5CF6);
    } else if (catLower == 'security') {
      iconData = Icons.security;
      color = const Color(0xFF059669);
    } else if (catLower == 'volunteer') {
      iconData = Icons.volunteer_activism;
      color = const Color(0xFFD97706);
    } else if (catLower == 'announcements') {
      iconData = Icons.campaign;
      color = const Color(0xFF2563EB);
    }

    return CircleAvatar(
      radius: 20,
      backgroundColor: color.withOpacity(0.15),
      child: Icon(iconData, color: color, size: 22),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color bg = Colors.grey.shade200;
    Color fg = Colors.black87;

    switch (priority.toUpperCase()) {
      case 'CRITICAL':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        break;
      case 'HIGH':
        bg = const Color(0xFFFFEDD5);
        fg = const Color(0xFFEA580C);
        break;
      case 'MEDIUM':
        bg = const Color(0xFFFEF9C3);
        fg = const Color(0xFFCA8A04);
        break;
      case 'LOW':
      default:
        bg = const Color(0xFFE0E7FF);
        fg = const Color(0xFF4338CA);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        priority.toUpperCase(),
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
