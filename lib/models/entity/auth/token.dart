class Token {
  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiry;
  final DateTime refreshTokenExpiry;

  Token({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiry,
    required this.refreshTokenExpiry,
  });

  factory Token.fromJson(Map<String, dynamic> json) {
    return Token(
      accessToken: json['accessToken'] ?? json['access_token'] ?? '',
      refreshToken: json['refreshToken'] ?? json['refresh_token'] ?? '',
      accessTokenExpiry: json['accessTokenExpiry'] != null
          ? DateTime.parse(json['accessTokenExpiry'])
          : DateTime.now().add(const Duration(hours: 1)), // Default 1 hour
      refreshTokenExpiry: json['refreshTokenExpiry'] != null
          ? DateTime.parse(json['refreshTokenExpiry'])
          : DateTime.now().add(const Duration(days: 7)), // Default 7 days
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'accessTokenExpiry': accessTokenExpiry.toIso8601String(),
      'refreshTokenExpiry': refreshTokenExpiry.toIso8601String(),
    };
  }

  bool get isAccessTokenExpired {
    return DateTime.now().isAfter(accessTokenExpiry);
  }

  bool get isRefreshTokenExpired {
    return DateTime.now().isAfter(refreshTokenExpiry);
  }

  bool get needsRefresh {
    // Refresh token if it expires within the next 5 minutes
    return DateTime.now().isAfter(
      accessTokenExpiry.subtract(const Duration(minutes: 5)),
    );
  }
}
