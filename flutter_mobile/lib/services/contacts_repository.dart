import 'dart:convert';

import '../core/constants/app_constants.dart';
import '../core/services/api_client.dart';
import '../core/services/local_storage_service.dart';
import '../models/contact_model.dart';

class ContactsRepository {
  ContactsRepository({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  Future<List<RelationshipModel>> fetchRelationships() async {
    final response = await _client.get('/api/emergency/relationships/');
    List items = [];
    if (response.data is List) {
      items = response.data as List;
    } else if (response.data is Map && response.data['results'] is List) {
      items = response.data['results'] as List;
    }
    return items.map((item) => RelationshipModel.fromJson(Map<String, dynamic>.from(item as Map))).toList();
  }

  Future<List<EmergencyContactModel>> fetchContacts({required int residentId}) async {
    final response = await _client.get('/api/emergency/contacts/', queryParameters: {'resident': residentId});
    List items = [];
    if (response.data is List) {
      items = response.data as List;
    } else if (response.data is Map && response.data['results'] is List) {
      items = response.data['results'] as List;
    }
    final contacts = items.map((item) => EmergencyContactModel.fromJson(Map<String, dynamic>.from(item as Map))).toList();
    await LocalStorageService.instance.saveString(
      AppConstants.apiContactsCacheKey,
      jsonEncode(contacts.map((item) => item.toJson()).toList()),
    );
    return contacts;
  }

  Future<List<GuardianModel>> fetchGuardians({required int residentId}) async {
    final response = await _client.get('/api/emergency/guardians/', queryParameters: {'resident': residentId});
    List items = [];
    if (response.data is List) {
      items = response.data as List;
    } else if (response.data is Map && response.data['results'] is List) {
      items = response.data['results'] as List;
    }
    return items.map((item) => GuardianModel.fromJson(Map<String, dynamic>.from(item as Map))).toList();
  }

  Future<EmergencyContactModel> createContact(Map<String, dynamic> payload) async {
    final response = await _client.post('/api/emergency/contacts/', data: payload);
    return EmergencyContactModel.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<EmergencyContactModel> updateContact(int id, Map<String, dynamic> payload) async {
    final response = await _client.put('/api/emergency/contacts/$id/', data: payload);
    return EmergencyContactModel.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<void> deleteContact(int id) async {
    await _client.delete('/api/emergency/contacts/$id/');
  }

  Future<bool> sendContactVerification({required int contactId}) async {
    final response = await _client.post(
      '/api/emergency/contacts/send-verification/',
      data: {'contact_id': contactId},
    );
    return response.statusCode == 200;
  }

  Future<bool> verifyContactOTP({required int contactId, required String otp}) async {
    final response = await _client.post(
      '/api/emergency/contacts/verify/',
      data: {'contact_id': contactId, 'otp': otp},
    );
    return response.statusCode == 200;
  }

  Future<bool> resendContactVerification({required int contactId}) async {
    final response = await _client.post(
      '/api/emergency/contacts/resend/',
      data: {'contact_id': contactId},
    );
    return response.statusCode == 200;
  }

  Future<void> verifyContact(int id) async {
    await _client.post('/api/emergency/contacts/$id/verify/');
  }

  // --- Guardian Code Based Linking API Methods ---

  Future<Map<String, dynamic>> fetchMyGuardianCode() async {
    final response = await _client.get('/api/guardian/my-code/');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<String> generateGuardianCode() async {
    final response = await _client.post('/api/guardian/generate-code/');
    final data = Map<String, dynamic>.from(response.data as Map);
    return data['guardian_code'] as String? ?? '';
  }

  Future<Map<String, dynamic>> linkGuardian({
    required String guardianCode,
    required String relationship,
    bool isPrimary = false,
  }) async {
    final response = await _client.post(
      '/api/resident/link-guardian/',
      data: {
        'guardian_code': guardianCode,
        'relationship': relationship,
        'is_primary': isPrimary,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<Map<String, dynamic>>> fetchResidentGuardians() async {
    final response = await _client.get('/api/resident/guardians/');
    List items = [];
    if (response.data is List) {
      items = response.data as List;
    } else if (response.data is Map && response.data['guardians'] is List) {
      items = response.data['guardians'] as List;
    } else if (response.data is Map && response.data['results'] is List) {
      items = response.data['results'] as List;
    }
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> unlinkGuardian(int id) async {
    await _client.delete(
      '/api/resident/unlink-guardian/$id/',
      data: {'guardian_id': id},
    );
  }

  Future<void> changePrimaryGuardian(int id) async {
    await _client.patch(
      '/api/resident/change-primary/',
      data: {'guardian_id': id},
    );
  }

  Future<Map<String, dynamic>> respondGuardianLink({required int linkId, required String action}) async {
    final response = await _client.post(
      '/api/guardian/respond-link/',
      data: {'link_id': linkId, 'action': action},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }
}




