import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth_models.dart';
import '../services/auth_service.dart';

// ✅ Auth Service Provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// ✅ Auth State
class AuthState {
  final User? user;
  final String? token;
  final bool isLoading;
  final String? error;
  final bool isLoggedIn;

  const AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.error,
    this.isLoggedIn = false,
  });

  AuthState copyWith({
    User? user,
    String? token,
    bool? isLoading,
    String? error,
    bool? isLoggedIn,
  }) {
    return AuthState(
      user: user ?? this.user,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    );
  }
}

// ✅ Auth Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AuthState()) {
    _checkAuthStatus();
  }

  // ✅ Check if user is already logged in
  Future<void> _checkAuthStatus() async {
    try {
      final isLoggedIn = await _authService.isLoggedIn();
      if (isLoggedIn) {
        final user = await _authService.getProfile();
        state = state.copyWith(
          user: user,
          isLoggedIn: true,
        );
        print('✅ User is logged in: ${user.username}');
      } else {
        print('⚠️ User is not logged in');
      }
    } catch (e) {
      print('❌ Auth check failed: $e');
      await _authService.logout();
    }
  }

  // ✅ Login
  Future<void> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _authService.login(
        username: username,
        password: password,
      );

      state = state.copyWith(
        user: result.user,
        token: result.token,
        isLoggedIn: true,
        isLoading: false,
      );

      print('✅ Login successful: ${result.user.username}');
    } catch (e) {
      state = state.copyWith(
        error: e.toString().replaceAll('Exception: ', ''),
        isLoading: false,
      );
      print('❌ Login failed: $e');
    }
  }

  // ✅ Register
  Future<void> register(String username, String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _authService.register(
        username: username,
        email: email,
        password: password,
      );

      state = state.copyWith(
        user: result.user,
        token: result.token,
        isLoggedIn: true,
        isLoading: false,
      );

      print('✅ Registration successful: ${result.user.username}');
    } catch (e) {
      state = state.copyWith(
        error: e.toString().replaceAll('Exception: ', ''),
        isLoading: false,
      );
      print('❌ Registration failed: $e');
    }
  }

  // ✅ Logout
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);

    try {
      await _authService.logout();
      print('✅ Logout successful');
    } finally {
      state = const AuthState();
    }
  }

  // ✅ Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  // ✅ Refresh user profile
  Future<void> refreshProfile() async {
    try {
      final user = await _authService.getProfile();
      state = state.copyWith(user: user);
    } catch (e) {
      print('❌ Profile refresh failed: $e');
      await logout();
    }
  }

  // ✅ Check auth status manually
  Future<void> checkAuthStatus() async {
    await _checkAuthStatus();
  }
}

// ✅ Auth Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});

// ✅ Convenience providers for easier access
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});

final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isLoggedIn;
});

final authLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isLoading;
});

final authErrorProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).error;
});
