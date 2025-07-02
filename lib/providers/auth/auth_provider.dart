import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:zippy/models/entity/auth/user.dart';
import 'package:zippy/models/request/auth/login_request.dart';
import 'package:zippy/services/auth/auth_service.dart';
import 'package:zippy/state/auth/auth_state.dart';
import 'package:zippy/utils/secure_storage.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState.unknown()) {
    checkAuth();
  }

  Future<void> checkAuth() async {
    final token = await SecureStorage.getAccessToken();
    if (token != null) {
      final valid = !JwtDecoder.isExpired(token);
      if (valid) {
        // Extract user information from JWT
        final user = _extractUserFromJwt(token);
        state = AuthState.authenticated(user: user);
        return;
      }
    }
    state = const AuthState.unauthenticated();
  }

  Future<void> login(LoginRequest data) async {
    state = const AuthState.loading();
    final success = await AuthService.login(data);
    if (success) {
      // After successful login, get the token and extract user info
      final token = await SecureStorage.getAccessToken();
      if (token != null) {
        final user = _extractUserFromJwt(token);
        state = AuthState.authenticated(user: user);
      } else {
        state = const AuthState.authenticated();
      }
    } else {
      state = const AuthState.unauthenticated("Invalid credentials");
    }
  }

  Future<void> logout() async {
    await SecureStorage.clearTokens();
    state = const AuthState.unauthenticated();
  }

  /// Extract user information from JWT token
  User? _extractUserFromJwt(String token) {
    try {
      // Decode the JWT payload
      final Map<String, dynamic> decodedToken = JwtDecoder.decode(token);

      // Extract user information from the 'sub' (subject) field
      final String? username = decodedToken['sub'];
      if (username == null) return null;

      return User(username: username);
    } catch (e) {
      // If there's an error decoding, log it and return null
      print('Error extracting user from JWT: $e');
      return null;
    }
  }

  /// Get current user
  User? get currentUser => state.user;

  /// Check if user is authenticated
  bool get isAuthenticated => state.isAuthenticated;
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

// Convenient provider to access current user directly
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authProvider);
  return authState.user;
});
