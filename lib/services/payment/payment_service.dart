import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../models/response/payment/payment_create_response.dart';
import '../../models/response/payment/payment_status_response.dart';
import '../../utils/secure_storage.dart';

class PaymentService {
  static final String _baseUrl =
      dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080';

  /// Create a payment for an order
  static Future<PaymentCreateResponse?> createPayment(String orderId) async {
    try {
      final token = await SecureStorage.getAccessToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      print('PaymentService: Creating payment for order: $orderId');

      final response = await http.post(
        Uri.parse('$_baseUrl/api/payment/mobile/create/$orderId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print(
        'PaymentService: Create payment response status: ${response.statusCode}',
      );
      print('PaymentService: Create payment response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = jsonDecode(response.body);
        return PaymentCreateResponse.fromJson(jsonData);
      } else {
        print(
          'PaymentService: Failed to create payment - Status: ${response.statusCode}',
        );
        throw Exception('Failed to create payment: ${response.statusCode}');
      }
    } catch (e) {
      print('PaymentService: Error creating payment: $e');
      throw Exception('Error creating payment: $e');
    }
  }

  /// Check payment status for an order
  static Future<PaymentStatusResponse?> getPaymentStatus(String orderId) async {
    try {
      final token = await SecureStorage.getAccessToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      print('PaymentService: Checking payment status for order: $orderId');

      final response = await http.get(
        Uri.parse('$_baseUrl/api/payment/mobile/status/$orderId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print(
        'PaymentService: Payment status response status: ${response.statusCode}',
      );
      print('PaymentService: Payment status response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return PaymentStatusResponse.fromJson(jsonData);
      } else {
        print(
          'PaymentService: Failed to get payment status - Status: ${response.statusCode}',
        );
        throw Exception('Failed to get payment status: ${response.statusCode}');
      }
    } catch (e) {
      print('PaymentService: Error getting payment status: $e');
      throw Exception('Error getting payment status: $e');
    }
  }

  /// Format amount for display (e.g., "150,000 ₫")
  static String formatAmount(double amount, {String currency = '₫'}) {
    // Format number with thousand separators
    final formatter = amount.toStringAsFixed(0);
    final parts = <String>[];

    // Add thousand separators
    for (int i = formatter.length; i > 0; i -= 3) {
      final start = i - 3 < 0 ? 0 : i - 3;
      parts.insert(0, formatter.substring(start, i));
    }

    return '${parts.join(',')} $currency';
  }
}
