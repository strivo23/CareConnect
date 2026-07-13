import '../core/services/api_client.dart';
import '../models/resident_profile_model.dart';
import '../models/society_model.dart';

class SocietyRepository {
  SocietyRepository({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  Future<List<SocietyModel>> fetchSocieties({String? search}) async {
    final response = await _client.get('/api/society/societies/', queryParameters: search == null ? null : {'search': search});
    final data = response.data as Map<String, dynamic>?;
    final items = data?['results'] is List ? data!['results'] as List : response.data as List? ?? const [];
    return items.map((item) => SocietyModel.fromJson(Map<String, dynamic>.from(item as Map))).toList();
  }

  Future<List<BlockTowerModel>> fetchBlocks(int societyId) async {
    final response = await _client.get('/api/society/blocks/', queryParameters: {'society': societyId});
    final data = response.data as Map<String, dynamic>?;
    final items = data?['results'] is List ? data!['results'] as List : response.data as List? ?? const [];
    return items.map((item) => BlockTowerModel.fromJson(Map<String, dynamic>.from(item as Map))).toList();
  }

  Future<List<FlatModel>> fetchFlats({int? societyId, int? blockId, bool? occupied}) async {
    final params = <String, dynamic>{};
    if (societyId != null) params['society'] = societyId;
    if (blockId != null) params['block'] = blockId;
    if (occupied != null) params['occupied'] = occupied.toString();

    final response = await _client.get('/api/society/flats/', queryParameters: params.isEmpty ? null : params);
    final data = response.data as Map<String, dynamic>?;
    final items = data?['results'] is List ? data!['results'] as List : response.data as List? ?? const [];
    return items.map((item) => FlatModel.fromJson(Map<String, dynamic>.from(item as Map))).toList();
  }

  Future<List<ResidentProfileModel>> fetchResidents({String? search}) async {
    final response = await _client.get('/api/accounts/residents/', queryParameters: search == null ? null : {'search': search});
    final data = response.data as Map<String, dynamic>?;
    final items = data?['results'] is List ? data!['results'] as List : response.data as List? ?? const [];
    return items.map((item) => ResidentProfileModel.fromJson(Map<String, dynamic>.from(item as Map))).toList();
  }

  Future<ResidentProfileModel?> fetchResidentProfileByUserId(int userId) async {
    final response = await _client.get('/api/accounts/residents/', queryParameters: {'user': userId});
    final data = response.data as Map<String, dynamic>?;
    final items = data?['results'] is List ? data!['results'] as List : response.data as List? ?? const [];
    if (items.isNotEmpty) {
      return ResidentProfileModel.fromJson(Map<String, dynamic>.from(items.first as Map));
    }
    return null;
  }

  Future<ResidentProfileModel> updateResidentProfile({
    required int residentProfileId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client.put('/api/accounts/residents/$residentProfileId/', data: payload);
    return ResidentProfileModel.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<ResidentProfileModel> createResidentProfile(Map<String, dynamic> payload) async {
    final response = await _client.post('/api/accounts/residents/', data: payload);
    return ResidentProfileModel.fromJson(Map<String, dynamic>.from(response.data as Map));
  }
}
