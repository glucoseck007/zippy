import 'package:zippy/models/entity/robot/robot.dart';

class RobotListResponse {
  final bool success;
  final String message;
  final List<Robot> data;

  const RobotListResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory RobotListResponse.fromJson(Map<String, dynamic> json) {
    return RobotListResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data:
          (json['data'] as List<dynamic>?)
              ?.map((robot) => Robot.fromJson(robot))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'data': data.map((r) => r.toJson()).toList(),
    };
  }
}
