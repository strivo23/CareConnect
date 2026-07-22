import 'package:flutter/material.dart';

import '../core/services/api_client.dart';
import '../core/constants/app_constants.dart';
import '../core/services/local_storage_service.dart';
import '../models/user_model.dart';
import '../services/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthRepository? repository}) : _repository = repository ?? AuthRepository();

  final AuthRepository _repository;

  bool _isReady = false;
  bool _isLoading = false;
  bool _useDarkTheme = false;
  String _themeMode = 'system';
  String _languageCode = 'en';
  AppUser? _user;
  String? _errorMessage;

  bool get isReady => _isReady;
  bool get isLoading => _isLoading;

  String get themeModeString => _themeMode;
  ThemeMode get themeMode {
    switch (_themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  bool get useDarkTheme {
    if (_themeMode == 'dark') return true;
    if (_themeMode == 'light') return false;
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return brightness == Brightness.dark;
  }

  String get languageCode => _languageCode;
  AppUser? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  Future<void> init() async {
    ApiClient.instance.onUnauthenticated = () {
      logout();
    };

    final storedUser = await _repository.getStoredUser();
    final themeMode = await LocalStorageService.instance.getString(AppConstants.themeModeKey);
    final languageCode = await LocalStorageService.instance.getString(AppConstants.languageCodeKey);

    _user = storedUser;
    _themeMode = themeMode ?? 'system';
    _useDarkTheme = _themeMode == 'dark';
    _languageCode = languageCode ?? 'en';
    _isReady = true;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    try {
      final session = await _repository.login(email: email, password: password);
      _user = session.user;
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = _extractMessage(error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String phoneNumber,
    required String password,
    required String role,
    int? societyId,
    int? blockId,
    int? flatId,
    int? relationship,
    String? skills,
    String? availability,
    String? serviceArea,
    String? shift,
    String? employeeId,
    int? assignedSocietyId,
  }) async {
    _setLoading(true);
    try {
      await _repository.register(
        name: name,
        email: email,
        phoneNumber: phoneNumber,
        password: password,
        role: role,
        societyId: societyId,
        blockId: blockId,
        flatId: flatId,
        relationship: relationship,
        skills: skills,
        availability: availability,
        serviceArea: serviceArea,
        shift: shift,
        employeeId: employeeId,
        assignedSocietyId: assignedSocietyId,
      );
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = _extractMessage(error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateProfile({required String name, required String email, required String phoneNumber}) async {
    _setLoading(true);
    try {
      final updatedUser = await _repository.updateProfile(name: name, email: email, phoneNumber: phoneNumber);
      if (_user != null) {
        _user = AppUser(
          id: _user!.id,
          email: updatedUser.email,
          fullName: updatedUser.fullName,
          phoneNumber: updatedUser.phoneNumber,
          role: _user!.role,
        );
      }
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = _extractMessage(error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    _user = null;
    notifyListeners();
  }

  Future<bool> sendOTP(String email) async {
    _setLoading(true);
    try {
      final success = await _repository.sendOTP(email: email);
      _errorMessage = null;
      return success;
    } catch (error) {
      _errorMessage = _extractMessage(error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> verifyOTP(String email, String otp) async {
    _setLoading(true);
    try {
      final success = await _repository.verifyOTP(email: email, otp: otp);
      _errorMessage = null;
      return success;
    } catch (error) {
      _errorMessage = _extractMessage(error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> resendOTP(String email) async {
    _setLoading(true);
    try {
      final success = await _repository.resendOTP(email: email);
      _errorMessage = null;
      return success;
    } catch (error) {
      _errorMessage = _extractMessage(error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> toggleTheme(bool value) async {
    _useDarkTheme = value;
    _themeMode = value ? 'dark' : 'light';
    await LocalStorageService.instance.saveString(AppConstants.themeModeKey, _themeMode);
    notifyListeners();
  }

  Future<void> setThemeMode(String mode) async {
    if (mode == 'System' || mode == 'system') {
      _themeMode = 'system';
    } else if (mode == 'Dark' || mode == 'dark') {
      _themeMode = 'dark';
    } else {
      _themeMode = 'light';
    }
    _useDarkTheme = _themeMode == 'dark';
    await LocalStorageService.instance.saveString(AppConstants.themeModeKey, _themeMode);
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    _languageCode = code;
    await LocalStorageService.instance.saveString(AppConstants.languageCodeKey, code);
    notifyListeners();
  }

  void setUser(AppUser? user) {
    _user = user;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String _extractMessage(Object error) {
    dynamic err = error;
    try {
      if (err.response != null && err.response.data != null) {
        final data = err.response.data;
        if (data is Map) {
          if (data.containsKey('detail')) {
            return data['detail'].toString();
          }
          final messages = <String>[];
          data.forEach((key, val) {
            if (val is List) {
              messages.add('${key}: ${val.join(", ")}');
            } else {
              messages.add('${key}: $val');
            }
          });
          if (messages.isNotEmpty) {
            return messages.join('\n');
          }
        }
      }
    } catch (_) {}

    final text = error.toString();
    if (text.contains('401')) {
      return 'Invalid email or password';
    }
    return 'Something went wrong. Please try again.';
  }
}

