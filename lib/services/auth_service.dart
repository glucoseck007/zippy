import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/auth_tokens.dart';
import '../models/user.dart';
import 'token_service.dart';

/// Result class for authentication operations
class AuthResult {
  final bool isSuccess;
  final String? errorMessage;
  final String? successMessage;
  final User? user;
  final AuthTokens? tokens;
  final bool isVerificationError;

  AuthResult._({
    required this.isSuccess,
    this.errorMessage,
    this.successMessage,
    this.user,
    this.tokens,
    this.isVerificationError = false,
  });

  factory AuthResult.success({
    User? user,
    AuthTokens? tokens,
    String? message,
  }) {
    return AuthResult._(
      isSuccess: true,
      user: user,
      tokens: tokens,
      successMessage: message,
    );
  }

  factory AuthResult.error(String message, {bool isVerificationError = false}) {
    return AuthResult._(
      isSuccess: false,
      errorMessage: message,
      isVerificationError: isVerificationError,
    );
  }

  /// Get the appropriate message to display to user
  String? get message => isSuccess ? successMessage : errorMessage;
}

/// Custom exception for authentication errors
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}

class AuthService {
  static final String _baseUrl = dotenv.env['BACKEND_API_ENDPOINT'] ?? '';

  /// Login with email/username and password
  static Future<AuthResult> login({
    required String credential, // email or username
    required String password,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/auth/login');

      // Determine if credential is email or username
      final isEmail = RegExp(
        r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$",
      ).hasMatch(credential);

      final body = jsonEncode({
        if (isEmail) 'email': credential else 'username': credential,
        'password': password,
      });

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      final responseData = jsonDecode(response.body);

      switch (response.statusCode) {
        case 200:
          // Success
          final tokens = AuthTokens.fromJson(
            responseData['tokens'] ?? responseData,
          );
          final user = User.fromJson(responseData['user'] ?? responseData);

          // Save tokens and user data
          await TokenService.saveTokens(tokens);
          await TokenService.saveUser(user);

          return AuthResult.success(user: user, tokens: tokens);

        case 401:
          return AuthResult.error(
            responseData['message'] ?? 'Invalid credentials',
          );

        case 403:
          return AuthResult.error(
            responseData['message'] ?? 'Account not verified',
            isVerificationError: true,
          );

        case 500:
          return AuthResult.error(responseData['message'] ?? 'Server error');

        default:
          return AuthResult.error(responseData['message'] ?? 'Login failed');
      }
    } on SocketException {
      return AuthResult.error('No internet connection');
    } catch (e) {
      return AuthResult.error('An unexpected error occurred: $e');
    }
  }

