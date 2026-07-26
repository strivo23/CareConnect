import 'package:dio/dio.dart';
import '../core/services/api_client.dart';
import '../models/emergency_action_model.dart';

class EmergencyRepository {
  EmergencyRepository({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  static const List<EmergencyActionModel> actions = [
    EmergencyActionModel(label: 'Ambulance', slug: 'ambulance', icon: 'local_hospital', colorHex: '#FF7A00'),
    EmergencyActionModel(label: 'Fire', slug: 'fire', icon: 'local_fire_department', colorHex: '#EF4444'),
    EmergencyActionModel(label: 'Police', slug: 'police', icon: 'local_police', colorHex: '#FF9A3D'),
    EmergencyActionModel(label: 'Electrical', slug: 'electrical', icon: 'power', colorHex: '#FFB266'),
    EmergencyActionModel(label: 'Security', slug: 'security', icon: 'shield', colorHex: '#FFB84D'),
    EmergencyActionModel(label: 'Hospital', slug: 'hospital', icon: 'medical_services', colorHex: '#FF8C42'),
  ];

  Future<Map<String, dynamic>> triggerSOS({String? message}) async {
    final response = await _client.post(
      '/api/emergency/alerts/',
      data: {
        'category': 'SOS',
        'message': message ?? 'Emergency SOS requested from mobile app',
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> triggerQuickAction(EmergencyActionModel action, {String? message}) async {
    final response = await _client.post(
      '/api/emergency/alerts/',
      data: {
        'category': action.slug,
        'message': message ?? '${action.label} assistance requested from mobile app',
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Upload text description and/or voice recording for an existing SOS incident.
  Future<Map<String, dynamic>> uploadSOSMessage({
    required int incidentId,
    String? emergencyDescription,
    String? voiceFilePath,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final formData = FormData();

    if (emergencyDescription != null && emergencyDescription.trim().isNotEmpty) {
      formData.fields.add(MapEntry('emergency_description', emergencyDescription.trim()));
    }

    if (voiceFilePath != null && voiceFilePath.isNotEmpty) {
      final fileName = voiceFilePath.split('/').last;
      formData.files.add(
        MapEntry(
          'voice_message',
          await MultipartFile.fromFile(
            voiceFilePath,
            filename: fileName,
          ),
        ),
      );
    }

    final response = await _client.post(
      '/api/sos/$incidentId/message/',
      data: formData,
      onSendProgress: onSendProgress,
    );

    return Map<String, dynamic>.from(response.data as Map);
  }
}

