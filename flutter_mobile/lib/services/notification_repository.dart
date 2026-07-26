import 'dart:convert';
import '../core/constants/app_constants.dart';
import '../core/services/api_client.dart';
import '../core/services/local_storage_service.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  NotificationRepository({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  /// Fetch paginated notifications (20 per page) with optional filtering and sorting.
  Future<Map<String, dynamic>> fetchNotifications({
    int page = 1,
    String? category,
    String? priority,
    String? sortBy,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page};
      if (category != null && category.isNotEmpty && category != 'All') {
        queryParams['category'] = category;
      }
      if (priority != null && priority.isNotEmpty) {
        queryParams['priority'] = priority;
      }
      if (sortBy != null && sortBy.isNotEmpty) {
        queryParams['ordering'] = sortBy;
      }

      final response = await _client.get('/api/notifications/', queryParameters: queryParams);
      final data = response.data;

      List<dynamic> items = [];
      bool hasMore = false;
      int count = 0;

      if (data is Map<String, dynamic>) {
        items = data['results'] as List<dynamic>? ?? [];
        hasMore = data['next'] != null;
        count = (data['count'] as num?)?.toInt() ?? items.length;
      } else if (data is List) {
        items = data;
      }

      final notifications = items
          .map((item) => AppNotificationModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();

      if (page == 1) {
        await _cache(notifications);
      }

      return {
        'notifications': notifications,
        'hasMore': hasMore,
        'count': count,
      };
    } catch (_) {
      final cached = await _readCache();
      return {
        'notifications': cached,
        'hasMore': false,
        'count': cached.length,
      };
    }
  }

  /// Lightweight endpoint to fetch unread count only.
  Future<int> fetchUnreadCount() async {
    try {
      final response = await _client.get('/api/notifications/count/');
      if (response.data is Map<String, dynamic>) {
        return (response.data['unread_count'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  Future<List<AppNotificationModel>> fetchGuardianNotifications() async {
    try {
      final response = await _client.get('/api/notifications/guardian/');
      final List items = response.data is List ? response.data as List : const [];
      return items.map((item) => AppNotificationModel.fromJson(Map<String, dynamic>.from(item as Map))).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _client.post('/api/notifications/read/$id/');
    } catch (_) {
      try {
        await _client.patch('/api/notifications/$id/read/');
      } catch (_) {}
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _client.post('/api/notifications/read-all/');
    } catch (_) {}
  }

  Future<void> markMultipleRead(List<String> ids) async {
    try {
      await _client.post('/api/notifications/mark-multiple-read/', data: {'ids': ids});
    } catch (_) {}
  }

  Future<void> deleteNotification(String id) async {
    try {
      await _client.delete('/api/notifications/$id/');
    } catch (_) {}
  }

  Future<void> deleteMultiple(List<String> ids) async {
    try {
      await _client.post('/api/notifications/delete-multiple/', data: {'ids': ids});
    } catch (_) {}
  }

  Future<void> registerDeviceToken(String token) async {
    try {
      await _client.post('/api/notifications/devices/', data: {'token': token});
    } catch (_) {}
  }

  Future<void> _cache(List<AppNotificationModel> notifications) async {
    final jsonString = jsonEncode(notifications.map((item) => item.toJson()).toList());
    await LocalStorageService.instance.saveString(AppConstants.apiNotificationsCacheKey, jsonString);
  }

  Future<List<AppNotificationModel>> _readCache() async {
    final raw = await LocalStorageService.instance.getString(AppConstants.apiNotificationsCacheKey);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((item) => AppNotificationModel.fromJson(Map<String, dynamic>.from(item as Map))).toList();
  }
}
