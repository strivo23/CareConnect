import 'dart:convert';

import '../core/constants/app_constants.dart';
import '../core/services/api_client.dart';
import '../core/services/local_storage_service.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  NotificationRepository({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  Future<List<AppNotificationModel>> fetchNotifications() async {
    try {
      final response = await _client.get('/api/notifications/');
      final data = response.data as Map<String, dynamic>?;
      final items = data?['results'] is List ? data!['results'] as List : response.data as List? ?? const [];
      final notifications = items.map((item) => AppNotificationModel.fromJson(Map<String, dynamic>.from(item as Map))).toList();
      await _cache(notifications);
      return notifications;
    } catch (_) {
      return _readCache();
    }
  }

  Future<List<AppNotificationModel>> fetchGuardianNotifications() async {
    try {
      final response = await _client.get('/api/notifications/guardian/');
      final List items = response.data is List ? response.data as List : const [];
      final notifications = items.map((item) => AppNotificationModel.fromJson(Map<String, dynamic>.from(item as Map))).toList();
      return notifications;
    } catch (_) {
      return const [];
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _client.patch('/api/notifications/$id/read/');
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    try {
      await _client.post('/api/notifications/mark-all-read/');
    } catch (_) {}
  }

  Future<void> deleteNotification(String id) async {
    try {
      await _client.delete('/api/notifications/$id/');
    } catch (_) {}
  }

  Future<void> registerDeviceToken(String token) async {
    try {
      await _client.post('/api/notifications/devices/', data: {'token': token});
    } catch (_) {}
  }

  Future<void> _cache(List<AppNotificationModel> notifications) async {
    final jsonString = jsonEncode(
      notifications.map((item) => item.toJson()).toList(),
    );
    await LocalStorageService.instance.saveString(AppConstants.apiNotificationsCacheKey, jsonString);
  }

  Future<List<AppNotificationModel>> _readCache() async {
    final raw = await LocalStorageService.instance.getString(AppConstants.apiNotificationsCacheKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((item) => AppNotificationModel.fromJson(Map<String, dynamic>.from(item as Map))).toList();
  }
}
