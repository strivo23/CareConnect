import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import '../services/notification_repository.dart';

class NotificationsProvider extends ChangeNotifier {
  NotificationsProvider({NotificationRepository? repository}) : _repository = repository ?? NotificationRepository();

  final NotificationRepository _repository;

  bool _isLoading = false;
  bool _isOffline = false;
  List<AppNotificationModel> _notifications = const [];

  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  List<AppNotificationModel> get notifications => _notifications;
  int get unreadCount => _notifications.where((notification) => !notification.isRead).length;

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
          ),
        )
        .toList();
    notifyListeners();
  }

  Future<void> markAsRead(String id) async {
    await _repository.markAsRead(id);
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
                )
              : item,
        )
        .toList();
    notifyListeners();
  }

  Future<void> deleteNotification(String id) async {
    await _repository.deleteNotification(id);
    _notifications = _notifications.where((item) => item.id != id).toList();
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
