import 'user_model.dart';

class ResidentProfileModel {
  ResidentProfileModel({
    required this.id,
    required this.user,
    required this.societyId,
    required this.societyName,
    required this.blockName,
    required this.flatNumber,
    required this.status,
    required this.approvedByName,
    required this.approvedAt,
  });

  final int id;
  final AppUser? user;
  final int? societyId;
  final String societyName;
  final String blockName;
  final String flatNumber;
  final String status;
  final String approvedByName;
  final DateTime? approvedAt;

  factory ResidentProfileModel.fromJson(Map<String, dynamic> json) {
    return ResidentProfileModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      user: json['user'] is Map<String, dynamic> ? AppUser.fromJson(json['user'] as Map<String, dynamic>) : null,
      societyId: (json['society'] as num?)?.toInt(),
      societyName: json['society_name']?.toString() ?? '',
      blockName: json['block_name']?.toString() ?? '',
      flatNumber: json['flat_number']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Pending',
      approvedByName: json['approved_by_name']?.toString() ?? '',
      approvedAt: DateTime.tryParse(json['approved_at']?.toString() ?? ''),
    );
  }
}
