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
    final data = response.data as Map<String, dynamic>?;
    final items = data?['results'] is List ? data!['results'] as List : response.data as List? ?? const [];
    return items.map((item) => RelationshipModel.fromJson(Map<String, dynamic>.from(item as Map))).toList();
  }

  Future<List<EmergencyContactModel>> fetchContacts({required int residentId}) async {
    final response = await _client.get('/api/emergency/contacts/', queryParameters: {'resident': residentId});
    final data = response.data as Map<String, dynamic>?;
    final items = data?['results'] is List ? data!['results'] as List : response.data as List? ?? const [];
    final contacts = items.map((item) => EmergencyContactModel.fromJson(Map<String, dynamic>.from(item as Map))).toList();
    await LocalStorageService.instance.saveString(
      AppConstants.apiContactsCacheKey,
      jsonEncode(contacts.map((item) => item.toJson()).toList()),
    );
    return contacts;
  }

  Future<List<GuardianModel>> fetchGuardians({required int residentId}) async {
    final response = await _client.get('/api/emergency/guardians/', queryParameters: {'resident': residentId});
    final data = response.data as Map<String, dynamic>?;
    final items = data?['results'] is List ? data!['results'] as List : response.data as List? ?? const [];
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

  Future<void> verifyContact(int id) async {
    await _client.post('/api/emergency/contacts/$id/verify/');
  }
}
