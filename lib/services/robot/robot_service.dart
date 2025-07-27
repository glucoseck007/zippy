import 'dart:convert';
import 'package:zippy/models/response/robot/robot_status_response.dart';
import 'package:zippy/services/api_client.dart';

class RobotService {
  /// Request status from all available robots
  static Future<RobotStatusResponse?> requestRobotStatus() async {
    try {
      print('RobotService: Requesting robot status...');

      final response = await ApiClient.post(
        '/robot/command/request-status',
        {},
      );

      print('RobotService: Response status code: ${response.statusCode}');
      print('RobotService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final robotStatusResponse = RobotStatusResponse.fromJson(jsonData);

        print('RobotService: Successfully parsed robot status response');
        print(
          'RobotService: Found ${robotStatusResponse.data.freeRobotsCount} free robots',
        );

        return robotStatusResponse;
      } else {
        print(
          'RobotService: Request failed with status code: ${response.statusCode}',
        );
        print('RobotService: Error response: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      print('RobotService: Error requesting robot status: $e');
      print('RobotService: Stack trace: $stackTrace');
      return null;
    }
  }

  /// Request status for specific robots
  static Future<RobotStatusResponse?> requestSpecificRobotStatus(
    List<String> robotCodes,
  ) async {
    try {
      print('RobotService: Requesting status for specific robots: $robotCodes');

      final response = await ApiClient.post('/robot/command/request-status', {
        'robotCodes': robotCodes,
      });

      print('RobotService: Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final robotStatusResponse = RobotStatusResponse.fromJson(jsonData);

        print(
          'RobotService: Successfully parsed specific robot status response',
        );

        return robotStatusResponse;
      } else {
        print(
          'RobotService: Request failed with status code: ${response.statusCode}',
        );
        return null;
      }
    } catch (e, stackTrace) {
      print('RobotService: Error requesting specific robot status: $e');
      print('RobotService: Stack trace: $stackTrace');
      return null;
    }
  }
}
