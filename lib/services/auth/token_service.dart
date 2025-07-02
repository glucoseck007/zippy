import 'package:zippy/utils/secure_storage.dart';

class TokenService {
  /// Saves the access and refresh tokens to secure storage.
  static Future<void> saveTokens(
    String accessToken,
    String refreshToken,
  ) async {
    await SecureStorage.saveTokens(accessToken, refreshToken);
  }

  /// Retrieves the access token from secure storage.
  static Future<String?> getAccessToken() async {
    return await SecureStorage.getAccessToken();
  }

  /// Retrieves the refresh token from secure storage.
  static Future<String?> getRefreshToken() async {
    return await SecureStorage.getRefreshToken();
  }

  /// Deletes both access and refresh tokens from secure storage.
  static Future<void> clearTokens() async {
    await SecureStorage.clearTokens();
  }
}
