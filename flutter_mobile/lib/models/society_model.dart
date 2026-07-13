class SocietyModel {
  SocietyModel({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    required this.contactPerson,
    required this.contactNumber,
    required this.email,
    required this.status,
    required this.totalBlocks,
    required this.totalFlats,
  });

  final int id;
  final String name;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String contactPerson;
  final String contactNumber;
  final String email;
  final String status;
  final int totalBlocks;
  final int totalFlats;

  factory SocietyModel.fromJson(Map<String, dynamic> json) {
    return SocietyModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      pincode: json['pincode']?.toString() ?? '',
      contactPerson: json['contact_person']?.toString() ?? '',
      contactNumber: json['contact_number']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Active',
      totalBlocks: (json['total_blocks'] as num?)?.toInt() ?? 0,
      totalFlats: (json['total_flats'] as num?)?.toInt() ?? 0,
    );
  }
}

class BlockTowerModel {
  BlockTowerModel({required this.id, required this.societyId, required this.name, required this.totalFloors, required this.societyName});

  final int id;
  final int societyId;
  final String name;
  final int totalFloors;
  final String societyName;

  factory BlockTowerModel.fromJson(Map<String, dynamic> json) {
    return BlockTowerModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      societyId: (json['society'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      totalFloors: (json['total_floors'] as num?)?.toInt() ?? 0,
      societyName: json['society_name']?.toString() ?? '',
    );
  }
}

class FlatModel {
  FlatModel({
    required this.id,
    required this.blockId,
    required this.flatNumber,
    required this.floor,
    required this.type,
    required this.occupied,
    required this.blockName,
    required this.societyName,
    required this.societyId,
  });

  final int id;
  final int blockId;
  final String flatNumber;
  final int floor;
  final String type;
  final bool occupied;
  final String blockName;
  final String societyName;
  final int societyId;

  factory FlatModel.fromJson(Map<String, dynamic> json) {
    return FlatModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      blockId: (json['block'] as num?)?.toInt() ?? 0,
      flatNumber: json['flat_number']?.toString() ?? '',
      floor: (json['floor'] as num?)?.toInt() ?? 0,
      type: json['type']?.toString() ?? '',
      occupied: json['occupied'] as bool? ?? false,
      blockName: json['block_name']?.toString() ?? '',
      societyName: json['society_name']?.toString() ?? '',
      societyId: (json['society_id'] as num?)?.toInt() ?? 0,
    );
  }
}
