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
    this.latitude,
    this.longitude,
    this.address = '',
    this.isSender = false,
    this.isAssignedGuardian = false,
    this.isAssignedVolunteer = false,
    this.isAssignedSecurity = false,
    this.canAccept = false,
    this.canDecline = false,
    this.canChat = false,
    this.canCall = false,
    this.canNavigate = false,
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
  final double? latitude;
  final double? longitude;
  final String address;
  final bool isSender;
  final bool isAssignedGuardian;
  final bool isAssignedVolunteer;
  final bool isAssignedSecurity;
  final bool canAccept;
  final bool canDecline;
  final bool canChat;
  final bool canCall;
  final bool canNavigate;

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? incidentDetails;
    int incId = 0;

    if (json['incident_details'] is Map) {
      incidentDetails = Map<String, dynamic>.from(json['incident_details'] as Map);
    }

    if (json['incident'] is Map) {
      final incMap = Map<String, dynamic>.from(json['incident'] as Map);
      incId = (incMap['id'] as num?)?.toInt() ?? 0;
      incidentDetails ??= incMap;
    } else if (json['incident'] is num) {
      incId = (json['incident'] as num).toInt();
    } else if (json['incident'] != null) {
      incId = int.tryParse(json['incident'].toString()) ?? 0;
    }

    double? lat;
    double? lng;
    String addr = '';

    if (incidentDetails != null) {
      if (incidentDetails['latitude'] != null) {
        lat = double.tryParse(incidentDetails['latitude'].toString());
      }
      if (incidentDetails['longitude'] != null) {
        lng = double.tryParse(incidentDetails['longitude'].toString());
      }
      addr = incidentDetails['resolved_address']?.toString() ?? incidentDetails['address']?.toString() ?? '';
    }

    if (lat == null || lng == null) {
      final locStr = json['location']?.toString() ?? '';
      if (locStr.isNotEmpty && locStr.contains(',')) {
        final parts = locStr.split(',');
        if (parts.length >= 2) {
          lat ??= double.tryParse(parts[0].trim());
          lng ??= double.tryParse(parts[1].trim());
        }
      }
    }

    final isSender = incidentDetails?['is_sender'] == true || json['is_sender'] == true;
    final isAssignedGuardian = incidentDetails?['is_assigned_guardian'] == true || json['is_assigned_guardian'] == true;
    final isAssignedVolunteer = incidentDetails?['is_assigned_volunteer'] == true || json['is_assigned_volunteer'] == true;
    final isAssignedSecurity = incidentDetails?['is_assigned_security'] == true || json['is_assigned_security'] == true;
    final canAccept = incidentDetails?['can_accept'] == true || json['can_accept'] == true;
    final canDecline = incidentDetails?['can_decline'] == true || json['can_decline'] == true;
    final canChat = incidentDetails?['can_chat'] == true || json['can_chat'] == true;
    final canCall = incidentDetails?['can_call'] == true || json['can_call'] == true;
    final canNavigate = incidentDetails?['can_navigate'] == true || json['can_navigate'] == true;

    return AppNotificationModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      category: json['category']?.toString() ?? 'general',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      priority: json['priority']?.toString() ?? 'LOW',
      location: json['location']?.toString() ?? '',
      incidentId: incId,
      residentName: incidentDetails?['resident_name']?.toString() ?? '',
      emergencyCategory: incidentDetails?['category_name']?.toString() ?? '',
      incidentMessage: incidentDetails?['message']?.toString() ?? '',
      incidentStatus: incidentDetails?['status']?.toString() ?? '',
      latitude: lat,
      longitude: lng,
      address: addr,
      isSender: isSender,
      isAssignedGuardian: isAssignedGuardian,
      isAssignedVolunteer: isAssignedVolunteer,
      isAssignedSecurity: isAssignedSecurity,
      canAccept: canAccept,
      canDecline: canDecline,
      canChat: canChat,
      canCall: canCall,
      canNavigate: canNavigate,
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
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'is_sender': isSender,
        'is_assigned_guardian': isAssignedGuardian,
        'is_assigned_volunteer': isAssignedVolunteer,
        'is_assigned_security': isAssignedSecurity,
        'can_accept': canAccept,
        'can_decline': canDecline,
        'can_chat': canChat,
        'can_call': canCall,
        'can_navigate': canNavigate,
        'incident_details': incidentId > 0
            ? {
                'resident_name': residentName,
                'category_name': emergencyCategory,
                'message': incidentMessage,
                'status': incidentStatus,
                'latitude': latitude,
                'longitude': longitude,
                'resolved_address': address,
                'is_sender': isSender,
                'is_assigned_guardian': isAssignedGuardian,
                'is_assigned_volunteer': isAssignedVolunteer,
                'is_assigned_security': isAssignedSecurity,
                'can_accept': canAccept,
                'can_decline': canDecline,
                'can_chat': canChat,
                'can_call': canCall,
                'can_navigate': canNavigate,
              }
            : null,
      };
}

