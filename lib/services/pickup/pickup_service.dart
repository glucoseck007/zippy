import 'dart:convert';
import 'package:zippy/services/api_client.dart';
import 'package:zippy/models/response/pickup/pickup_response.dart';

class PickupService {
  /// Send OTP via email after QR scan confirmation
  static Future<PickupResponse?> sendOtp(
    String orderCode,
    String tripCode,
  ) async {
    print(
      'PickupService: Sending OTP request for order: $orderCode, trip: $tripCode',
    );

    try {
      final requestBody = {'orderCode': orderCode, 'tripCode': tripCode};
      print('PickupService: Request body: $requestBody');

      final response = await ApiClient.post(
        '/order/pickup/send-otp',
        requestBody,
      );

      print('PickupService: Response status: ${response.statusCode}');
      print('PickupService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final pickupResponse = PickupResponse.fromJson(jsonData);
        print('PickupService: OTP send successful: ${pickupResponse.success}');
        return pickupResponse;
      }

      print(
        'PickupService: OTP send failed with status: ${response.statusCode}',
      );
      return PickupResponse(
        success: false,
        message: 'Failed to send OTP - Status: ${response.statusCode}',
        data: null,
      );
    } catch (e) {
      print('PickupService: OTP send error: $e');
      return PickupResponse(
        success: false,
        message: 'Network error: $e',
        data: null,
      );
    }
  }

  /// Resend OTP via email
  static Future<PickupResponse?> resendOtp(
    String orderCode,
    String tripCode,
  ) async {
    print(
      'PickupService: Resending OTP request for order: $orderCode, trip: $tripCode',
    );

    try {
      final requestBody = {'orderCode': orderCode, 'tripCode': tripCode};
      print('PickupService: Resend request body: $requestBody');

      final response = await ApiClient.post(
        '/order/pickup/resend-otp',
        requestBody,
      );

      print('PickupService: Resend response status: ${response.statusCode}');
      print('PickupService: Resend response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final pickupResponse = PickupResponse.fromJson(jsonData);
        print(
          'PickupService: OTP resend successful: ${pickupResponse.success}',
        );
        return pickupResponse;
      }

      print(
        'PickupService: OTP resend failed with status: ${response.statusCode}',
      );
      return PickupResponse(
        success: false,
        message: 'Failed to resend OTP - Status: ${response.statusCode}',
        data: null,
      );
    } catch (e) {
      print('PickupService: OTP resend error: $e');
      return PickupResponse(
        success: false,
        message: 'Network error: $e',
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
