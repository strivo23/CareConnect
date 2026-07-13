import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

class LocalStorageService {
  LocalStorageService._();

  static final LocalStorageService instance = LocalStorageService._();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> saveString(String key, String value) async {
    final prefs = await _preferences;
    await prefs.setString(key, value);
  }

  Future<void> saveJson(String key, Map<String, dynamic> value) async {
    await saveString(key, jsonEncode(value));
  }

  Future<String?> getString(String key) async {
    final prefs = await _preferences;
    return prefs.getString(key);
  }

  Future<Map<String, dynamic>?> getJson(String key) async {
    final value = await getString(key);
    if (value == null || value.isEmpty) {
      return null;
    }
    return jsonDecode(value) as Map<String, dynamic>;
  }

  Future<void> remove(String key) async {
    final prefs = await _preferences;
    await prefs.remove(key);
  }

  Future<void> clearAuth() async {
    final prefs = await _preferences;
    await prefs.remove(AppConstants.apiTokenKey);
    await prefs.remove(AppConstants.apiRefreshTokenKey);
    await prefs.remove(AppConstants.apiUserKey);
    await prefs.remove(AppConstants.apiResidentKey);
  }
}
