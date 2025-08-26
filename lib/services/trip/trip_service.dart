import 'dart:convert';
import 'package:zippy/models/response/trip/trip_response.dart';
import 'package:zippy/services/api_client.dart';

class TripService {
  /// Get trip details by order code
  static Future<TripResponse?> getTripByOrderCode(String orderCode) async {
    try {
      print('TripService: Getting trip for order code: $orderCode');

      final response = await ApiClient.get(
        '/trip/by-order-code?orderCode=$orderCode',
      );

      print('TripService: Response status code: ${response.statusCode}');
      print('TripService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final tripResponse = TripResponse.fromJson(jsonData);

        print('TripService: Successfully retrieved trip data');
        if (tripResponse.data != null) {
          print('TripService: Trip code: ${tripResponse.data!.tripCode}');
          print('TripService: Trip status: ${tripResponse.data!.status}');
        }

        return tripResponse;
      } else {
        print(
          'TripService: Failed to get trip with status code: ${response.statusCode}',
        );
        print('TripService: Error response: ${response.body}');

        try {
          final jsonData = json.decode(response.body);
          return TripResponse.fromJson(jsonData);
        } catch (e) {
          return TripResponse(
            success: false,
            message: 'Failed to retrieve trip details',
          );
        }
      }
    } catch (e, stackTrace) {
      print('TripService: Error getting trip: $e');
      print('TripService: Stack trace: $stackTrace');

      return TripResponse(
        success: false,
        message: 'Network error: Failed to retrieve trip details',
      );
    }
  }

  /// Get trip details by trip code
  static Future<TripResponse?> getTripByTripCode(String tripCode) async {
    try {
      print('TripService: Getting trip by trip code: $tripCode');

      final response = await ApiClient.get('/trip/$tripCode');

      print('TripService: Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final tripResponse = TripResponse.fromJson(jsonData);

        print('TripService: Successfully retrieved trip details');
        return tripResponse;
      } else {
        print(
          'TripService: Failed to get trip details with status code: ${response.statusCode}',
        );

        try {
          final jsonData = json.decode(response.body);
          return TripResponse.fromJson(jsonData);
        } catch (e) {
          return TripResponse(
            success: false,
            message: 'Failed to retrieve trip details',
          );
        }
      }
    } catch (e, stackTrace) {
      print('TripService: Error getting trip details: $e');
      print('TripService: Stack trace: $stackTrace');

      return TripResponse(
        success: false,
        message: 'Network error: Failed to retrieve trip details',
      );
    }
  }

  /// Get trip details by trip code including start and end points
  static Future<Map<String, dynamic>?> getTripDetails(String tripCode) async {
    try {
      print('TripService: Fetching trip details for tripCode: $tripCode');

      final response = await ApiClient.get('/trip/details/$tripCode');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['success'] == true && jsonData['data'] != null) {
          final data = jsonData['data'];
          final result = {
            'startPoint': data['startPoint'] as String?,
            'endPoint': data['endPoint'] as String?,
          };

          print(
            'TripService: Trip details loaded - Start: ${result['startPoint']}, End: ${result['endPoint']}',
          );
          return result;
        } else {
          print('TripService: Invalid response format or no data');
          return null;
        }
      } else {
        print(
          'TripService: Failed to fetch trip details, status: ${response.statusCode}',
        );
        throw Exception('Failed to fetch trip details');
      }
    } catch (e, stackTrace) {
      print('TripService: Error fetching trip details: $e');
      print('TripService: Stack trace: $stackTrace');
      rethrow;
    }
  }
}
