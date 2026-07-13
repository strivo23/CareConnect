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
  String _languageCode = 'en';
  AppUser? _user;
  String? _errorMessage;

  bool get isReady => _isReady;
  bool get isLoading => _isLoading;
  bool get useDarkTheme => _useDarkTheme;
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
    _useDarkTheme = themeMode == 'dark';
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
  }) async {
    _setLoading(true);
    try {
      final session = await _repository.register(
        name: name,
        email: email,
        phoneNumber: phoneNumber,
        password: password,
        role: role,
        societyId: societyId,
        blockId: blockId,
        flatId: flatId,
      );
      _user = session.user.email.isEmpty ? _user : session.user;
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

  Future<void> toggleTheme(bool value) async {
    _useDarkTheme = value;
    await LocalStorageService.instance.saveString(AppConstants.themeModeKey, value ? 'dark' : 'light');
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
    final text = error.toString();
    if (text.contains('401')) {
      return 'Invalid email or password';
    }
    return 'Something went wrong. Please try again.';
  }
}
