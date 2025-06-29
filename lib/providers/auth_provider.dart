import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../models/entity/auth/user.dart';
import '../models/entity/auth/auth_tokens.dart';
import '../services/auth/auth_service.dart';
import '../services/auth/token_service.dart';

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
        _currentTokens = await TokenService.getTokens();

        // First try to get user from storage for fast initialization
        _currentUser = await AuthService.getCurrentUser();

        // If no user found in storage or it's incomplete, try to fetch or extract
        if (_currentUser == null && _currentTokens != null) {
          final userData = await fetchUserData();
          if (userData != null) {
            _currentUser = userData;
            await TokenService.saveUser(_currentUser!);
          }
        }

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
      _currentTokens = result.tokens;

      // Always attempt to get the most complete user information
      if (result.tokens != null) {
        // First check if login returned a user object
        if (result.user != null) {
          _currentUser = result.user;
          await TokenService.saveUser(_currentUser!);
        } else {
          // If no user object, fetch from server or extract from token
          final userData = await fetchUserData();
          if (userData != null) {
            _currentUser = userData;
            await TokenService.saveUser(_currentUser!);
          }
        }
      }

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
      if (result.isSuccess && result.tokens != null) {
        _currentTokens = result.tokens;

        // If user data is provided, update it
        if (result.user != null) {
          _currentUser = result.user;
        }
        // Otherwise, try to extract user from token if we don't have user data
        else if (_currentUser == null && result.tokens != null) {
          _currentUser = extractUserFromToken(result.tokens!.accessToken);

          // Save the extracted user to storage
          if (_currentUser != null) {
            await TokenService.saveUser(_currentUser!);
          }
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
      // Use our new helper method that tries server first, then token
      final user = await fetchUserData();

      if (user != null) {
        _currentUser = user;
        // Save the user data to storage for future use
        await TokenService.saveUser(user);
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

  /// Extract user information from JWT token
  User? extractUserFromToken(String token) {
    try {
      // Decode the JWT token
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);

      // Based on the server implementation, the token primarily contains:
      // - subject (username)
      // - issuedAt
      // - expiration
      // - and possibly some extra claims

      // Extract username from subject claim (this is the most important piece)
      final String? username = decodedToken['sub'];
      if (username == null || username.isEmpty) {
        debugPrint(
          'Token does not contain a valid username in the subject claim',
        );
        return null;
      }

      // Log token expiration for debugging
      if (decodedToken.containsKey('exp')) {
        final expDate = DateTime.fromMillisecondsSinceEpoch(
          decodedToken['exp'] * 1000,
        );
        debugPrint('Token expires on: $expDate');
      }

      // Get issued time if available
      final int? iat = decodedToken['iat']; // issued at timestamp

      // Check for any extra claims that might be present
      // In the future, the server might add more user information
      final Map<String, dynamic> extraClaims = Map.from(decodedToken);
      extraClaims.removeWhere(
        (key, _) =>
            ['sub', 'iat', 'exp', 'nbf', 'iss', 'aud', 'jti'].contains(key),
      );

      if (extraClaims.isNotEmpty) {
        debugPrint('Extra claims in token: ${extraClaims.keys}');
      }

      // Extract additional information if available
      final String? email = extraClaims['email'] ?? '$username@example.com';
      final String? firstName = extraClaims['firstName'] ?? '';
      final String? lastName = extraClaims['lastName'] ?? '';

      // Create a minimal User object with the username from the token
      // and placeholder values for required fields
      return User(
        id:
            extraClaims['id'] ??
            username, // Use username as ID if no ID is provided
        username: username,
        email:
            email ??
            '$username@example.com', // Provide a default email based on username
        firstName: firstName ?? '', // Empty string as default
        lastName: lastName ?? '', // Empty string as default
        isVerified: true, // Assume verified since they have a valid token
        createdAt: iat != null
            ? DateTime.fromMillisecondsSinceEpoch(iat * 1000)
            : DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error decoding JWT token: $e');
      return null;
    }
  }

  /// Refresh user information from the token
  Future<bool> refreshUserFromToken() async {
    if (_currentTokens == null) return false;

    try {
      // Extract user information from the current token
      final extractedUser = extractUserFromToken(_currentTokens!.accessToken);
      if (extractedUser != null) {
        _currentUser = extractedUser;
        await TokenService.saveUser(_currentUser!);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error refreshing user from token: $e');
      return false;
    }
  }

  /// Fetch user data from backend API or extract from token
  Future<User?> fetchUserData() async {
    if (_currentTokens == null) return null;

    try {
      // First, try to get user from a dedicated user profile endpoint
      final response = await _fetchUserProfileFromServer();

      if (response != null) {
        // If server profile endpoint is available, use that data
        return response;
      } else {
        // If no dedicated endpoint or it failed, extract from token
        debugPrint('Falling back to token extraction for user data');
        return extractUserFromToken(_currentTokens!.accessToken);
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      // As last resort, try token extraction
      return extractUserFromToken(_currentTokens!.accessToken);
    }
  }

  /// Private method to fetch user profile from server
  Future<User?> _fetchUserProfileFromServer() async {
    try {
      // Check if we have an access token
      final accessToken = _currentTokens?.accessToken;
      if (accessToken == null) return null;

      // Use the apiRequest helper for consistency
      final result = await AuthService.apiRequest(
        method: 'GET',
        endpoint: '/auth/profile',
        requiresAuth: true, // This will use the token from TokenService
      );

      // If successful and user data is available, return it
      if (result.isSuccess && result.user != null) {
        return result.user;
      }

      // Fallback to legacy getCurrentUser which might return cached data
      return await AuthService.getCurrentUser();
    } catch (e) {
      debugPrint('Error fetching user profile from server: $e');
      return null;
    }
  }
}
