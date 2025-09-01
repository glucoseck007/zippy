import 'dart:convert';
import 'package:zippy/models/entity/request/order_request.dart';
import 'package:zippy/models/response/order/order_response.dart';
import 'package:zippy/models/response/order/order_list_response.dart';
import 'package:zippy/services/api_client.dart';

class OrderService {
  /// Create a new order
  static Future<OrderResponse?> createOrder(OrderRequest orderRequest) async {
    try {
      print('OrderService: Creating order...');
      print('OrderService: Order request: $orderRequest');

      final response = await ApiClient.post(
        '/order/create',
        orderRequest.toJson(),
      );

      print('OrderService: Response status code: ${response.statusCode}');
      print('OrderService: Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = json.decode(response.body);
        final orderResponse = OrderResponse.fromJson(jsonData);

        print('OrderService: Successfully created order');
        if (orderResponse.data != null) {
          print('OrderService: Order ID: ${orderResponse.data!.orderId}');
          print('OrderService: Order status: ${orderResponse.data!.status}');
        }

        return orderResponse;
      } else {
        print(
          'OrderService: Order creation failed with status code: ${response.statusCode}',
        );
        print('OrderService: Error response: ${response.body}');

        // Try to parse error response
        try {
          final jsonData = json.decode(response.body);
          return OrderResponse.fromJson(jsonData);
        } catch (e) {
          // If parsing fails, return a generic error response
          return OrderResponse(
            success: false,
            message: 'Order creation failed with status ${response.statusCode}',
          );
        }
      }
    } catch (e, stackTrace) {
      print('OrderService: Error creating order: $e');
      print('OrderService: Stack trace: $stackTrace');

      return OrderResponse(
        success: false,
        message: 'Network error: Failed to create order',
      );
    }
  }

  /// Get order details by ID
  static Future<OrderResponse?> getOrder(String orderId) async {
    try {
      print('OrderService: Getting order details for ID: $orderId');

      final response = await ApiClient.get('/order/$orderId');

      print('OrderService: Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final orderResponse = OrderResponse.fromJson(jsonData);

        print('OrderService: Successfully retrieved order details');
        return orderResponse;
      } else {
        print(
          'OrderService: Failed to get order with status code: ${response.statusCode}',
        );
        print('OrderService: Error response: ${response.body}');

        try {
          final jsonData = json.decode(response.body);
          return OrderResponse.fromJson(jsonData);
        } catch (e) {
          return OrderResponse(
            success: false,
            message: 'Failed to retrieve order details',
          );
        }
      }
    } catch (e, stackTrace) {
      print('OrderService: Error getting order: $e');
      print('OrderService: Stack trace: $stackTrace');

      return OrderResponse(
        success: false,
        message: 'Network error: Failed to retrieve order',
      );
    }
  }

  /// Cancel an order
  static Future<OrderResponse?> cancelOrder(String orderId) async {
    try {
      print('OrderService: Cancelling order ID: $orderId');

      final response = await ApiClient.post('/order/$orderId/cancel', {});

      print('OrderService: Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final orderResponse = OrderResponse.fromJson(jsonData);

        print('OrderService: Successfully cancelled order');
        return orderResponse;
      } else {
        print(
          'OrderService: Failed to cancel order with status code: ${response.statusCode}',
        );

        try {
          final jsonData = json.decode(response.body);
          return OrderResponse.fromJson(jsonData);
        } catch (e) {
          return OrderResponse(
            success: false,
            message: 'Failed to cancel order',
          );
        }
      }
    } catch (e, stackTrace) {
      print('OrderService: Error cancelling order: $e');
      print('OrderService: Stack trace: $stackTrace');

      return OrderResponse(
        success: false,
        message: 'Network error: Failed to cancel order',
      );
    }
  }

