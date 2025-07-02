import 'dart:convert';

class ApiResponse<T> {
  final bool success;
  final String message;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  ApiResponse({
    required this.success,
    required this.message,
    required this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ApiResponse.success({
    String message = 'Operation successful',
    Map<String, dynamic> data = const {},
  }) {
    return ApiResponse(
      success: true,
      message: message,
      data: data,
      timestamp: DateTime.now(),
    );
  }

  factory ApiResponse.error({
    String message = 'Operation failed',
    Map<String, dynamic> data = const {},
  }) {
    return ApiResponse(
      success: false,
      message: message,
      data: data,
      timestamp: DateTime.now(),
    );
  }

  factory ApiResponse.fromJson(String responseBody) {
    final Map<String, dynamic> json = jsonDecode(responseBody);
    return ApiResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] ?? {},
      timestamp: DateTime.parse(
        json['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}
