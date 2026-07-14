class AppNotificationModel {
  AppNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.isRead,
    required this.createdAt,
    this.priority = 'LOW',
    this.location = '',
    this.incidentId = 0,
    this.residentName = '',
    this.emergencyCategory = '',
    this.incidentMessage = '',
    this.incidentStatus = '',
  });

  final String id;
  final String title;
  final String message;
  final String category;
  final bool isRead;
  final DateTime createdAt;
  final String priority;
  final String location;
  final int incidentId;
  final String residentName;
  final String emergencyCategory;
  final String incidentMessage;
  final String incidentStatus;

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    final incidentDetails = json['incident_details'] as Map<String, dynamic>?;
    return AppNotificationModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      category: json['category']?.toString() ?? 'general',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      priority: json['priority']?.toString() ?? 'LOW',
      location: json['location']?.toString() ?? '',
      incidentId: (json['incident'] as num?)?.toInt() ?? 0,
      residentName: incidentDetails?['resident_name']?.toString() ?? '',
      emergencyCategory: incidentDetails?['category_name']?.toString() ?? '',
      incidentMessage: incidentDetails?['message']?.toString() ?? '',
      incidentStatus: incidentDetails?['status']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'category': category,
        'is_read': isRead,
        'created_at': createdAt.toIso8601String(),
        'priority': priority,
        'location': location,
        'incident': incidentId,
        'incident_details': incidentId > 0
            ? {
                'resident_name': residentName,
                'category_name': emergencyCategory,
                'message': incidentMessage,
                'status': incidentStatus,
              }
            : null,
      };
}
