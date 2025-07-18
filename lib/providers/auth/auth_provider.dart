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
        // Token is valid, extract user information
        final user = _extractUserFromJwt(token);
        state = AuthState.authenticated(user: user);
        return;
      } else {
        // Token is expired, try to refresh it
        print('Access token expired, attempting to refresh...');
        final refreshSuccess = await _refreshToken();
        if (refreshSuccess) {
          // Successfully refreshed, extract user from new token
          final newToken = await SecureStorage.getAccessToken();
          if (newToken != null) {
            final user = _extractUserFromJwt(newToken);
            state = AuthState.authenticated(user: user);
            return;
          }
        }
        // Refresh failed, user needs to log in again
        print('Token refresh failed, user needs to log in again');
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

  /// Refresh the access token using the refresh token
  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await SecureStorage.getRefreshToken();
      if (refreshToken == null) {
        print('No refresh token found');
        return false;
      }

      // Check if refresh token is expired
      if (JwtDecoder.isExpired(refreshToken)) {
        print('Refresh token is expired');
        await SecureStorage.clearTokens();
        return false;
      }

      // Call refresh token API
      final success = await AuthService.refreshAccessToken();
      if (success) {
        print('Token refreshed successfully');
        return true;
      } else {
        print('Failed to refresh token');
        await SecureStorage.clearTokens();
        return false;
      }
    } catch (e) {
      print('Error during token refresh: $e');
      await SecureStorage.clearTokens();
      return false;
    }
  }

  /// Extract user information from JWT token
  User? _extractUserFromJwt(String token) {
    try {
      // Decode the JWT payload
      final Map<String, dynamic> decodedToken = JwtDecoder.decode(token);

      print('JWT payload: $decodedToken'); // Debug log

      // Extract user information from the token
      // The 'sub' field typically contains the username or user ID
      final String? username = decodedToken['sub'];
      if (username == null) return null;

      // Extract additional user information from JWT claims
      final String? email = decodedToken['email'];
      final bool? isVerified =
          decodedToken['isVerified'] ?? decodedToken['email_verified'];

      return User(username: username, email: email, isVerified: isVerified);
    } catch (e) {
      // If there's an error decoding, log it and return null
      print('Error extracting user from JWT: $e');
      return null;
    }
  }

  /// Public method to manually refresh token
  Future<bool> refreshToken() async {
    final success = await _refreshToken();
    if (success) {
      // Update auth state with new token
      final newToken = await SecureStorage.getAccessToken();
      if (newToken != null) {
        final user = _extractUserFromJwt(newToken);
        state = AuthState.authenticated(user: user);
      }
    }
    return success;
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
