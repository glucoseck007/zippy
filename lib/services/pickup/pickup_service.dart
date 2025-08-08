import 'dart:convert';
import 'package:zippy/services/api_client.dart';
import 'package:zippy/models/response/pickup/pickup_response.dart';

class PickupService {
  /// Send OTP via email after QR scan confirmation
  static Future<PickupResponse?> sendOtp(
    String orderCode,
    String tripCode,
  ) async {
    try {
      final response = await ApiClient.post('/order/pickup/send-otp', {
        'orderCode': orderCode,
        'tripCode': tripCode,
      });

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return PickupResponse.fromJson(jsonData);
      }

      return PickupResponse(
        success: false,
        message: 'Failed to send OTP',
        data: null,
      );
    } catch (e) {
      return PickupResponse(
        success: false,
        message: 'Network error',
        data: null,
      );
    }
  }

  /// Verify OTP and complete order pickup
  static Future<PickupResponse?> verifyOtpAndComplete(
    String orderCode,
    String otp,
    String tripCode,
  ) async {
    try {
      final response = await ApiClient.post('/order/pickup/verify-otp', {
        'orderCode': orderCode,
        'otp': otp,
        'tripCode': tripCode,
      });

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return PickupResponse.fromJson(jsonData);
      }

      return PickupResponse(
        success: false,
        message: 'Failed to verify OTP',
        data: null,
      );
    } catch (e) {
      return PickupResponse(
        success: false,
        message: 'Network error',
        data: null,
      );
    }
  }
}
