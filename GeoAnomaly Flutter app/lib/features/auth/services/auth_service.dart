import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/network/api_client.dart';
import '../models/auth_models.dart';

class AuthService {
  final Dio _dio = ApiClient.dio;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // ✅ Initialize auth - load token from storage
  Future<void> initializeAuth() async {
    try {
      final token = await _secureStorage.read(key: 'jwt_token');
      if (token != null) {
        ApiClient.setAuthToken(token);
        print('✅ JWT token loaded from storage: ${token.substring(0, 20)}...');

        // Validate token
        final isValid = await validateToken();
        if (!isValid) {
          await clearAuthData();
          print('⚠️ Invalid token cleared');
        }
      } else {
        print('⚠️ No JWT token found in storage');
      }
    } catch (e) {
      print('❌ Failed to initialize auth: $e');
    }
  }

  // ✅ Login s persistent storage
  Future<AuthResponse> login({
    required String username,
    required String password,
  }) async {
    try {
      print('🔐 Logging in user: $username');

      final response = await _dio.post(
        '/auth/login',
        data: {
          'username': username,
          'password': password,
        },
      );

      print('✅ Login response: ${response.data}');

      final user = User.fromJson(response.data['user']);
      final token = response.data['token'];

      // ✅ FIX: Pridaj expiresAt parameter
      final expiresAt = (response.data['expires'] as num?)?.toInt() ??
          (DateTime.now().millisecondsSinceEpoch ~/ 1000) +
              86400; // 24h default

      // Save token to API client
      ApiClient.setAuthToken(token);

      // ✅ Save token persistently
      await _secureStorage.write(key: 'jwt_token', value: token);
      await _secureStorage.write(
          key: 'user_data', value: user.toJson().toString());

      print('✅ JWT token saved: ${token.substring(0, 20)}...');
      return AuthResponse(
        user: user,
        token: token,
        expiresAt: expiresAt, // ✅ FIX: Pridaj expiresAt
      );
    } on DioException catch (e) {
      print('❌ Login error: ${e.response?.data}');
      throw Exception(_handleDioError(e, 'Login failed'));
    } catch (e) {
      print('❌ Unexpected login error: $e');
      throw Exception('Unexpected error occurred during login');
    }
  }

  // ✅ Register s persistent storage
  Future<AuthResponse> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      print('📝 Registering user: $username');

      final response = await _dio.post(
        '/auth/register',
        data: {
          'username': username,
          'email': email,
          'password': password,
        },
      );

      print('✅ Register response: ${response.data}');

      final user = User.fromJson(response.data['user']);
      final token = response.data['token'];

      // ✅ FIX: Pridaj expiresAt parameter
      final expiresAt = (response.data['expires'] as num?)?.toInt() ??
          (DateTime.now().millisecondsSinceEpoch ~/ 1000) +
              86400; // 24h default

      // Save token to API client
      ApiClient.setAuthToken(token);

      // ✅ Save token persistently
      await _secureStorage.write(key: 'jwt_token', value: token);
      await _secureStorage.write(
          key: 'user_data', value: user.toJson().toString());

      print('✅ JWT token saved: ${token.substring(0, 20)}...');
      return AuthResponse(
        user: user,
        token: token,
        expiresAt: expiresAt, // ✅ FIX: Pridaj expiresAt
      );
    } on DioException catch (e) {
      print('❌ Register error: ${e.response?.data}');
      throw Exception(_handleDioError(e, 'Registration failed'));
    } catch (e) {
      print('❌ Unexpected register error: $e');
      throw Exception('Unexpected error occurred during registration');
    }
  }

  // ✅ Get user profile
  Future<User> getProfile() async {
    try {
      final response = await _dio.get('/user/profile');
      return User.fromJson(response.data);
    } on DioException catch (e) {
      print('❌ Get profile error: ${e.response?.data}');
      throw Exception(_handleDioError(e, 'Failed to get profile'));
    }
  }

  // ✅ Validate JWT token
  Future<bool> validateToken() async {
    try {
      if (ApiClient.authToken == null) {
        return false;
      }

      final response = await _dio.get(
          '/user/profile'); // ✅ FIX: Použiť /user/profile namiesto /auth/validate
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Token validation failed: $e');
      return false;
    }
  }

  // ✅ Clear auth data
  Future<void> clearAuthData() async {
    try {
      await _secureStorage.delete(key: 'jwt_token');
      await _secureStorage.delete(key: 'user_data');
      ApiClient.clearAuthToken();
      print('✅ Auth data cleared');
    } catch (e) {
      print('❌ Failed to clear auth data: $e');
    }
  }

  // ✅ Logout s clearing storage
  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
      print('✅ Logout successful');
    } catch (e) {
      print('❌ Logout error: $e');
      // Continue with logout even if server call fails
    } finally {
      // Clear all auth data
      await clearAuthData();
    }
  }

  // ✅ Check if user is logged in
  Future<bool> isLoggedIn() async {
    try {
      final token = await _secureStorage.read(key: 'jwt_token');
      return token != null && ApiClient.authToken != null;
    } catch (e) {
      return false;
    }
  }

  // ✅ Handle Dio errors
  String _handleDioError(DioException e, String defaultMessage) {
    if (e.response?.statusCode == 401) {
      return 'Invalid credentials';
    } else if (e.response?.statusCode == 403) {
      return 'Access forbidden';
    } else if (e.response?.statusCode == 409) {
      return 'Username or email already exists';
    } else if (e.response?.data != null && e.response?.data['error'] != null) {
      return e.response!.data['error'];
    } else {
      return defaultMessage;
    }
  }
}
