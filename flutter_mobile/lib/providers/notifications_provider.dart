import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import '../services/notification_repository.dart';
import '../core/services/local_storage_service.dart';

class NotificationsProvider extends ChangeNotifier {
  NotificationsProvider({NotificationRepository? repository})
      : _repository = repository ?? NotificationRepository();

  final NotificationRepository _repository;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isOffline = false;
  bool _hasMore = true;
  int _currentPage = 1;
  int _serverUnreadCount = 0;

  String _selectedCategory = 'All';
  String _selectedSort = 'Newest';

  List<AppNotificationModel> _notifications = [];
  List<AppNotificationModel> _guardianNotifications = [];

  Timer? _pollingTimer;
  final Set<String> _knownNotificationIds = {};

  void Function(AppNotificationModel)? onNewEmergencyNotification;

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isOffline => _isOffline;
  bool get hasMore => _hasMore;
  int get currentPage => _currentPage;
  String get selectedCategory => _selectedCategory;
  String get selectedSort => _selectedSort;

  List<AppNotificationModel> get notifications => _notifications;
  List<AppNotificationModel> get guardianNotifications => _guardianNotifications;

  int get unreadCount => _serverUnreadCount > 0
      ? _serverUnreadCount
      : _notifications.where((n) => !n.isRead).length;

  Future<void> load({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
    }

    if (_currentPage == 1) {
      _setLoading(true);
    } else {
      _isLoadingMore = true;
      notifyListeners();
    }

    try {
      final res = await _repository.fetchNotifications(
        page: _currentPage,
        category: _selectedCategory,
        sortBy: _getSortQuery(),
      );

      final fetchedList = res['notifications'] as List<AppNotificationModel>;
      _hasMore = res['hasMore'] as bool? ?? false;

      if (_currentPage == 1) {
        _notifications = fetchedList;
      } else {
        _notifications.addAll(fetchedList);
      }

      for (final n in _notifications) {
        _knownNotificationIds.add(n.id);
      }

      _isOffline = false;
      await fetchUnreadCount();
    } catch (e) {
      _isOffline = true;
    } finally {
      _setLoading(false);
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    _currentPage++;
    await load();
  }

  Future<void> refresh() => load(refresh: true);

  void setCategoryFilter(String category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    load(refresh: true);
  }

  void setSortOption(String sort) {
    if (_selectedSort == sort) return;
    _selectedSort = sort;
    load(refresh: true);
  }

  String _getSortQuery() {
    switch (_selectedSort) {
      case 'Priority':
        return 'priority';
      case 'Unread':
        return 'unread';
      case 'Newest':
      default:
        return '-created_at';
    }
  }

  Future<void> fetchUnreadCount() async {
    try {
      _serverUnreadCount = await _repository.fetchUnreadCount();
      notifyListeners();
    } catch (_) {}
  }

  // ── Polling & Real-time Auto Refresh ────────────────────────────────────

  void startGuardianPolling() => startRealtimePolling();
  void stopGuardianPolling() => stopRealtimePolling();
  Future<void> pollGuardianNotifications() => pollNotifications();
  Future<void> loadCachedGuardianNotifications() async {}


  void startRealtimePolling() {

    _pollingTimer?.cancel();
    pollNotifications();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await pollNotifications();
    });
  }

  void stopRealtimePolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> pollNotifications() async {
    try {
      final res = await _repository.fetchNotifications(page: 1, category: _selectedCategory, sortBy: _getSortQuery());
      final list = res['notifications'] as List<AppNotificationModel>;

      AppNotificationModel? newEmergencyAlert;

      for (final notif in list) {
        if (!_knownNotificationIds.contains(notif.id)) {
          _knownNotificationIds.add(notif.id);
          if (!notif.isRead && (notif.priority == 'HIGH' || notif.priority == 'CRITICAL' || notif.category.toLowerCase() == 'sos' || notif.category.toLowerCase() == 'emergency')) {
            newEmergencyAlert = notif;
          }
        }
      }

      _notifications = list;
      await fetchUnreadCount();
      notifyListeners();

      if (newEmergencyAlert != null && onNewEmergencyNotification != null) {
        onNewEmergencyNotification!(newEmergencyAlert);
      }
    } catch (e) {
      debugPrint('Error polling notifications: $e');
    }
  }

  // ── Multi-select & Batch Actions ───────────────────────────────────────

  Future<void> markAsRead(String id) async {
    await _repository.markAsRead(id);
    _notifications = _notifications.map((n) {
      if (n.id == id) {
        return AppNotificationModel(
          id: n.id,
          title: n.title,
          message: n.message,
          category: n.category,
          isRead: true,
          createdAt: n.createdAt,
          priority: n.priority,
          location: n.location,
          incidentId: n.incidentId,
          residentName: n.residentName,
          emergencyCategory: n.emergencyCategory,
          incidentMessage: n.incidentMessage,
          incidentStatus: n.incidentStatus,
          latitude: n.latitude,
          longitude: n.longitude,
          address: n.address,
        );
      }
      return n;
    }).toList();
    if (_serverUnreadCount > 0) _serverUnreadCount--;
    notifyListeners();
  }

  Future<void> markAllAsRead() async {
    await _repository.markAllAsRead();
    _notifications = _notifications.map((n) {
      return AppNotificationModel(
        id: n.id,
        title: n.title,
        message: n.message,
        category: n.category,
        isRead: true,
        createdAt: n.createdAt,
        priority: n.priority,
        location: n.location,
        incidentId: n.incidentId,
        residentName: n.residentName,
        emergencyCategory: n.emergencyCategory,
        incidentMessage: n.incidentMessage,
        incidentStatus: n.incidentStatus,
        latitude: n.latitude,
        longitude: n.longitude,
        address: n.address,
      );
    }).toList();
    _serverUnreadCount = 0;
    notifyListeners();
  }

  Future<void> markMultipleRead(List<String> ids) async {
    if (ids.isEmpty) return;
    await _repository.markMultipleRead(ids);
    _notifications = _notifications.map((n) {
      if (ids.contains(n.id)) {
        return AppNotificationModel(
          id: n.id,
          title: n.title,
          message: n.message,
          category: n.category,
          isRead: true,
          createdAt: n.createdAt,
          priority: n.priority,
          location: n.location,
          incidentId: n.incidentId,
          residentName: n.residentName,
          emergencyCategory: n.emergencyCategory,
          incidentMessage: n.incidentMessage,
          incidentStatus: n.incidentStatus,
          latitude: n.latitude,
          longitude: n.longitude,
          address: n.address,
        );
      }
      return n;
    }).toList();
    fetchUnreadCount();
    notifyListeners();
  }

  Future<void> deleteNotification(String id) async {
    await _repository.deleteNotification(id);
    _notifications = _notifications.where((n) => n.id != id).toList();
    fetchUnreadCount();
    notifyListeners();
  }

  Future<void> deleteMultiple(List<String> ids) async {
    if (ids.isEmpty) return;
    await _repository.deleteMultiple(ids);
    _notifications = _notifications.where((n) => !ids.contains(n.id)).toList();
    fetchUnreadCount();
    notifyListeners();
  }

  Future<void> registerDeviceToken(String token) async {
    await _repository.registerDeviceToken(token);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    stopRealtimePolling();
    super.dispose();
  }
}
