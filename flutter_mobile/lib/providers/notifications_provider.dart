import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import '../services/notification_repository.dart';
import '../core/services/local_storage_service.dart';

class NotificationsProvider extends ChangeNotifier {
  NotificationsProvider({NotificationRepository? repository}) : _repository = repository ?? NotificationRepository();

  final NotificationRepository _repository;

  bool _isLoading = false;
  bool _isOffline = false;
  List<AppNotificationModel> _notifications = const [];
  List<AppNotificationModel> _guardianNotifications = const [];

  Timer? _pollingTimer;
  final Set<String> _knownNotificationIds = {};

  void Function(AppNotificationModel)? onNewEmergencyNotification;

  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  List<AppNotificationModel> get notifications => _notifications;
  List<AppNotificationModel> get guardianNotifications => _guardianNotifications;
  
  int get unreadCount =>
      _notifications.where((notification) => !notification.isRead).length +
      _guardianNotifications.where((notification) => !notification.isRead).length;

  Future<void> load() async {
    _setLoading(true);
    try {
      _notifications = await _repository.fetchNotifications();
      _isOffline = false;
    } catch (_) {
      _isOffline = true;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refresh() => load();

  // ── Guardian Notification Polling ────────────────────────────────────────

  void startGuardianPolling() {
    _pollingTimer?.cancel();
    // Fetch once immediately
    pollGuardianNotifications();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      await pollGuardianNotifications();
    });
  }

  void stopGuardianPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> pollGuardianNotifications() async {
    try {
      final list = await _repository.fetchGuardianNotifications();
      AppNotificationModel? newEmergency;

    for (final notif in list) {
      if (!_knownNotificationIds.contains(notif.id)) {
        _knownNotificationIds.add(notif.id);
        if (!notif.isRead && (notif.priority == 'HIGH' || notif.category.toLowerCase() == 'sos')) {
          newEmergency = notif;
        }
      }
    }

    _guardianNotifications = list;
    await _cacheGuardianNotifications(list);
    notifyListeners();

    if (newEmergency != null && onNewEmergencyNotification != null) {
      onNewEmergencyNotification!(newEmergency);
    }
    } catch (e) {
      debugPrint('Error polling guardian notifications: $e');
    }
  }

  Future<void> loadCachedGuardianNotifications() async {
    final raw = await LocalStorageService.instance.getString('careconnect_guardian_notifications');
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _guardianNotifications = decoded
            .map((item) => AppNotificationModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
        for (final notif in _guardianNotifications) {
          _knownNotificationIds.add(notif.id);
        }
        notifyListeners();
      } catch (_) {}
    }
  }

  Future<void> _cacheGuardianNotifications(List<AppNotificationModel> list) async {
    final jsonString = jsonEncode(list.map((item) => item.toJson()).toList());
    await LocalStorageService.instance.saveString('careconnect_guardian_notifications', jsonString);
  }

  // ─────────────────────────────────────────────────────────────────────────

  Future<void> markAllAsRead() async {
    await _repository.markAllAsRead();
    _notifications = _notifications
        .map(
          (item) => AppNotificationModel(
            id: item.id,
            title: item.title,
            message: item.message,
            category: item.category,
            isRead: true,
            createdAt: item.createdAt,
            priority: item.priority,
            location: item.location,
            incidentId: item.incidentId,
            residentName: item.residentName,
            emergencyCategory: item.emergencyCategory,
            incidentMessage: item.incidentMessage,
            incidentStatus: item.incidentStatus,
          ),
        )
        .toList();
    notifyListeners();
  }

  Future<void> markAsRead(String id) async {
    await _repository.markAsRead(id);
    
    // Check main notifications
    _notifications = _notifications
        .map(
          (item) => item.id == id
              ? AppNotificationModel(
                  id: item.id,
                  title: item.title,
                  message: item.message,
                  category: item.category,
                  isRead: true,
                  createdAt: item.createdAt,
                  priority: item.priority,
                  location: item.location,
                  incidentId: item.incidentId,
                  residentName: item.residentName,
                  emergencyCategory: item.emergencyCategory,
                  incidentMessage: item.incidentMessage,
                  incidentStatus: item.incidentStatus,
                )
              : item,
        )
        .toList();

    // Check guardian notifications
    _guardianNotifications = _guardianNotifications
        .map(
          (item) => item.id == id
              ? AppNotificationModel(
                  id: item.id,
                  title: item.title,
                  message: item.message,
                  category: item.category,
                  isRead: true,
                  createdAt: item.createdAt,
                  priority: item.priority,
                  location: item.location,
                  incidentId: item.incidentId,
                  residentName: item.residentName,
                  emergencyCategory: item.emergencyCategory,
                  incidentMessage: item.incidentMessage,
                  incidentStatus: item.incidentStatus,
                )
              : item,
        )
        .toList();

    notifyListeners();
  }

  Future<void> deleteNotification(String id) async {
    await _repository.deleteNotification(id);
    _notifications = _notifications.where((item) => item.id != id).toList();
    _guardianNotifications = _guardianNotifications.where((item) => item.id != id).toList();
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    stopGuardianPolling();
    super.dispose();
  }
}
