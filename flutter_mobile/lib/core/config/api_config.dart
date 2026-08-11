class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://careconnect-backend-hbdu.onrender.com/api',
  );

  static const String websocketBaseUrl = String.fromEnvironment(
    'WEBSOCKET_BASE_URL',
    defaultValue: 'wss://careconnect-backend-hbdu.onrender.com',
  );

  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'https://careconnect-backend-hbdu.onrender.com',
  );
}
