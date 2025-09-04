/// DTO for robot heartbeat MQTT messages from topic: robot/+/heartbeat
class RobotHeartbeatDto {
  final bool isAlive;
  final String timestamp;

  const RobotHeartbeatDto({required this.isAlive, required this.timestamp});

  factory RobotHeartbeatDto.fromJson(Map<String, dynamic> json) {
    return RobotHeartbeatDto(
      isAlive: json['isAlive'] ?? false,
      timestamp: json['timestamp'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'isAlive': isAlive, 'timestamp': timestamp};
  }

  @override
  String toString() {
    return 'RobotHeartbeatDto(isAlive: $isAlive, timestamp: $timestamp)';
  }
}
