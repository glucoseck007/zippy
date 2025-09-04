/// DTO for trip state MQTT messages from topic: robot/+/trip
class TripStateMqttDto {
  final String tripId;
  final double progress;
  final int status;
  final String startPoint;
  final String endPoint;

  const TripStateMqttDto({
    required this.tripId,
    required this.progress,
    required this.status,
    required this.startPoint,
    required this.endPoint,
  });

  factory TripStateMqttDto.fromJson(Map<String, dynamic> json) {
    return TripStateMqttDto(
      tripId: json['trip_id'] ?? '',
      progress: (json['progress'] ?? 0.0).toDouble(),
      status: json['status'] ?? 0,
      startPoint: json['start_point'] ?? '',
      endPoint: json['end_point'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trip_id': tripId,
      'progress': progress,
      'status': status,
      'start_point': startPoint,
      'end_point': endPoint,
    };
  }

  /// Get human-readable status name
  String get statusName {
    switch (status) {
      case 0:
        return 'Prepare';
      case 1:
        return 'Load';
      case 2:
        return 'On Going';
      case 3:
        return 'Delivered';
      case 4:
        return 'Finish';
      default:
        return 'Unknown($status)';
    }
  }

  /// Get progress as percentage (0-100)
  double get progressPercentage {
    return progress > 1 ? progress : progress * 100;
  }

  /// Check if trip is completed
  bool get isCompleted => status == 4;

  /// Check if trip is in progress
  bool get isInProgress => status >= 1 && status <= 3;

  @override
  String toString() {
    return 'TripStateMqttDto(tripId: $tripId, progress: $progress, status: $status ($statusName), startPoint: $startPoint, endPoint: $endPoint)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TripStateMqttDto &&
        other.tripId == tripId &&
        other.progress == progress &&
        other.status == status &&
        other.startPoint == startPoint &&
        other.endPoint == endPoint;
  }

  @override
  int get hashCode {
    return tripId.hashCode ^
        progress.hashCode ^
        status.hashCode ^
        startPoint.hashCode ^
        endPoint.hashCode;
  }
}
