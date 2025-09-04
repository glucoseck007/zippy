import 'package:zippy/models/entity/robot/container.dart';

class Robot {
  final String code;
  final String batteryStatus;
  final String locationRealtime;

  // MQTT state fields
  final bool? isAlive; // from heartbeat
  final String? lastHeartbeat; // timestamp from heartbeat
  final List<Container> containers; // from container messages

  // Additional fields for UI display
  final String? name;
  final int? batteryLevel;
  final String? status;
  final bool? online;
  final String? estimatedArrival;

  const Robot({
    required this.code,
    required this.batteryStatus,
    required this.locationRealtime,
    this.isAlive,
    this.lastHeartbeat,
    this.containers = const [],
    this.name,
    this.batteryLevel,
    this.status,
    this.online,
    this.estimatedArrival,
  });

  factory Robot.fromJson(Map<String, dynamic> json) {
    // Parse batteryStatus as either double or string
    final rawBatteryStatus = json['batteryStatus'];
    final batteryLevel = rawBatteryStatus is num
        ? rawBatteryStatus.round()
        : (rawBatteryStatus != null
              ? int.tryParse(rawBatteryStatus.toString())
              : null);

    return Robot(
      code: json['code'] ?? '',
      batteryStatus: json['batteryStatus']?.toString() ?? '',
      locationRealtime: json['locationRealtime'] ?? '',
      isAlive: json['isAlive'],
      lastHeartbeat: json['lastHeartbeat'],
      containers:
          (json['containers'] as List<dynamic>?)
              ?.map((container) => Container.fromJson(container))
              .toList() ??
          [],
      name: json['name'],
      batteryLevel: batteryLevel ?? json['batteryLevel'],
      status: json['status'],
      online: json['online'],
      estimatedArrival: json['estimatedArrival'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'batteryStatus': batteryStatus,
      'locationRealtime': locationRealtime,
      if (isAlive != null) 'isAlive': isAlive,
      if (lastHeartbeat != null) 'lastHeartbeat': lastHeartbeat,
      'containers': containers.map((c) => c.toJson()).toList(),
      if (name != null) 'name': name,
      if (batteryLevel != null) 'batteryLevel': batteryLevel,
      if (status != null) 'status': status,
      if (online != null) 'online': online,
      if (estimatedArrival != null) 'estimatedArrival': estimatedArrival,
    };
  }

  Robot copyWith({
    String? code,
    String? batteryStatus,
    String? locationRealtime,
    bool? isAlive,
    String? lastHeartbeat,
    List<Container>? containers,
    String? name,
    int? batteryLevel,
    String? status,
    bool? online,
    String? estimatedArrival,
  }) {
    return Robot(
      code: code ?? this.code,
      batteryStatus: batteryStatus ?? this.batteryStatus,
      locationRealtime: locationRealtime ?? this.locationRealtime,
      isAlive: isAlive ?? this.isAlive,
      lastHeartbeat: lastHeartbeat ?? this.lastHeartbeat,
      containers: containers ?? this.containers,
      name: name ?? this.name,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      status: status ?? this.status,
      online: online ?? this.online,
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
    );
  }

  // Helper method to get user-friendly display name
  String get displayName {
    if (name != null && name!.isNotEmpty) {
      return name!;
    }
    // Generate friendly name from robot code (e.g., ROBOT001 -> Zippy Bot 1)
    final numericPart = _extractNumericFromCode(code);
    return 'Zippy Bot $numericPart';
  }

  // Helper method to get robot code (for backward compatibility)
  String get robotCode => code;

  // Helper method to get current location (for backward compatibility)
  String? get currentLocation => locationRealtime;

  // Check if robot is available for booking (all robots from /api/robots can be booked)
  bool get isAvailable => true;

  // Determine if robot is online based on MQTT heartbeat or fallback to online field
  bool get isOnline => isAlive ?? online ?? false;

  // Get free containers
  List<Container> get freeContainers =>
      containers.where((c) => c.isAvailable).toList();

  // Get total free containers count (for backward compatibility)
  int get totalFreeContainers => freeContainers.length;

  // Get occupied containers
  List<Container> get occupiedContainers =>
      containers.where((c) => c.isOccupied).toList();

  // Determine robot status based on various factors
  String get currentStatus {
    if (!isOnline) return 'offline';
    if (occupiedContainers.isNotEmpty) return 'busy';
    return status ?? 'free';
  }

  // Helper method to extract numeric value from robot code
  String _extractNumericFromCode(String robotCode) {
    try {
      // Remove ROBOT prefix and any leading zeros to get clean number
      final numericString = robotCode.replaceAll(RegExp(r'^ROBOT0*'), '');
      if (numericString.isEmpty) {
        return '1'; // Default to 1 if no number found
      }
      // Parse as int to remove leading zeros, then convert back to string
      final number = int.parse(numericString);
      return number.toString();
    } catch (e) {
      // If parsing fails, try to extract any digits from the code
      final match = RegExp(r'\d+').firstMatch(robotCode);
      if (match != null) {
        final number = int.parse(match.group(0)!);
        return number.toString();
      }
      return '1'; // Default fallback
    }
  }
}