  /// Get orders for a specific user
  static Future<OrderListResponse?> getUserOrders(String username) async {
    try {
      print('OrderService: Getting orders for user: $username');

      final response = await ApiClient.get('/order/get?username=$username');

      print('OrderService: Response status code: ${response.statusCode}');
      print('OrderService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final orderListResponse = OrderListResponse.fromJson(jsonData);

        print(
          'OrderService: Successfully retrieved ${orderListResponse.data.length} orders',
        );
        return orderListResponse;
      } else {
        print(
          'OrderService: Failed to get orders with status code: ${response.statusCode}',
        );
        print('OrderService: Error response: ${response.body}');

        try {
          final jsonData = json.decode(response.body);
          return OrderListResponse(
            success: false,
            message: jsonData['message'] ?? 'Failed to retrieve orders',
            data: [],
          );
        } catch (e) {
          return OrderListResponse(
            success: false,
            message: 'Failed to retrieve orders',
            data: [],
          );
        }
      }
    } catch (e, stackTrace) {
      print('OrderService: Error getting orders: $e');
      print('OrderService: Stack trace: $stackTrace');

      return OrderListResponse(
        success: false,
        message: 'Network error: Failed to retrieve orders',
        data: [],
      );
    }
  }

  /// Confirm a reservation and create the actual order
  static Future<OrderResponse?> confirmReservation({
    required String reservationId,
    required String productName,
    required String endpoint,
  }) async {
    try {
      print('OrderService: Confirming reservation...');
      print('OrderService: Reservation ID: $reservationId');

      final response = await ApiClient.post('/order/confirm-reservation', {
        'reservationId': reservationId,
        'productName': productName,
        'endpoint': endpoint,
      });

      print(
        'OrderService: Confirm response status code: ${response.statusCode}',
      );
      print('OrderService: Confirm response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = json.decode(response.body);
        final orderResponse = OrderResponse.fromJson(jsonData);

        print(
          'OrderService: Successfully confirmed reservation and created order',
        );
        if (orderResponse.data != null) {
          print('OrderService: Order ID: ${orderResponse.data!.orderId}');
          print('OrderService: Order status: ${orderResponse.data!.status}');
        }

        return orderResponse;
      } else {
        print(
          'OrderService: Reservation confirmation failed with status code: ${response.statusCode}',
        );
        print('OrderService: Error response: ${response.body}');

        // Try to parse error response
        try {
          final jsonData = json.decode(response.body);
          return OrderResponse.fromJson(jsonData);
        } catch (e) {
          // If parsing fails, return a generic error response
          return OrderResponse(
            success: false,
            message:
                'Reservation confirmation failed with status ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      print(
        'OrderService: Exception occurred during reservation confirmation: $e',
      );
      return OrderResponse(
        success: false,
        message: 'Network error occurred during confirmation: $e',
      );
    }
  }

  /// Cancel a reservation
  static Future<bool> cancelReservation(String reservationId) async {
    try {
      print('OrderService: Cancelling reservation...');
      print('OrderService: Reservation ID: $reservationId');

      final response = await ApiClient.post(
        '/order/reservation/$reservationId/cancel',
        {},
      );

      print(
        'OrderService: Cancel response status code: ${response.statusCode}',
      );
      print('OrderService: Cancel response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('OrderService: Successfully cancelled reservation');
        return true;
      } else {
        print(
          'OrderService: Reservation cancellation failed with status code: ${response.statusCode}',
        );
        return false;
      }
    } catch (e) {
      print(
        'OrderService: Exception occurred during reservation cancellation: $e',
      );
      return false;
    }
  }

  /// Get order details by order code
  static Future<OrderResponse?> getOrderByCode(String orderCode) async {
    try {
      print('OrderService: Getting order details for order code: $orderCode');

      final response = await ApiClient.get('/order/$orderCode');

      print('OrderService: Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final orderResponse = OrderResponse.fromJson(jsonData);

        print('OrderService: Successfully retrieved order details by code');
        return orderResponse;
      } else {
        print(
          'OrderService: Failed to get order by code with status code: ${response.statusCode}',
        );
        print('OrderService: Error response: ${response.body}');

        try {
          final jsonData = json.decode(response.body);
          return OrderResponse.fromJson(jsonData);
        } catch (e) {
          return OrderResponse(
            success: false,
            message: 'Failed to retrieve order details',
          );
        }
      }
    } catch (e, stackTrace) {
      print('OrderService: Error getting order by code: $e');
      print('OrderService: Stack trace: $stackTrace');

      return OrderResponse(
        success: false,
        message: 'Network error: Failed to retrieve order',
      );
    }
  }
}
