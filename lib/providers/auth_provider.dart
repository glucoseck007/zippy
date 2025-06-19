import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/auth/user.dart';
import '../models/auth/auth_tokens.dart';
import '../services/auth_service.dart';
import '../services/token_service.dart';

enum AuthState { unknown, authenticated, unauthenticated }

class AuthProvider with ChangeNotifier {
  AuthState _authState = AuthState.unknown;
  User? _currentUser;
  AuthTokens? _currentTokens;
  String? _lastError;

  // Getters
  AuthState get authState => _authState;
  User? get currentUser => _currentUser;
  AuthTokens? get currentTokens => _currentTokens;
  String? get lastError => _lastError;
  bool get isAuthenticated => _authState == AuthState.authenticated;
  bool get isLoading => _authState == AuthState.unknown;

  /// Initialize authentication state
  Future<void> initialize() async {
    try {
      final isAuth = await AuthService.isAuthenticated();
      if (isAuth) {
        _currentUser = await AuthService.getCurrentUser();
        _currentTokens = await TokenService.getTokens();
        _authState = AuthState.authenticated;
      } else {
        _authState = AuthState.unauthenticated;
      }
    } catch (e) {
      _authState = AuthState.unauthenticated;
      _lastError = e.toString();
    }
    notifyListeners();
  }

  /// Login with credentials
  Future<AuthResult> login({
    required String credential,
    required String password,
  }) async {
    _clearError();

    final result = await AuthService.login(
      credential: credential,
      password: password,
    );

    if (result.isSuccess) {
      _currentUser = result.user;
      _currentTokens = result.tokens;
      _authState = AuthState.authenticated;
    } else {
      _lastError = result.errorMessage;
      _authState = AuthState.unauthenticated;
    }

    notifyListeners();
    return result;
  }

  /// Resend OTP for account verification
  Future<AuthResult> resendOTP({required String credential}) async {
    _clearError();

    final result = await AuthService.resendOTP(credential: credential);

    if (!result.isSuccess) {
      _lastError = result.errorMessage;
      notifyListeners();
    }

    return result;
  }

  /// Register a new user account
  Future<AuthResult> register({
    required String username,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
    required bool termsAccepted,
  }) async {
    _clearError();

    final result = await AuthService.register(
      username: username,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      password: password,
      confirmPassword: confirmPassword,
      termsAccepted: termsAccepted,
    );

    if (!result.isSuccess) {
      _lastError = result.errorMessage;
      notifyListeners();
    }

    return result;
  }

  /// Verify OTP code for account verification
  Future<AuthResult> verifyOTP({
    required String credential,
    required String otp,
  }) async {
    _clearError();

    final result = await AuthService.verifyOTP(
      credential: credential,
      otp: otp,
    );

    if (!result.isSuccess) {
      _lastError = result.errorMessage;
      notifyListeners();
    }

    return result;
  }

  /// Send forgot password email
  Future<AuthResult> forgotPassword({required String email}) async {
    _clearError();

    final result = await AuthService.forgotPassword(email: email);

    if (!result.isSuccess) {
      _lastError = result.errorMessage;
      notifyListeners();
    }

    return result;
  }

  /// Refresh authentication tokens
  Future<bool> refreshTokens() async {
    try {
      final result = await AuthService.refreshToken();
      if (result.isSuccess) {
        _currentTokens = result.tokens;
        // User data might be updated, but typically stays the same
        if (result.user != null) {
          _currentUser = result.user;
        }
        _authState = AuthState.authenticated;
        notifyListeners();
        return true;
      } else {
        // Refresh failed, user needs to login again
        await logout();
        return false;
      }
    } catch (e) {
      _lastError = e.toString();
      await logout();
      return false;
    }
  }

  /// Logout user
  Future<void> logout() async {
    await AuthService.logout();
    _currentUser = null;
    _currentTokens = null;
    _authState = AuthState.unauthenticated;
    _clearError();
    notifyListeners();
  }

  /// Update user profile data
  void updateUser(User user) {
    _currentUser = user;
    // Save updated user data
    TokenService.saveUser(user);
    notifyListeners();
  }

  /// Check if access token is still valid
  bool get hasValidAccessToken {
    if (_currentTokens == null) return false;
    return !_currentTokens!.isAccessTokenExpired;
  }

  /// Check if refresh token is still valid
  bool get hasValidRefreshToken {
    if (_currentTokens == null) return false;
    return !_currentTokens!.isRefreshTokenExpired;
  }

  /// Check if token needs refresh (expires soon)
  bool get needsTokenRefresh {
    if (_currentTokens == null) return false;
    return _currentTokens!.needsRefresh;
  }

  /// Get valid access token, refreshing if necessary
  Future<String?> getValidAccessToken() async {
    if (_currentTokens == null) return null;

    // If token is expired or needs refresh, try to refresh
    if (_currentTokens!.isAccessTokenExpired || _currentTokens!.needsRefresh) {
      final refreshed = await refreshTokens();
      if (!refreshed) return null;
    }

    return _currentTokens?.accessToken;
  }

  /// Clear error message
  void _clearError() {
    _lastError = null;
  }

  /// Clear error message (public method)
  void clearError() {
    _clearError();
    notifyListeners();
  }

  /// Force refresh user data from server
  Future<bool> refreshUserData() async {
    try {
      // This would typically call an API endpoint to get fresh user data
      // For now, we'll just return the cached user data
      final user = await AuthService.getCurrentUser();
      if (user != null) {
        _currentUser = user;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Development-only method to set mock authentication
  /// WARNING: This should only be used during development
  Future<void> setMockAuthentication({
    String role = 'USER',
    String? username,
    String? email,
    String? firstName,
    String? lastName,
  }) async {
    assert(() {
      // This assertion only runs in debug mode
      debugPrint('⚠️ DEVELOPER MODE: Using mock authentication');
      return true;
    }());

    final result = await AuthService.mockAuthentication(
      role: role,
      username: username,
      email: email,
      firstName: firstName,
      lastName: lastName,
    );

    if (result.isSuccess) {
      _currentUser = result.user;
      _currentTokens = result.tokens;
      _authState = AuthState.authenticated;
      _clearError();
      notifyListeners();
    }
  }
}
