import 'package:zippy/models/entity/robot/robot.dart';

class RobotStatusResponse {
  final bool success;
  final String message;
  final RobotStatusData data;
  final String timestamp;

  const RobotStatusResponse({
    required this.success,
    required this.message,
    required this.data,
    required this.timestamp,
  });

  factory RobotStatusResponse.fromJson(Map<String, dynamic> json) {
    return RobotStatusResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: RobotStatusData.fromJson(json['data'] ?? {}),
      timestamp: json['timestamp'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'data': data.toJson(),
      'timestamp': timestamp,
    };
  }
}

class RobotStatusData {
  final int freeRobotsCount;
  final int commandsSent;
  final List<Robot> freeRobots;
  final List<String> robotsRequested;
  final String message;

  const RobotStatusData({
    required this.freeRobotsCount,
    required this.commandsSent,
    required this.freeRobots,
    required this.robotsRequested,
    required this.message,
  });

  factory RobotStatusData.fromJson(Map<String, dynamic> json) {
    return RobotStatusData(
      freeRobotsCount: json['freeRobotsCount'] ?? 0,
      commandsSent: json['commandsSent'] ?? 0,
      freeRobots:
          (json['freeRobots'] as List<dynamic>?)
              ?.map((robot) => Robot.fromJson(robot))
              .toList() ??
          [],
      robotsRequested:
          (json['robotsRequested'] as List<dynamic>?)
              ?.map((code) => code.toString())
              .toList() ??
          [],
      message: json['message'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'freeRobotsCount': freeRobotsCount,
      'commandsSent': commandsSent,
      'freeRobots': freeRobots.map((r) => r.toJson()).toList(),
      'robotsRequested': robotsRequested,
      'message': message,
    };
  }
}
