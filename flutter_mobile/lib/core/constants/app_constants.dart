import 'package:flutter/foundation.dart' show kIsWeb;

class AppConstants {
  static const appName = 'CareConnect';
  static const defaultBaseUrl = kIsWeb
      ? 'http://localhost:8000'
      : String.fromEnvironment(
          'API_BASE_URL',
          // For Android Emulator: 10.0.2.2 (alias to host PC)
          // For real device on same Wi-Fi: use your PC's LAN IP below
          defaultValue: 'http://192.168.1.36:8000',
        );

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
