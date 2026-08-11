import '../config/api_config.dart';

class AppConstants {
  static const appName = 'CareConnect';
  static const defaultBaseUrl = ApiConfig.baseUrl;

  static const apiTokenKey = 'careconnect_access_token';
  static const apiRefreshTokenKey = 'careconnect_refresh_token';
  static const apiUserKey = 'careconnect_user_json';
  static const apiResidentKey = 'careconnect_resident_json';
  static const apiContactsCacheKey = 'careconnect_contacts_cache';
  static const apiNotificationsCacheKey = 'careconnect_notifications_cache';
  static const themeModeKey = 'careconnect_theme_mode';
  static const languageCodeKey = 'careconnect_language_code';
  static const profileImagePathKey = 'careconnect_profile_image_path';
}
