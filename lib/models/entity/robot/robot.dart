class Robot {
  final String robotCode;
  final bool online;
  final String status;
  final List<Container> freeContainers;
  final int totalFreeContainers;

  // Additional fields for UI display (can be populated from other sources)
  final String? name;
  final int? batteryLevel;
  final String? currentLocation;
  final String? estimatedArrival;

  const Robot({
    required this.robotCode,
    required this.online,
    required this.status,
    required this.freeContainers,
    required this.totalFreeContainers,
    this.name,
    this.batteryLevel,
    this.currentLocation,
    this.estimatedArrival,
  });

  factory Robot.fromJson(Map<String, dynamic> json) {
    return Robot(
      robotCode: json['robotCode'] ?? '',
      online: json['online'] ?? false,
      status: json['status'] ?? '',
      freeContainers:
          (json['freeContainers'] as List<dynamic>?)
              ?.map((container) => Container.fromJson(container))
              .toList() ??
          [],
      totalFreeContainers: json['totalFreeContainers'] ?? 0,
      name: json['name'],
      batteryLevel: json['batteryLevel'],
      currentLocation: json['currentLocation'],
      estimatedArrival: json['estimatedArrival'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'robotCode': robotCode,
      'online': online,
      'status': status,
      'freeContainers': freeContainers.map((c) => c.toJson()).toList(),
      'totalFreeContainers': totalFreeContainers,
      if (name != null) 'name': name,
      if (batteryLevel != null) 'batteryLevel': batteryLevel,
      if (currentLocation != null) 'currentLocation': currentLocation,
      if (estimatedArrival != null) 'estimatedArrival': estimatedArrival,
    };
  }

  Robot copyWith({
    String? robotCode,
    bool? online,
    String? status,
    List<Container>? freeContainers,
    int? totalFreeContainers,
    String? name,
    int? batteryLevel,
    String? currentLocation,
    String? estimatedArrival,
  }) {
    return Robot(
      robotCode: robotCode ?? this.robotCode,
      online: online ?? this.online,
      status: status ?? this.status,
      freeContainers: freeContainers ?? this.freeContainers,
      totalFreeContainers: totalFreeContainers ?? this.totalFreeContainers,
      name: name ?? this.name,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      currentLocation: currentLocation ?? this.currentLocation,
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
    );
  }

  // Helper method to get user-friendly display name
  String get displayName {
    if (name != null && name!.isNotEmpty) {
      return name!;
    }
    // Generate friendly name from robot code
    final codeNumber = robotCode.replaceAll('ROBOT-', '');
    return 'Zippy Bot ${_getAlphabetName(codeNumber)}';
  }

  // Helper method to convert number to alphabet name
  String _getAlphabetName(String codeNumber) {
    try {
      final number = int.parse(codeNumber);
      const alphabets = [
        'Alpha',
        'Beta',
        'Gamma',
        'Delta',
        'Epsilon',
        'Zeta',
        'Eta',
        'Theta',
      ];
      if (number > 0 && number <= alphabets.length) {
        return alphabets[number - 1];
      }
      return codeNumber;
    } catch (e) {
      return codeNumber;
    }
  }

  // Check if robot is available for booking
  bool get isAvailable => online && status == 'free' && totalFreeContainers > 0;
}

class Container {
  final String containerCode;
  final String status;

  // Additional fields for UI display
  final String? name;
  final String? capacity;
  final String? dimensions;
  final String? occupiedBy;

  const Container({
    required this.containerCode,
    required this.status,
    this.name,
    this.capacity,
    this.dimensions,
    this.occupiedBy,
  });

  factory Container.fromJson(Map<String, dynamic> json) {
    return Container(
      containerCode: json['containerCode'] ?? '',
      status: json['status'] ?? '',
      name: json['name'],
      capacity: json['capacity'],
      dimensions: json['dimensions'],
      occupiedBy: json['occupiedBy'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'containerCode': containerCode,
      'status': status,
      if (name != null) 'name': name,
      if (capacity != null) 'capacity': capacity,
      if (dimensions != null) 'dimensions': dimensions,
      if (occupiedBy != null) 'occupiedBy': occupiedBy,
    };
  }

  Container copyWith({
    String? containerCode,
    String? status,
    String? name,
    String? capacity,
    String? dimensions,
    String? occupiedBy,
  }) {
    return Container(
      containerCode: containerCode ?? this.containerCode,
      status: status ?? this.status,
      name: name ?? this.name,
      capacity: capacity ?? this.capacity,
      dimensions: dimensions ?? this.dimensions,
      occupiedBy: occupiedBy ?? this.occupiedBy,
    );
  }

  // Helper method to get user-friendly display name
  String get displayName {
    if (name != null && name!.isNotEmpty) {
      return name!;
    }
    // Generate friendly name from container code
    // Example: R-001_C-1 -> Container 1
    final parts = containerCode.split('_C-');
    if (parts.length == 2) {
      return 'Container ${parts[1]}';
    }
    return 'Container';
  }

  // Check if container is available for booking
  bool get isAvailable => status == 'free';
}
