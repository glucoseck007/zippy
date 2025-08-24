import 'dart:convert';
import 'package:zippy/models/entity/staff/order.dart';
import 'package:zippy/services/api_client.dart';

class StaffOrderService {
  /// Get all orders for staff
  static Future<List<StaffOrder>> getAllOrders() async {
    try {
      final response = await ApiClient.get('/order/staff/all');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Debug: Print the response structure
        print('API Response: $responseData');

        // Check if response has the expected structure
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> ordersData =
              responseData['data'] as List<dynamic>;

          return ordersData
              .map(
                (orderJson) =>
                    StaffOrder.fromJson(orderJson as Map<String, dynamic>),
              )
              .toList();
        } else {
          throw Exception(
            'Invalid response format: ${responseData['message'] ?? 'Unknown error'}',
          );
        }
      } else {
        throw Exception('Failed to load orders: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching staff orders: $e');
      throw Exception('Failed to fetch orders: $e');
    }
  }

  /// Approve a pending order
  static Future<bool> approveOrder(String orderCode) async {
    try {
      final response = await ApiClient.get('/order/approve/$orderCode');

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Failed to approve order: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error approving order: $e');
      return false;
    }
  }
}
