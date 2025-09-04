/// DTO for robot container MQTT messages from topic: robot/+/container
class RobotContainerDto {
  final bool isClosed;
  final String status;
  final double weight;

  const RobotContainerDto({
    required this.isClosed,
    required this.status,
    required this.weight,
  });

  factory RobotContainerDto.fromJson(Map<String, dynamic> json) {
    return RobotContainerDto(
      isClosed: json['isClosed'] ?? false,
      status: json['status'] ?? 'free',
      weight: (json['weight'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'isClosed': isClosed, 'status': status, 'weight': weight};
  }

  /// Check if container is available for use
  bool get isAvailable => status == 'free' && !isClosed;

  /// Check if container is occupied
  bool get isOccupied => status != 'free' || (isClosed && weight > 0);

  @override
  String toString() {
    return 'RobotContainerDto(isClosed: $isClosed, status: $status, weight: $weight)';
  }
}
