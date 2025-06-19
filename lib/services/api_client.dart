import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';

/// HTTP client wrapper that handles authentication automatically
class ApiClient {
  /// GET request with authentication
  static Future<http.Response> get(
    String endpoint, {
    Map<String, String>? additionalHeaders,
  }) async {
    return await AuthService.authenticatedRequest(
      method: 'GET',
      endpoint: endpoint,
      additionalHeaders: additionalHeaders,
    );
  }

  /// POST request with authentication
  static Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? additionalHeaders,
  }) async {
    return await AuthService.authenticatedRequest(
      method: 'POST',
      endpoint: endpoint,
      body: body,
      additionalHeaders: additionalHeaders,
    );
  }

  /// PUT request with authentication
  static Future<http.Response> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? additionalHeaders,
  }) async {
    return await AuthService.authenticatedRequest(
      method: 'PUT',
      endpoint: endpoint,
      body: body,
      additionalHeaders: additionalHeaders,
    );
  }

  /// PATCH request with authentication
  static Future<http.Response> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? additionalHeaders,
  }) async {
    return await AuthService.authenticatedRequest(
      method: 'PATCH',
      endpoint: endpoint,
      body: body,
      additionalHeaders: additionalHeaders,
    );
  }

  /// DELETE request with authentication
  static Future<http.Response> delete(
    String endpoint, {
    Map<String, String>? additionalHeaders,
  }) async {
    return await AuthService.authenticatedRequest(
      method: 'DELETE',
      endpoint: endpoint,
      additionalHeaders: additionalHeaders,
    );
  }

  /// Handle API response and extract data
  static Map<String, dynamic> handleResponse(http.Response response) {
    final responseData = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseData;
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: responseData['message'] ?? 'API request failed',
        data: responseData,
      );
    }
  }

  /// Handle API response and return success status
  static bool isSuccessResponse(http.Response response) {
    return response.statusCode >= 200 && response.statusCode < 300;
  }
}

/// Custom exception for API errors
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? data;

  ApiException({required this.statusCode, required this.message, this.data});

  @override
  String toString() {
    return 'ApiException($statusCode): $message';
  }

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => statusCode >= 500;
}
