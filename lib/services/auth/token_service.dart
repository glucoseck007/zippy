import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/entity/auth/auth_tokens.dart';
import '../../models/entity/auth/user.dart';

class TokenService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _accessTokenExpiryKey = 'access_token_expiry';
  static const String _refreshTokenExpiryKey = 'refresh_token_expiry';
  static const String _userDataKey = 'user_data';

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Save authentication tokens securely
  static Future<void> saveTokens(AuthTokens tokens) async {
    await Future.wait([
      _secureStorage.write(key: _accessTokenKey, value: tokens.accessToken),
      _secureStorage.write(key: _refreshTokenKey, value: tokens.refreshToken),
      _secureStorage.write(
        key: _accessTokenExpiryKey,
        value: tokens.accessTokenExpiry.toIso8601String(),
      ),
      _secureStorage.write(
        key: _refreshTokenExpiryKey,
        value: tokens.refreshTokenExpiry.toIso8601String(),
      ),
    ]);
  }

  /// Get stored authentication tokens
  static Future<AuthTokens?> getTokens() async {
    try {
      final results = await Future.wait([
        _secureStorage.read(key: _accessTokenKey),
        _secureStorage.read(key: _refreshTokenKey),
        _secureStorage.read(key: _accessTokenExpiryKey),
        _secureStorage.read(key: _refreshTokenExpiryKey),
      ]);

      final accessToken = results[0];
      final refreshToken = results[1];
      final accessTokenExpiry = results[2];
      final refreshTokenExpiry = results[3];

      if (accessToken == null ||
          refreshToken == null ||
          accessTokenExpiry == null ||
          refreshTokenExpiry == null) {
        return null;
      }

      return AuthTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        accessTokenExpiry: DateTime.parse(accessTokenExpiry),
        refreshTokenExpiry: DateTime.parse(refreshTokenExpiry),
      );
    } catch (e) {
      print('Error getting tokens: $e');
      return null;
    }
  }

  /// Save user data
  static Future<void> saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userDataKey, jsonEncode(user.toJson()));
  }

  /// Get stored user data
  static Future<User?> getUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString(_userDataKey);
      if (userData == null) return null;

      return User.fromJson(jsonDecode(userData));
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  /// Check if access token exists and is valid
  static Future<bool> hasValidAccessToken() async {
    final tokens = await getTokens();
    if (tokens == null) return false;
    return !tokens.isAccessTokenExpired;
  }

  /// Check if refresh token exists and is valid
  static Future<bool> hasValidRefreshToken() async {
    final tokens = await getTokens();
    if (tokens == null) return false;
    return !tokens.isRefreshTokenExpired;
  }

  /// Get access token if valid
  static Future<String?> getValidAccessToken() async {
    final tokens = await getTokens();
    if (tokens == null || tokens.isAccessTokenExpired) return null;
    return tokens.accessToken;
  }

  /// Get refresh token if valid
  static Future<String?> getValidRefreshToken() async {
    final tokens = await getTokens();
    if (tokens == null || tokens.isRefreshTokenExpired) return null;
    return tokens.refreshToken;
  }

  /// Clear all stored data
  static Future<void> clearAll() async {
    await Future.wait([
      _secureStorage.delete(key: _accessTokenKey),
      _secureStorage.delete(key: _refreshTokenKey),
      _secureStorage.delete(key: _accessTokenExpiryKey),
      _secureStorage.delete(key: _refreshTokenExpiryKey),
    ]);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userDataKey);
  }

  /// Clear only tokens (keep user data)
  static Future<void> clearTokens() async {
    await Future.wait([
      _secureStorage.delete(key: _accessTokenKey),
      _secureStorage.delete(key: _refreshTokenKey),
      _secureStorage.delete(key: _accessTokenExpiryKey),
      _secureStorage.delete(key: _refreshTokenExpiryKey),
    ]);
  }
}
