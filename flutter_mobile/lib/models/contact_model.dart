class EmergencyContactModel {
  EmergencyContactModel({
    required this.id,
    required this.residentId,
    required this.name,
    required this.phone,
    this.email,
    required this.relationshipName,
    required this.isPrimary,
    required this.verified,
    required this.verificationStatus,
  });

  final int id;
  final int residentId;
  final String name;
  final String phone;
  final String? email;
  final String relationshipName;
  final bool isPrimary;
  final bool verified;
  final String verificationStatus;

  factory EmergencyContactModel.fromJson(Map<String, dynamic> json) {
    final verification = json['verification_status_details'] as Map<String, dynamic>?;
    return EmergencyContactModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      residentId: (json['resident'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      relationshipName: json['relationship_name']?.toString() ?? '',
      isPrimary: json['is_primary'] as bool? ?? false,
      verified: json['verified'] as bool? ?? false,
      verificationStatus: verification?['status']?.toString() ?? (json['verified'] as bool? ?? false ? 'Verified' : 'Pending'),
    );
  }

  Map<String, dynamic> toJson() => {
        'resident': residentId,
        'name': name,
        'phone': phone,
        'email': email,
        'relationship': null,
        'is_primary': isPrimary,
        'verified': verified,
      };
}


class RelationshipModel {
  RelationshipModel({required this.id, required this.name});

  final int id;
  final String name;

  factory RelationshipModel.fromJson(Map<String, dynamic> json) {
    return RelationshipModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}

class GuardianModel {
  GuardianModel({
    required this.id,
    required this.residentId,
    required this.name,
    required this.phone,
    required this.relationshipName,
    required this.isPrimary,
    required this.verified,
  });

  final int id;
  final int residentId;
  final String name;
  final String phone;
  final String relationshipName;
  final bool isPrimary;
  final bool verified;

  factory GuardianModel.fromJson(Map<String, dynamic> json) {
    return GuardianModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      residentId: (json['resident'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      relationshipName: json['relationship_name']?.toString() ?? '',
      isPrimary: json['is_primary'] as bool? ?? false,
      verified: json['verified'] as bool? ?? false,
    );
  }
}
