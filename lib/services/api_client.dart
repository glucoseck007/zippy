import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:zippy/utils/secure_storage.dart';
import 'package:zippy/services/auth/auth_service.dart';

class ApiClient {
  static String baseUrl = dotenv.get('BACKEND_API_ENDPOINT');

  // Helper method to get fresh token and headers
  static Future<Map<String, String>> _getHeaders([
    Map<String, String>? additionalHeaders,
  ]) async {
    String? token;
    try {
      token = await SecureStorage.getAccessToken();
      // Debug logging for token retrieval
      if (token != null) {
        print(
          'ApiClient: Token retrieved successfully (length: ${token.length})',
        );
      } else {
        print('ApiClient: No token found in secure storage');
      }
    } catch (e) {
      print('ApiClient: Error retrieving token: $e');
      token = null;
    }

    return {
      if (token != null) 'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      ...?additionalHeaders,
    };
  }

  // Helper method to handle token refresh and retry
  static Future<http.Response> _handleTokenRefreshAndRetry(
    Future<http.Response> Function() apiCall,
  ) async {
    final response = await apiCall();

    // If unauthorized, try to refresh token and retry once
    if (response.statusCode == 401 || response.statusCode == 403) {
      print('ApiClient: Received 401, attempting token refresh...');

      final refreshSuccess = await AuthService.refreshAccessToken();
      if (refreshSuccess) {
        print('ApiClient: Token refreshed, retrying request...');
        // Retry the original request with new token
        return await apiCall();
      } else {
        print('ApiClient: Token refresh failed');
      }
    }

    return response;
  }

  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    return await _handleTokenRefreshAndRetry(() async {
      final authHeaders = await _getHeaders(headers);
      return await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: authHeaders,
        body: jsonEncode(body),
      );
    });
  }

  static Future<http.Response> refreshTokenPost(
    String endpoint,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    return await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: {'Content-Type': 'application/json', ...?headers},
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> get(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    return await _handleTokenRefreshAndRetry(() async {
      final authHeaders = await _getHeaders(headers);
      return await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: authHeaders,
      );
    });
  }

  static Future<http.Response> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    return await _handleTokenRefreshAndRetry(() async {
      final authHeaders = await _getHeaders(headers);
      return await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: authHeaders,
        body: body != null ? jsonEncode(body) : null,
      );
    });
  }
}
