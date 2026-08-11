import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import 'local_storage_service.dart';

class ApiClient {
  ApiClient._()
      : _dio = Dio(
          BaseOptions(
            baseUrl: AppConstants.defaultBaseUrl,
            connectTimeout: const Duration(seconds: 45),
            receiveTimeout: const Duration(seconds: 45),
            sendTimeout: const Duration(seconds: 45),
            headers: const {'Accept': 'application/json'},
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.baseUrl.endsWith('/api') && options.path.startsWith('/api/')) {
            options.path = options.path.substring(4);
          }
          final token = await LocalStorageService.instance.getString(AppConstants.apiTokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (kDebugMode) {
            debugPrint('=== DIO REQUEST ===');
            debugPrint('URL: ${options.baseUrl}${options.path}');
            debugPrint('Method: ${options.method}');
            debugPrint('Headers: ${options.headers}');
            if (options.data != null) debugPrint('Request JSON: ${options.data}');
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint('=== DIO RESPONSE ===');
            debugPrint('URL: ${response.requestOptions.path}');
            debugPrint('Status Code: ${response.statusCode}');
            debugPrint('Response JSON: ${response.data}');
          }
          handler.next(response);
        },
        onError: (error, handler) async {
          if (kDebugMode) {
            debugPrint('=== DIO ERROR ===');
            debugPrint('URL: ${error.requestOptions.path}');
            debugPrint('Status Code: ${error.response?.statusCode}');
            debugPrint('Response Data: ${error.response?.data}');
            debugPrint('Error Message: ${error.message}');
            if (error.stackTrace != null) debugPrint('Stack Trace: ${error.stackTrace}');
          }

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

  // ── Static Helper Wrappers ─────────────────────────────────────────────
  static String get baseUrl => AppConstants.defaultBaseUrl;

  static Future<String?> getAccessToken() async {
    return LocalStorageService.instance.getString(AppConstants.apiTokenKey);
  }

  static String extractErrorMessage(dynamic error) {
    if (error is DioException) {
      if (error.response?.statusCode == 401) {
        return 'Unauthorized. Please login again.';
      }
      if (error.response?.statusCode == 502 || error.response?.statusCode == 503 || error.response?.statusCode == 504) {
        return 'Server is temporarily warming up. Please try again in a few seconds.';
      }
      if (error.response?.data != null) {
        final data = error.response!.data;
        if (data is Map) {
          if (data['message'] != null && data['message'].toString().isNotEmpty) {
            return data['message'].toString();
          }
          if (data['detail'] != null && data['detail'].toString().isNotEmpty) {
            return data['detail'].toString();
          }
          if (data['error'] != null && data['error'].toString().isNotEmpty) {
            return data['error'].toString();
          }
          for (final entry in data.entries) {
            if (entry.value is List && (entry.value as List).isNotEmpty) {
              return '${entry.key}: ${(entry.value as List).first}';
            } else if (entry.value is String) {
              return '${entry.key}: ${entry.value}';
            }
          }
        } else if (data is String && data.isNotEmpty) {
          if (data.trim().startsWith('<')) {
            return 'Server is warming up. Please try again in a few seconds.';
          }
          return data;
        }
      }
      if (error.type == DioExceptionType.connectionTimeout || error.type == DioExceptionType.receiveTimeout) {
        return 'Network connection timeout. Please try again.';
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'Network connection failure. Please check your internet connection.';
      }
    }
    final raw = error.toString().replaceAll('Exception: ', '').replaceAll('DioException: ', '');
    return raw.isNotEmpty ? raw : 'An unexpected error occurred. Please try again.';
  }
}
