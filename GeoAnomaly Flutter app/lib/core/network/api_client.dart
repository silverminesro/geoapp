import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

class ApiClient {
  static const String baseUrl = 'http://95.217.17.177:8080/api/v1';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  late final Dio _dio;

  // ✅ PRIDAJ: Static instance
  static ApiClient? _instance;
  static ApiClient get instance => _instance ??= ApiClient._internal();

  // ✅ PRIDAJ: Private constructor
  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add interceptors
    _dio.interceptors.add(PrettyDioLogger(
      requestHeader: true,
      requestBody: true,
      responseBody: true,
      responseHeader: false,
      error: true,
      compact: true,
    ));

    // Add auth interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await _storage.delete(key: 'auth_token');
          await _storage.delete(key: 'user_data');
        }
        handler.next(error);
      },
    ));
  }

  // ✅ PRIDAJ: Backward compatibility methods
  static void initialize() {
    // Initialize instance
    _instance = ApiClient._internal();
  }

  static Dio get dio => instance._dio;
  static String? authToken;

  static Future<void> setAuthToken(String token) async {
    authToken = token;
    await _storage.write(key: 'auth_token', value: token);
  }

  static Future<void> clearAuthToken() async {
    authToken = null;
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'user_data');
  }

  // Instance methods
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) {
    return _dio.put(path, data: data);
  }

  Future<Response> delete(String path) {
    return _dio.delete(path);
  }

  Future<void> setAuthTokenInstance(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  Future<String?> getAuthToken() async {
    return await _storage.read(key: 'auth_token');
  }

  Future<void> clearAuth() async {
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'user_data');
  }
}

// Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient.instance;
});
