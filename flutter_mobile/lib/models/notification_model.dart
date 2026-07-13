class AppNotificationModel {
  AppNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String message;
  final String category;
  final bool isRead;
  final DateTime createdAt;

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    return AppNotificationModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      category: json['category']?.toString() ?? 'general',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
