import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../../models/entity/auth/auth_tokens.dart';
import '../../models/entity/auth/user.dart';
import '../../models/result/auth/auth_result.dart' as ar;
import '../../models/result/result_template.dart' as rt;
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

  static Future<AuthResult> login({
    required String credential, // email or username
    required String password,
  }) async {
    try {
      // Determine if credential is email or username
      final isEmail = RegExp(
        r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$",
      ).hasMatch(credential);

      final requestBody = {
        if (isEmail) 'email': credential else 'username': credential,
        'password': password,
      };

      // Use our apiRequest helper method
      final result = await apiRequest(
        method: 'POST',
        endpoint: '/auth/login',
        body: requestBody,
        requiresAuth: false,
        isAuthRequest: true,
      );

      return result;
    } catch (e) {
      return AuthResult.error('Login failed: $e');
    }
  }

  /// Refresh token using the new API helpers
  static Future<AuthResult> refreshToken() async {
    try {
      final refreshToken = await TokenService.getValidRefreshToken();
      if (refreshToken == null) {
        return AuthResult.error('No valid refresh token available');
      }

      // Use our apiRequest helper method
      final result = await apiRequest(
        method: 'POST',
        endpoint: '/auth/refresh-token',
        headers: {'Authorization': 'Bearer $refreshToken'},
        requiresAuth: false, // We're providing the token manually
        isAuthRequest: true,
      );

      // If successful, update stored tokens
      if (result.isSuccess && result.tokens != null) {
        await TokenService.saveTokens(result.tokens!);
      } else {
        // Clear tokens if refresh failed
        await TokenService.clearTokens();
      }

      return result;
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
      // Use the apiRequest helper method instead of direct HTTP calls
      return await apiRequest(
        method: 'GET',
        endpoint: '/auth/resend-otp',
        // Pass the query parameter
        headers: {
          'X-Query-Credential': credential,
        }, // We'll handle this in _executeHttpRequest
        requiresAuth: false,
      );
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
      // Prepare request body
      final requestBody = {
        'username': username,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'password': password,
        'confirmPassword': confirmPassword,
        'termsAccepted': termsAccepted,
      };

      // Use our apiRequest helper method
      return await apiRequest(
        method: 'POST',
        endpoint: '/auth/register',
        body: requestBody,
        requiresAuth: false,
      );
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
      // Prepare request body
      final requestBody = {'credential': credential, 'otp': otp};

      // Use our apiRequest helper method
      return await apiRequest(
        method: 'POST',
        endpoint: '/auth/verify-otp',
        body: requestBody,
        requiresAuth: false,
      );
    } catch (e) {
      return AuthResult.error('Verification failed: $e');
    }
  }

  /// Send forgot password email
  static Future<AuthResult> forgotPassword({required String email}) async {
    try {
      // Prepare request body
      final requestBody = {'email': email};

      // Use our apiRequest helper method
      return await apiRequest(
        method: 'POST',
        endpoint: '/auth/forgot-password',
        body: requestBody,
        requiresAuth: false,
      );
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
    var headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
      ...?additionalHeaders,
    };

    // Extract query parameters if they exist in the headers
    Map<String, dynamic>? queryParams;
    if (headers.containsKey('X-Query-Credential')) {
      queryParams = {'credential': headers['X-Query-Credential']};
      headers = Map.from(headers)..remove('X-Query-Credential');
    }

    // Execute the HTTP request using our helper method
    http.Response response = await _executeHttpRequest(
      method: method,
      uri: uri,
      headers: headers,
      body: body,
      queryParams: queryParams,
    );

    // If unauthorized, try to refresh token once
    if (response.statusCode == 401) {
      final refreshResult = await refreshToken();
      if (refreshResult.isSuccess) {
        // Retry the request with new token
        final newHeaders = {
          ...headers,
          'Authorization': 'Bearer ${refreshResult.tokens!.accessToken}',
        };

        // Use the helper method again for the retry with new token
        response = await _executeHttpRequest(
          method: method,
          uri: uri,
          headers: newHeaders,
          body: body,
          queryParams: queryParams,
        );
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

  /// Process API response using the new result templates
  static Future<AuthResult> processAuthResponse(http.Response response) async {
    try {
      final responseData = jsonDecode(response.body);

      // Create a result template from the response
      final resultTemplate = rt.AuthResult.fromJson(responseData);

      if (response.statusCode == 200 && resultTemplate.success) {
        // If we have tokens in the data object
        if (resultTemplate.data.containsKey('accessToken') &&
            resultTemplate.data.containsKey('refreshToken')) {
          // Extract using the auth_result.dart model
          final authResultTokens = ar.AuthResult(
            accessToken: resultTemplate.data['accessToken'],
            refreshToken: resultTemplate.data['refreshToken'],
          );

          // Convert to our AuthTokens model
          final tokens = AuthTokens(
            accessToken: authResultTokens.accessToken,
            refreshToken: authResultTokens.refreshToken,
            accessTokenExpiry: DateTime.now().add(const Duration(hours: 1)),
            refreshTokenExpiry: DateTime.now().add(const Duration(days: 7)),
          );

          // Check if verification is required
          final verificationRequired =
              resultTemplate.data['verificationRequired'] == true;
          if (verificationRequired) {
            return AuthResult.error(
              'Account verification required',
              isVerificationError: true,
            );
          }

          // Fetch user profile in a separate call or from data if available
          User? user;
          if (resultTemplate.data.containsKey('user')) {
            user = User.fromJson(resultTemplate.data['user']);
          } else {
            user = await _fetchUserProfile(tokens.accessToken);
          }

          // Save tokens and user data
          await TokenService.saveTokens(tokens);
          if (user != null) {
            await TokenService.saveUser(user);
          }

          return AuthResult.success(
            user: user,
            tokens: tokens,
            message: resultTemplate.message,
          );
        }
      }

      // Handle error cases
      return AuthResult.error(resultTemplate.message);
    } catch (e) {
      debugPrint('Error processing auth response: $e');
      return AuthResult.error('Failed to process authentication response');
    }
  }

  /// Fetch user profile using access token
  static Future<User?> _fetchUserProfile(String accessToken) async {
    try {
      final uri = Uri.parse('$_baseUrl/auth/profile');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Check if response follows the new format
        if (responseData['success'] == true && responseData['data'] != null) {
          // Extract user data from the 'data' object
          final userData = responseData['data'];
          return User.fromJson(userData);
        } else {
          // Try to parse the direct response or extract from 'user' field
          return User.fromJson(responseData['user'] ?? responseData);
        }
      }

      debugPrint('Failed to fetch user profile: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      return null;
    }
  }

  /// Helper method to execute HTTP requests with different methods
  static Future<http.Response> _executeHttpRequest({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
  }) async {
    // Handle custom headers that might contain query parameters
    Map<String, String> requestHeaders = {...headers};
    Map<String, dynamic> queryParameters = {...?queryParams};

    // Check for special header X-Query-Credential which we'll convert to a query parameter
    if (requestHeaders.containsKey('X-Query-Credential')) {
      queryParameters['credential'] = requestHeaders['X-Query-Credential'];
      requestHeaders.remove('X-Query-Credential');
    }

    // Apply query parameters if provided
    Uri requestUri = queryParameters.isNotEmpty
        ? uri.replace(
            queryParameters: queryParameters.map(
              (key, value) => MapEntry(key, value.toString()),
            ),
          )
        : uri;

    switch (method.toUpperCase()) {
      case 'GET':
        return await http.get(requestUri, headers: requestHeaders);

      case 'POST':
        return await http.post(
          requestUri,
          headers: requestHeaders,
          body: body != null ? jsonEncode(body) : null,
        );

      case 'PUT':
        return await http.put(
          requestUri,
          headers: requestHeaders,
          body: body != null ? jsonEncode(body) : null,
        );

      case 'DELETE':
        return await http.delete(requestUri, headers: requestHeaders);

      case 'PATCH':
        return await http.patch(
          requestUri,
          headers: requestHeaders,
          body: body != null ? jsonEncode(body) : null,
        );

      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }
  }

  /// Helper method to handle HTTP status codes and return appropriate AuthResult
  static Future<AuthResult> handleHttpResponse(
    http.Response response, {
    bool isAuthentication = false,
  }) async {
    final responseData = jsonDecode(response.body);

    // Check if this is the new API format with success/message/data structure
    if (isAuthentication &&
        response.statusCode == 200 &&
        responseData['success'] != null &&
        responseData['data'] != null) {
      return processAuthResponse(response);
    }

    switch (response.statusCode) {
      case 200:
      case 201:
        // Try to extract user data if available in the response
        User? user;

        // Check for user data in different potential locations
        if (responseData['data'] != null && responseData['data'] is Map) {
          // If it has user data inside data object
          if (responseData['data']['user'] != null) {
            user = User.fromJson(responseData['data']['user']);
          }
          // If the data object itself is the user
          else if (responseData['data'].containsKey('username') ||
              responseData['data'].containsKey('email')) {
            user = User.fromJson(responseData['data']);
          }
        }
        // If user data is directly in the response
        else if (responseData['user'] != null) {
          user = User.fromJson(responseData['user']);
        }
        // If the response itself might be the user object
        else if (responseData.containsKey('username') ||
            responseData.containsKey('email')) {
          user = User.fromJson(responseData);
        }

        return AuthResult.success(
          message: responseData['message'] ?? 'Operation successful',
          user: user,
        );

      case 400:
        return AuthResult.error(responseData['message'] ?? 'Bad request');

      case 401:
        return AuthResult.error(
          responseData['message'] ?? 'Unauthorized access',
        );

      case 403:
        return AuthResult.error(
          responseData['message'] ?? 'Access forbidden',
          isVerificationError: responseData['verificationRequired'] == true,
        );

      case 404:
        return AuthResult.error(
          responseData['message'] ?? 'Resource not found',
        );

      case 500:
      case 502:
      case 503:
        return AuthResult.error(
          responseData['message'] ?? 'Server error occurred',
        );

      default:
        return AuthResult.error(
          responseData['message'] ??
              'Operation failed with status: ${response.statusCode}',
        );
    }
  }

  /// General-purpose method for making API requests with proper error handling
  static Future<AuthResult> apiRequest({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool requiresAuth = true,
    bool isAuthRequest = false,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');

      Map<String, String> requestHeaders = {
        'Content-Type': 'application/json',
        ...?headers,
      };

      // Add auth header if required
      if (requiresAuth) {
        final accessToken = await TokenService.getValidAccessToken();
        if (accessToken == null) {
          // Try to refresh token
          final refreshResult = await refreshToken();
          if (!refreshResult.isSuccess) {
            return AuthResult.error('Authentication required');
          }
          requestHeaders['Authorization'] =
              'Bearer ${refreshResult.tokens!.accessToken}';
        } else {
          requestHeaders['Authorization'] = 'Bearer $accessToken';
        }
      }

      // Extract query parameters if they exist in the headers
      Map<String, dynamic>? queryParams;
      if (requestHeaders.containsKey('X-Query-Credential')) {
        queryParams = {'credential': requestHeaders['X-Query-Credential']};
      }

      // Execute the HTTP request
      final response = await _executeHttpRequest(
        method: method,
        uri: uri,
        headers: requestHeaders,
        body: body,
        queryParams: queryParams,
      );

      // Handle 401 with token refresh if authenticated request
      if (requiresAuth && response.statusCode == 401) {
        final refreshResult = await refreshToken();
        if (refreshResult.isSuccess) {
          requestHeaders['Authorization'] =
              'Bearer ${refreshResult.tokens!.accessToken}';

          // Retry the request
          final retryResponse = await _executeHttpRequest(
            method: method,
            uri: uri,
            headers: requestHeaders,
            body: body,
            queryParams: queryParams,
          );

          return handleHttpResponse(
            retryResponse,
            isAuthentication: isAuthRequest,
          );
        }
        // If refresh fails, return unauthorized error
        return AuthResult.error('Session expired. Please log in again.');
      }

      // Handle the response
      return handleHttpResponse(response, isAuthentication: isAuthRequest);
    } on SocketException {
      return AuthResult.error('No internet connection');
    } catch (e) {
      return AuthResult.error('Request failed: $e');
    }
  }
}
