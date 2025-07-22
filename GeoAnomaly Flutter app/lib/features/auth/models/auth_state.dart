import 'user_model.dart';

class AuthState {
  final bool isLoading;
  final bool isLoggedIn;
  final User? user;
  final String? token;
  final String? error;

  AuthState({
    required this.isLoading,
    required this.isLoggedIn,
    this.user,
    this.token,
    this.error,
  });

  factory AuthState.initial() {
    return AuthState(
      isLoading: false,
      isLoggedIn: false,
      user: null,
      token: null,
      error: null,
    );
  }

  AuthState copyWith({
    bool? isLoading,
    bool? isLoggedIn,
    User? user,
    String? token,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      user: user ?? this.user,
      token: token ?? this.token,
      error: error ?? this.error,
    );
  }
}
