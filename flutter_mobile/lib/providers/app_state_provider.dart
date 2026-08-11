import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/services/local_storage_service.dart';
import '../models/resident_profile_model.dart';
import '../services/society_repository.dart';

class AppStateProvider extends ChangeNotifier {
  AppStateProvider({SocietyRepository? repository}) : _repository = repository ?? SocietyRepository();

  final SocietyRepository _repository;

  ResidentProfileModel? _residentProfile;
  bool _isOffline = false;
  bool _isLoading = false;

  ResidentProfileModel? get residentProfile => _residentProfile;
  bool get isOffline => _isOffline;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    final cachedResident = await LocalStorageService.instance.getJson(AppConstants.apiResidentKey);
    if (cachedResident != null) {
      _residentProfile = ResidentProfileModel.fromJson(cachedResident);
    }
    notifyListeners();
  }

  Future<void> loadResidentByUserId(int userId) async {
    _setLoading(true);
    try {
      final resident = await _repository.fetchResidentProfileByUserId(userId);
      _residentProfile = resident;
      if (resident != null) {
        await LocalStorageService.instance.saveJson(AppConstants.apiResidentKey, _serializeResident(resident));
      }
      _isOffline = false;
    } catch (e) {
      debugPrint('[AppStateProvider] Load resident error: $e');
      _isOffline = false;
      final cachedResident = await LocalStorageService.instance.getJson(AppConstants.apiResidentKey);
      if (cachedResident != null) {
        _residentProfile = ResidentProfileModel.fromJson(cachedResident);
      }
    } finally {
      _setLoading(false);
    }
  }

  Map<String, dynamic> _serializeResident(ResidentProfileModel resident) {
    return {
      'id': resident.id,
      'user': resident.user?.toJson(),
      'society': resident.societyId,
      'society_name': resident.societyName,
      'block_name': resident.blockName,
      'flat_number': resident.flatNumber,
      'status': resident.status,
      'approved_by_name': resident.approvedByName,
      'approved_at': resident.approvedAt?.toIso8601String(),
    };
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
