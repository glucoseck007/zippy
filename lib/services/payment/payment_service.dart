import 'dart:convert';

import '../../models/response/payment/payment_create_response.dart';
import '../../models/response/payment/payment_status_response.dart';
import '../api_client.dart';

class PaymentService {
  /// Create a payment for an order
  static Future<PaymentCreateResponse?> createPayment(String orderId) async {
    try {
      print('PaymentService: Creating payment for order: $orderId');

      final response = await ApiClient.post(
        '/payment/mobile/create/$orderId',
        {},
      );

      print(
        'PaymentService: Create payment response status: ${response.statusCode}',
      );
      print('PaymentService: Create payment response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = jsonDecode(response.body);
        print('PaymentService: Parsed JSON data: $jsonData');

        // Check if response has the expected structure
        if (jsonData is Map<String, dynamic>) {
          try {
            // Check if this is a wrapped API response
            if (jsonData.containsKey('success') &&
                jsonData.containsKey('data')) {
              final apiResponse = jsonData;
              if (apiResponse['success'] == true &&
                  apiResponse['data'] != null) {
                final paymentData = apiResponse['data'] as Map<String, dynamic>;
                print(
                  'PaymentService: Payment data from API response: $paymentData',
                );
                final paymentResponse = PaymentCreateResponse.fromJson(
                  paymentData,
                );
                print(
                  'PaymentService: Successfully created PaymentCreateResponse: $paymentResponse',
                );
                return paymentResponse;
              } else {
                throw Exception(
                  'API request failed: ${apiResponse['message'] ?? 'Unknown error'}',
                );
              }
            } else {
              // Direct payment response (fallback)
              final paymentResponse = PaymentCreateResponse.fromJson(jsonData);
              print(
                'PaymentService: Successfully created PaymentCreateResponse: $paymentResponse',
              );
              return paymentResponse;
            }
          } catch (e) {
            print('PaymentService: Error parsing PaymentCreateResponse: $e');
            print('PaymentService: JSON data that caused the error: $jsonData');
            throw Exception('Error parsing payment response: $e');
          }
        } else {
          print(
            'PaymentService: Response is not a Map<String, dynamic>: $jsonData',
          );
          throw Exception('Invalid response format from server');
        }
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
      print('PaymentService: Checking payment status for order: $orderId');

      final response = await ApiClient.get('/payment/mobile/status/$orderId');

      print(
        'PaymentService: Payment status response status: ${response.statusCode}',
      );
      print('PaymentService: Payment status response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        print('PaymentService: Payment status parsed JSON data: $jsonData');

        // Check if response has the expected structure
        if (jsonData is Map<String, dynamic>) {
          try {
            // Check if this is a wrapped API response
            if (jsonData.containsKey('success') &&
                jsonData.containsKey('data')) {
              final apiResponse = jsonData;
              if (apiResponse['success'] == true &&
                  apiResponse['data'] != null) {
                final statusData = apiResponse['data'] as Map<String, dynamic>;
                print(
                  'PaymentService: Payment status data from API response: $statusData',
                );
                final statusResponse = PaymentStatusResponse.fromJson(
                  statusData,
                );
                print(
                  'PaymentService: Successfully created PaymentStatusResponse: $statusResponse',
                );
                return statusResponse;
              } else {
                throw Exception(
                  'API request failed: ${apiResponse['message'] ?? 'Unknown error'}',
                );
              }
            } else {
              // Direct status response (fallback)
              final statusResponse = PaymentStatusResponse.fromJson(jsonData);
              print(
                'PaymentService: Successfully created PaymentStatusResponse: $statusResponse',
              );
              return statusResponse;
            }
          } catch (e) {
            print('PaymentService: Error parsing PaymentStatusResponse: $e');
            print('PaymentService: JSON data that caused the error: $jsonData');
            throw Exception('Error parsing payment status response: $e');
          }
        } else {
          print(
            'PaymentService: Response is not a Map<String, dynamic>: $jsonData',
          );
          throw Exception('Invalid response format from server');
        }
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
