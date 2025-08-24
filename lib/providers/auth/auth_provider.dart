import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:zippy/models/entity/auth/user.dart';
import 'package:zippy/models/request/auth/login_request.dart';
import 'package:zippy/services/auth/auth_service.dart';
import 'package:zippy/state/auth/auth_state.dart';
import 'package:zippy/utils/secure_storage.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  bool _isRefreshing = false;
  bool _isInit = false;

  bool get isInit => _isInit;

  AuthNotifier() : super(const AuthState.unknown()) {
    checkAuth();
  }

  Future<void> checkAuth() async {
    if (_isInit) return; // Avoid re-initialization
    _isInit = true;
    final token = await SecureStorage.getAccessToken();
    if (token != null) {
      try {
        final valid = !JwtDecoder.isExpired(token);
        if (valid) {
          // Token is valid, extract user information
          final user = _extractUserFromJwt(token);
          state = AuthState.authenticated(user: user);
          return;
        } else {
          // Token is expired, try to refresh it
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
        }
      } catch (e) {
        state = AuthState.unauthenticated("Invalid token format");
      }
    }
    state = const AuthState.unauthenticated();
  }

  Future<void> login(LoginRequest data) async {
    state = const AuthState.loading();
    final statusCode = await AuthService.login(data);

    if (statusCode == 200) {
      // After successful login, get the token and extract user info
      final token = await SecureStorage.getAccessToken();
      if (token != null) {
        final user = _extractUserFromJwt(token);
        state = AuthState.authenticated(user: user);
      } else {
        state = const AuthState.authenticated();
      }
    } else if (statusCode == 403) {
      // Account needs verification
      state = const AuthState.unauthenticated("Account verification required");
      throw Exception("verification_required:${data.credential}");
    } else {
      state = const AuthState.unauthenticated("Invalid credentials");
    }
  }

  Future<void> logout() async {
    try {
      // Call server logout API and clear local tokens
      await AuthService.logout();
    } catch (e) {
      print('Error during logout: $e');
      // Ensure tokens are cleared even if logout fails
      await SecureStorage.clearTokens();
    }

    // Update state to unauthenticated
    state = const AuthState.unauthenticated();
  }

  /// Refresh the access token using the refresh token
  Future<bool> _refreshToken() async {
    try {
      if (_isRefreshing) {
        // Already refreshing, avoid duplicate calls
        while (_isRefreshing) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        return false;
      }
      _isRefreshing = true;
      // Call refresh token API
      final success = await AuthService.refreshAccessToken();
      _isRefreshing = false;

      if (success) {
        print('AuthNotifier: Token refreshed successfully');
        return true;
      } else {
        print(
          'AuthNotifier: Failed to refresh token - clearing tokens and logging out',
        );
        await SecureStorage.clearTokens();
        // Update state to unauthenticated to trigger login screen
        state = const AuthState.unauthenticated(
          "Session expired. Please log in again.",
        );
        return false;
      }
    } catch (e) {
      _isRefreshing = false;
      print('AuthNotifier: Error during token refresh: $e');
      await SecureStorage.clearTokens();
      // Update state to unauthenticated to trigger login screen
      state = const AuthState.unauthenticated(
        "Authentication error. Please log in again.",
      );
      return false;
    }
  }

  /// Force logout due to authentication failure
  Future<void> forceLogout([String? reason]) async {
    print(
      'AuthNotifier: Force logout triggered - ${reason ?? "Authentication failed"}',
    );

    try {
      // Try to logout from server, but don't wait for it
      AuthService.logout().catchError((e) {
        print('AuthNotifier: Server logout failed during force logout: $e');
        return false; // Return false to satisfy the Future<bool> return type
      });
    } catch (e) {
      print('AuthNotifier: Error during server logout: $e');
    }

    // Clear local tokens
    await SecureStorage.clearTokens();

    // Update state to unauthenticated to trigger login screen
    state = AuthState.unauthenticated(
      reason ?? "Session expired. Please log in again.",
    );
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
      final String? role = decodedToken['role'];

      return User(
        username: username,
        email: email,
        isVerified: isVerified,
        role: role,
      );
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
