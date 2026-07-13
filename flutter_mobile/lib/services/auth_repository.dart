import '../core/constants/app_constants.dart';
import '../core/services/api_client.dart';
import '../core/services/local_storage_service.dart';
import '../models/user_model.dart';

class AuthRepository {
  AuthRepository({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  Future<AuthSession> login({required String email, required String password}) async {
    final response = await _client.post(
      '/api/accounts/login/',
      data: {'email': email, 'password': password},
    );
    final session = AuthSession.fromJson(Map<String, dynamic>.from(response.data as Map));
    await _persistSession(session);
    return session;
  }

  Future<AuthSession> register({
    required String name,
    required String email,
    required String phoneNumber,
    required String password,
    required String role,
    int? societyId,
    int? blockId,
    int? flatId,
  }) async {
    final response = await _client.post(
      '/api/accounts/register/',
      data: {
        'full_name': name,
        'email': email,
        'phone_number': phoneNumber,
        'password': password,
        'role': role,
        if (societyId != null) 'society': societyId,
        if (blockId != null) 'block': blockId,
        if (flatId != null) 'flat': flatId,
      },
    );

    final data = response.data is Map<String, dynamic>
        ? Map<String, dynamic>.from(response.data as Map)
        : <String, dynamic>{};
    if (data.containsKey('access') && data.containsKey('refresh')) {
      final session = AuthSession.fromJson(data);
      await _persistSession(session);
      return session;
    }

    return AuthSession(
      accessToken: '',
      refreshToken: '',
      user: AppUser.fromJson(data),
    );
  }

  Future<AppUser?> getStoredUser() async {
    final json = await LocalStorageService.instance.getJson(AppConstants.apiUserKey);
    if (json == null) {
      return null;
    }
    return AppUser.fromJson(json);
  }

  Future<AppUser> updateProfile({required String name, required String email, required String phoneNumber}) async {
    final response = await _client.patch(
      '/api/accounts/me/',
      data: {
        'full_name': name,
        'email': email,
        'phone_number': phoneNumber,
      },
    );
    final user = AppUser.fromJson(Map<String, dynamic>.from(response.data as Map));
    final currentUser = await getStoredUser();
    if (currentUser != null) {
      final updatedSessionUser = AppUser(
        id: currentUser.id,
        email: user.email,
        fullName: user.fullName,
        phoneNumber: user.phoneNumber,
        role: currentUser.role,
      );
      await LocalStorageService.instance.saveJson(AppConstants.apiUserKey, updatedSessionUser.toJson());
    }
    return user;
  }

  Future<void> logout() async {
    await LocalStorageService.instance.clearAuth();
  }

  Future<void> _persistSession(AuthSession session) async {
    await LocalStorageService.instance.saveString(AppConstants.apiTokenKey, session.accessToken);
    await LocalStorageService.instance.saveString(AppConstants.apiRefreshTokenKey, session.refreshToken);
    await LocalStorageService.instance.saveJson(AppConstants.apiUserKey, session.user.toJson());
  }
}
