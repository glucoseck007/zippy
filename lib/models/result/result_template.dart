class AuthResult {
  final bool success;
  final String message;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  AuthResult({
    required this.success,
    required this.message,
    required this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory AuthResult.success({
    String message = 'Operation successful',
    Map<String, dynamic> data = const {},
  }) {
    return AuthResult(
      success: true,
      message: message,
      data: data,
      timestamp: DateTime.now(),
    );
  }

  factory AuthResult.error({
    String message = 'Operation failed',
    Map<String, dynamic> data = const {},
  }) {
    return AuthResult(
      success: false,
      message: message,
      data: data,
      timestamp: DateTime.now(),
    );
  }

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] ?? {},
      timestamp: DateTime.parse(
        json['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}
