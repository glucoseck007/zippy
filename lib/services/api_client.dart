import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  static String baseUrl = dotenv.get('BACKEND_API_ENDPOINT');
  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
    String? token,
  }) async {
    final authHeaders = {
      if (token != null) 'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      ...?headers,
    };

    return await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: authHeaders,
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> get(
    String endpoint, {
    Map<String, String>? headers,
    String? token,
  }) async {
    final authHeaders = {
      if (token != null) 'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      ...?headers,
    };
    return await http.get(Uri.parse('$baseUrl$endpoint'), headers: authHeaders);
  }

  static Future<http.Response> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    String? token,
  }) async {
    final authHeaders = {
      if (token != null) 'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      ...?headers,
    };

    return await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: authHeaders,
      body: body != null ? jsonEncode(body) : null,
    );
  }
}
