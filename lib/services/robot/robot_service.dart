import 'dart:convert';
import 'package:zippy/models/response/robot/robot_list_response.dart';
import 'package:zippy/services/api_client.dart';

class RobotService {
  /// Fetch all robots from /api/robots
  static Future<RobotListResponse?> fetchAllRobots() async {
    try {
      print('RobotService: Fetching all robots...');

      final response = await ApiClient.get('/robots');

      print('RobotService: Response status code: ${response.statusCode}');
      print('RobotService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final robotListResponse = RobotListResponse.fromJson(jsonData);

        print('RobotService: Successfully parsed robot list response');
        print('RobotService: Found ${robotListResponse.data.length} robots');

        return robotListResponse;
      } else {
        print(
          'RobotService: Request failed with status code: ${response.statusCode}',
        );
        print('RobotService: Error response: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      print('RobotService: Error fetching robots: $e');
      print('RobotService: Stack trace: $stackTrace');
      return null;
    }
  }
}
