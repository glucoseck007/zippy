class TripResponse {
  final bool success;
  final String message;
  final TripData? data;
  final String? timestamp;

  const TripResponse({
    required this.success,
    required this.message,
    this.data,
    this.timestamp,
  });

  factory TripResponse.fromJson(Map<String, dynamic> json) {
    return TripResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null
          ? TripData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
      timestamp: json['timestamp'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      if (data != null) 'data': data!.toJson(),
      if (timestamp != null) 'timestamp': timestamp,
    };
  }

  @override
  String toString() {
    return 'TripResponse(success: $success, message: $message, data: $data, timestamp: $timestamp)';
  }
}

class TripData {
  final String tripCode;
  final String? startPoint;
  final String endPoint;
  final String robotId;
  final String robotCode;
  final String status;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? estimatedArrival;

  const TripData({
    required this.tripCode,
    this.startPoint,
    required this.endPoint,
    required this.robotId,
    required this.robotCode,
    required this.status,
    this.startTime,
    this.endTime,
    this.estimatedArrival,
  });

  factory TripData.fromJson(Map<String, dynamic> json) {
    return TripData(
      tripCode: json['tripCode'] as String? ?? '',
      startPoint: json['startPoint'] as String?,
      endPoint: json['endPoint'] as String? ?? '',
      robotId: json['robotId'] as String? ?? '',
      robotCode: json['robotCode'] as String? ?? '',
      status: json['status'] as String? ?? '',
      startTime: json['startTime'] != null
          ? DateTime.tryParse(json['startTime'] as String)
          : null,
      endTime: json['endTime'] != null
          ? DateTime.tryParse(json['endTime'] as String)
          : null,
      estimatedArrival: json['estimatedArrival'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tripCode': tripCode,
      if (startPoint != null) 'startPoint': startPoint,
      'endPoint': endPoint,
      'robotId': robotId,
      'robotCode': robotCode,
      'status': status,
      if (startTime != null) 'startTime': startTime!.toIso8601String(),
      if (endTime != null) 'endTime': endTime!.toIso8601String(),
      if (estimatedArrival != null) 'estimatedArrival': estimatedArrival,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TripData &&
        other.tripCode == tripCode &&
        other.startPoint == startPoint &&
        other.endPoint == endPoint &&
        other.robotId == robotId &&
        other.robotCode == robotCode &&
        other.status == status;
  }

  @override
  int get hashCode {
    return Object.hash(
      tripCode,
      startPoint,
      endPoint,
      robotId,
      robotCode,
      status,
    );
  }

  @override
  String toString() {
    return 'TripData(tripCode: $tripCode, startPoint: $startPoint, endPoint: $endPoint, robotCode: $robotCode, status: $status)';
  }
}