  /// Refresh access token using refresh token
  static Future<AuthResult> refreshToken() async {
    try {
      final refreshToken = await TokenService.getValidRefreshToken();
      if (refreshToken == null) {
        return AuthResult.error('No valid refresh token available');
      }

      final uri = Uri.parse('$_baseUrl/auth/refresh');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $refreshToken',
        },
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final tokens = AuthTokens.fromJson(
          responseData['tokens'] ?? responseData,
        );
        await TokenService.saveTokens(tokens);

        // Get existing user data
        final user = await TokenService.getUser();

        return AuthResult.success(user: user, tokens: tokens);
      } else {
        // Refresh failed, clear all tokens
        await TokenService.clearTokens();
        return AuthResult.error(
          responseData['message'] ?? 'Token refresh failed',
        );
      }
    } catch (e) {
      await TokenService.clearTokens();
      return AuthResult.error('Token refresh failed: $e');
    }
  }

  /// Resend OTP for account verification
  static Future<AuthResult> resendOTP({
    required String credential, // email or username
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/auth/resend-otp');

      final response = await http.get(
        uri.replace(queryParameters: {'credential': credential}),
        headers: {'Content-Type': 'application/json'},
      );

      final responseData = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : <String, dynamic>{};

      if (response.statusCode == 200) {
        return AuthResult.success(
          message: responseData['message'] ?? 'OTP sent successfully',
        );
      } else {
        return AuthResult.error(
          responseData['message'] ?? 'Failed to resend OTP',
        );
      }
    } on SocketException {
      return AuthResult.error('No internet connection');
    } catch (e) {
      return AuthResult.error('Failed to resend OTP: $e');
    }
  }

  /// Register a new user account
  static Future<AuthResult> register({
    required String username,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
    required bool termsAccepted,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/auth/register');

      final body = jsonEncode({
        'username': username,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'password': password,
        'confirmPassword': confirmPassword,
        'termsAccepted': termsAccepted,
      });

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      final responseData = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : <String, dynamic>{};

      switch (response.statusCode) {
        case 201:
          return AuthResult.success(
            message: responseData['message'] ?? 'Registration successful',
          );
        case 403:
          return AuthResult.error(
            responseData['message'] ?? 'Account created but needs verification',
            isVerificationError: true,
          );
        case 401:
          return AuthResult.error(
            responseData['message'] ?? 'Email already exists',
          );
        case 500:
          return AuthResult.error(
            responseData['message'] ?? 'Server error occurred',
          );
        default:
          return AuthResult.error(
            responseData['message'] ?? 'Registration failed',
          );
      }
    } on SocketException {
      return AuthResult.error('No internet connection');
    } catch (e) {
      return AuthResult.error('Registration failed: $e');
    }
  }

  /// Verify OTP code for account verification
  static Future<AuthResult> verifyOTP({
    required String credential, // email or username
    required String otp,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/auth/verify-otp');

      final body = jsonEncode({'credential': credential, 'otp': otp});

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      final responseData = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : <String, dynamic>{};

      if (response.statusCode == 200) {
        return AuthResult.success(
          message: responseData['message'] ?? 'Verification successful',
        );
      } else {
        return AuthResult.error(
          responseData['message'] ?? 'Verification failed',
        );
      }
    } on SocketException {
      return AuthResult.error('No internet connection');
    } catch (e) {
      return AuthResult.error('Verification failed: $e');
    }
  }

  /// Send forgot password email
  static Future<AuthResult> forgotPassword({required String email}) async {
    try {
      final uri = Uri.parse('$_baseUrl/auth/forgot-password');

      final body = jsonEncode({'email': email});

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      final responseData = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : <String, dynamic>{};

      if (response.statusCode == 200) {
        return AuthResult.success(
          message: responseData['message'] ?? 'Password reset email sent',
        );
      } else {
        return AuthResult.error(
          responseData['message'] ?? 'Failed to send reset email',
        );
      }
    } on SocketException {
      return AuthResult.error('No internet connection');
    } catch (e) {
      return AuthResult.error('Failed to send reset email: $e');
    }
  }

  /// Get authenticated HTTP client with automatic token refresh
  static Future<http.Response> authenticatedRequest({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
    Map<String, String>? additionalHeaders,
  }) async {
    String? accessToken = await TokenService.getValidAccessToken();

    // Check if token needs refresh
    final tokens = await TokenService.getTokens();
    if (tokens != null && tokens.needsRefresh) {
      final refreshResult = await refreshToken();
      if (refreshResult.isSuccess) {
        accessToken = refreshResult.tokens?.accessToken;
      }
    }

    if (accessToken == null) {
      throw AuthException('No valid access token available');
    }

    final uri = Uri.parse('$_baseUrl$endpoint');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
      ...?additionalHeaders,
    };

    http.Response response;

    switch (method.toUpperCase()) {
      case 'GET':
        response = await http.get(uri, headers: headers);
        break;
      case 'POST':
        response = await http.post(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'PUT':
        response = await http.put(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: headers);
        break;
      case 'PATCH':
        response = await http.patch(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }

    // If unauthorized, try to refresh token once
    if (response.statusCode == 401) {
      final refreshResult = await refreshToken();
      if (refreshResult.isSuccess) {
        // Retry the request with new token
        final newHeaders = {
          ...headers,
          'Authorization': 'Bearer ${refreshResult.tokens!.accessToken}',
        };

        switch (method.toUpperCase()) {
          case 'GET':
            response = await http.get(uri, headers: newHeaders);
            break;
          case 'POST':
            response = await http.post(
              uri,
              headers: newHeaders,
              body: body != null ? jsonEncode(body) : null,
            );
            break;
          case 'PUT':
            response = await http.put(
              uri,
              headers: newHeaders,
              body: body != null ? jsonEncode(body) : null,
            );
            break;
          case 'DELETE':
            response = await http.delete(uri, headers: newHeaders);
            break;
          case 'PATCH':
            response = await http.patch(
              uri,
              headers: newHeaders,
              body: body != null ? jsonEncode(body) : null,
            );
            break;
        }
      }
    }

    return response;
  }

  /// Logout user
  static Future<void> logout() async {
    try {
      // Optionally call logout endpoint
      final refreshToken = await TokenService.getValidRefreshToken();
      if (refreshToken != null) {
        final uri = Uri.parse('$_baseUrl/auth/logout');
        await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $refreshToken',
          },
        );
      }
    } catch (e) {
      // Ignore logout endpoint errors
      debugPrint('Logout endpoint error: $e');
    } finally {
      // Always clear local data
      await TokenService.clearAll();
    }
  }

  /// Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    final hasValidAccess = await TokenService.hasValidAccessToken();
    if (hasValidAccess) return true;

    final hasValidRefresh = await TokenService.hasValidRefreshToken();
    if (hasValidRefresh) {
      final refreshResult = await refreshToken();
      return refreshResult.isSuccess;
    }

    return false;
  }

  /// Get current user from storage
  static Future<User?> getCurrentUser() async {
    return await TokenService.getUser();
  }

  /// Generate mock authentication for development purposes only
  static Future<AuthResult> mockAuthentication({
    String role = 'USER',
    String? username,
    String? email,
    String? firstName,
    String? lastName,
  }) async {
    // Create mock tokens with long expiration times
    final mockTokens = AuthTokens(
      accessToken: 'mock_access_token_${DateTime.now().millisecondsSinceEpoch}',
      refreshToken:
          'mock_refresh_token_${DateTime.now().millisecondsSinceEpoch}',
      accessTokenExpiry: DateTime.now().add(
        const Duration(days: 30),
      ), // Long expiration for development
      refreshTokenExpiry: DateTime.now().add(const Duration(days: 90)),
    );

    // Format username and email based on role
    String formattedUsername =
        username ?? (role.toLowerCase() == 'admin' ? 'admin_user' : 'dev_user');
    String formattedEmail =
        email ??
        (role.toLowerCase() == 'admin'
            ? 'admin@example.com'
            : 'dev@example.com');

    // Create a mock user
    final mockUser = User(
      id: 'mock_user_${DateTime.now().millisecondsSinceEpoch}',
      username: formattedUsername,
      email: formattedEmail,
      firstName:
          firstName ?? (role.toLowerCase() == 'admin' ? 'Admin' : 'Developer'),
      lastName: lastName ?? 'User',
      isVerified: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Save tokens and user data
    await TokenService.saveTokens(mockTokens);
    await TokenService.saveUser(mockUser);

    return AuthResult.success(
      user: mockUser,
      tokens: mockTokens,
      message: 'Development mock authentication successful',
    );
  }
}
