class SOSIncidentModel {
  SOSIncidentModel({
    required this.id,
    this.residentId = 0,
    this.residentName = 'Unknown Resident',
    this.residentEmail = '',
    this.categoryName = 'SOS Emergency',
    this.message = '',
    this.emergencyDescription = '',
    this.voiceMessage = '',
    this.latitude,
    this.longitude,
    this.status = 'Pending',
    this.currentStatus = 'OPEN',
    this.assignedResponderName,
    this.assignedRole,
    this.acceptedAt,
    this.address = '',
    this.resolvedAddress = '',
    this.priority = 'HIGH',
    this.createdAt,
    this.isSender = false,
    this.isAssignedGuardian = false,
    this.canAccept = false,
    this.canDecline = false,
    this.canChat = false,
    this.canCall = false,
    this.canNavigate = false,
  });

  final int id;
  final int residentId;
  final String residentName;
  final String residentEmail;
  final String categoryName;
  final String message;
  final String emergencyDescription;
  final String voiceMessage;
  final double? latitude;
  final double? longitude;
  final String status;
  final String currentStatus;
  final String? assignedResponderName;
  final String? assignedRole;
  final DateTime? acceptedAt;
  final String address;
  final String resolvedAddress;
  final String priority;
  final DateTime? createdAt;

  /// Incident-based Permission Flags (Computed strictly by backend relative to current logged-in user)
  final bool isSender;
  final bool isAssignedGuardian;
  final bool canAccept;
  final bool canDecline;
  final bool canChat;
  final bool canCall;
  final bool canNavigate;

  factory SOSIncidentModel.fromJson(Map<String, dynamic> json) {
    int parseId(dynamic val) {
      if (val is num) return val.toInt();
      if (val != null) return int.tryParse(val.toString()) ?? 0;
      return 0;
    }

    double? parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val != null) return double.tryParse(val.toString());
      return null;
    }

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      return DateTime.tryParse(val.toString());
    }

    bool parseBool(dynamic val) {
      if (val is bool) return val;
      if (val != null) return val.toString().toLowerCase() == 'true';
      return false;
    }

    return SOSIncidentModel(
      id: parseId(json['id']),
      residentId: parseId(json['resident']),
      residentName: json['resident_name']?.toString() ?? 'Resident',
      residentEmail: json['resident_email']?.toString() ?? '',
      categoryName: json['category_name']?.toString() ?? 'SOS Emergency',
      message: json['message']?.toString() ?? '',
      emergencyDescription: json['emergency_description']?.toString() ?? '',
      voiceMessage: json['voice_message']?.toString() ?? '',
      latitude: parseDouble(json['latitude']),
      longitude: parseDouble(json['longitude']),
      status: json['status']?.toString() ?? 'Pending',
      currentStatus: json['current_status']?.toString() ?? json['status']?.toString() ?? 'OPEN',
      assignedResponderName: json['assigned_responder_name']?.toString(),
      assignedRole: json['assigned_role']?.toString(),
      acceptedAt: parseDate(json['accepted_at']),
      address: json['address']?.toString() ?? '',
      resolvedAddress: json['resolved_address']?.toString() ?? json['address']?.toString() ?? '',
      priority: json['priority']?.toString() ?? 'HIGH',
      createdAt: parseDate(json['created_at'] ?? json['triggered_time'] ?? json['time']),
      isSender: parseBool(json['is_sender']),
      isAssignedGuardian: parseBool(json['is_assigned_guardian']),
      canAccept: parseBool(json['can_accept']),
      canDecline: parseBool(json['can_decline']),
      canChat: parseBool(json['can_chat']),
      canCall: parseBool(json['can_call']),
      canNavigate: parseBool(json['can_navigate']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'resident': residentId,
      'resident_name': residentName,
      'resident_email': residentEmail,
      'category_name': categoryName,
      'message': message,
      'emergency_description': emergencyDescription,
      'voice_message': voiceMessage,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'current_status': currentStatus,
      'assigned_responder_name': assignedResponderName,
      'assigned_role': assignedRole,
      'accepted_at': acceptedAt?.toIso8601String(),
      'address': address,
      'resolved_address': resolvedAddress,
      'priority': priority,
      'created_at': createdAt?.toIso8601String(),
      'is_sender': isSender,
      'is_assigned_guardian': isAssignedGuardian,
      'can_accept': canAccept,
      'can_decline': canDecline,
      'can_chat': canChat,
      'can_call': canCall,
      'can_navigate': canNavigate,
    };
  }
}
