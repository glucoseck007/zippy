import 'package:zippy/models/request/auth/login_request.dart';
import 'package:zippy/models/request/auth/register_request.dart';
import 'package:zippy/models/response/api_response.dart';
import 'package:zippy/models/response/auth/auth_response.dart';
import 'package:zippy/services/api_client.dart';
import 'package:zippy/utils/secure_storage.dart';

class AuthService {
  ///Login user with credential and password
  static Future<bool> login(LoginRequest data) async {
    final response = await ApiClient.post('/auth/login', {
      'credential': data.credential,
      'password': data.password,
    });

    if (response.statusCode == 200) {
      final responseData = ApiResponse.fromJson(response.body);
      final authData = AuthResponse.fromJson(responseData.data);
      await SecureStorage.saveTokens(
        authData.accessToken,
        authData.refreshToken,
      );
      return true;
    } else {
      // Optionally parse error response and show message
      return false;
    }
  }

  ///Register user with credential, password and user data
  ///Returns true if registration is successful
  static Future<bool> register(RegisterRequest userData) async {
    final response = await ApiClient.post('/auth/register', {
      'firstName': userData.firstName,
      'lastName': userData.lastName,
      'email': userData.email,
      'phone': userData.phone,
      'username': userData.username,
      'password': userData.password,
      'confirmPassword': userData.confirmPassword,
      'termsAccepted': userData.termsAccepted.toString(),
    });

    if (response.statusCode == 200) {
      final responseData = ApiResponse.fromJson(response.body);
      final authData = AuthResponse.fromJson(responseData.data);
      await SecureStorage.saveTokens(
        authData.accessToken,
        authData.refreshToken,
      );
      return true;
    } else {
      // Optionally parse error response and show message
      return false;
    }
  }

  ///Get refreshed access token using refresh token
  static Future<bool> refreshAccessToken() async {
    final refreshToken = await SecureStorage.getRefreshToken();
    if (refreshToken == null) return false;

    final response = await ApiClient.post('/auth/refresh-token', {
      'refreshToken': refreshToken,
    });

    if (response.statusCode == 200) {
      final responseData = ApiResponse.fromJson(response.body);
      final authData = AuthResponse.fromJson(responseData.data);
      await SecureStorage.saveTokens(
        authData.accessToken,
        authData.refreshToken,
      );
      return true;
    }

    await SecureStorage.clearTokens();
    return false;
  }
}
