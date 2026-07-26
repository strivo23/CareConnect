import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import 'local_storage_service.dart';

class ApiClient {
  ApiClient._()
      : _dio = Dio(
          BaseOptions(
            baseUrl: AppConstants.defaultBaseUrl,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 20),
            sendTimeout: const Duration(seconds: 20),
            headers: const {'Accept': 'application/json'},
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await LocalStorageService.instance.getString(AppConstants.apiTokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final isAuthEndpoint = error.requestOptions.path.contains('/login') ||
              error.requestOptions.path.contains('/token/refresh');
          final shouldRefresh = error.response?.statusCode == 401 && !_isRefreshing && !isAuthEndpoint;
          if (!shouldRefresh) {
            handler.next(error);
            return;
          }

          final refreshed = await _refreshAccessToken();
          if (!refreshed) {
            await LocalStorageService.instance.clearAuth();
            if (onUnauthenticated != null) {
              onUnauthenticated!();
            }
            handler.next(error);
            return;
          }

          final retryOptions = error.requestOptions;
          final token = await LocalStorageService.instance.getString(AppConstants.apiTokenKey);
          if (token != null && token.isNotEmpty) {
            retryOptions.headers['Authorization'] = 'Bearer $token';
          }

          try {
            final response = await _dio.fetch(retryOptions);
            handler.resolve(response);
          } catch (retryError) {
            handler.next(retryError is DioException ? retryError : error);
          }
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._();

  void Function()? onUnauthenticated;

  final Dio _dio;
  bool _isRefreshing = false;

  Dio get dio => _dio;

  Future<bool> _refreshAccessToken() async {
    if (_isRefreshing) {
      return false;
    }

    _isRefreshing = true;
    try {
      final refreshToken = await LocalStorageService.instance.getString(AppConstants.apiRefreshTokenKey);
      if (refreshToken == null || refreshToken.isEmpty) {
        return false;
      }

      final response = await _dio.post(
        '/api/token/refresh/',
        data: {'refresh': refreshToken},
        options: Options(extra: {'skipAuth': true}),
      );

      final accessToken = response.data['access']?.toString();
      if (accessToken == null || accessToken.isEmpty) {
        return false;
      }

      await LocalStorageService.instance.saveString(AppConstants.apiTokenKey, accessToken);
      return true;
    } catch (_) {
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.get(path, queryParameters: queryParameters, options: options);
  }

  Future<Response<dynamic>> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    ProgressCallback? onSendProgress,
  }) {
    return _dio.post(path, data: data, queryParameters: queryParameters, options: options, onSendProgress: onSendProgress);
  }


  Future<Response<dynamic>> put(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.put(path, data: data, queryParameters: queryParameters, options: options);
  }

  Future<Response<dynamic>> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.delete(path, data: data, queryParameters: queryParameters, options: options);
  }

  Future<Response<dynamic>> patch(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.patch(path, data: data, queryParameters: queryParameters, options: options);
  }
}
