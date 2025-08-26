import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zippy/models/entity/robot/robot.dart';
import 'package:zippy/services/robot/robot_service.dart';
import 'package:zippy/services/mqtt/mqtt_service.dart';
import 'package:zippy/state/robot/robot_state.dart';

class RobotNotifier extends StateNotifier<RobotState> {
  /// Callback for when robots become available (for UI refresh)
  static Function()? onRobotsAvailable;

  /// Callback for when containers become available (for step 4 UI refresh)
  static Function()? onContainersAvailable;

  RobotNotifier() : super(const RobotState.initial()) {
    _initializeMqttListener();
  }

  /// Initialize MQTT listener for real-time robot status updates
  void _initializeMqttListener() {
    // Set up the callback for MQTT robot status updates
    MqttService.onRobotStatusUpdate = _handleRobotStatusUpdate;
  }

  /// Handle real-time robot status updates from MQTT
  void _handleRobotStatusUpdate(Map<String, dynamic> data) {
    try {
      print('RobotProvider: === MQTT UPDATE RECEIVED ===');
      print('RobotProvider: Raw MQTT data: $data');

      // Get the topic from the message
      final topic = data['topic'] as String?;

      if (topic == null) {
        print('RobotProvider: Invalid update - missing topic');
        return;
      }

      print('RobotProvider: Processing topic: $topic');

      // Parse topic to determine message type and extract robot ID
      final parts = topic.split('/');

      if (parts.isEmpty || parts[0] != 'robot') {
        print(
          'RobotProvider: Invalid topic format - does not start with robot/',
        );
        return;
      }

      // Extract robot ID (should be at index 1)
      if (parts.length < 2) {
        print('RobotProvider: Invalid topic format - missing robot ID');
        return;
      }

      final robotId = parts[1];
      print('RobotProvider: Processing update for robot: $robotId');

      // Determine message type based on topic pattern and route to appropriate handler
      Map<String, dynamic> processedData = Map.from(data);
      processedData['robotId'] = robotId;

      if (topic.contains('/location')) {
        // Topic: robot/+/location
        print('RobotProvider: Message type: robot_location');
        _handleRobotLocationUpdate(processedData);
      } else if (topic.contains('/battery')) {
        // Topic: robot/+/battery
        print('RobotProvider: Message type: robot_battery');
        _handleRobotBatteryUpdate(processedData);
      } else if (topic.contains('/status')) {
        // Topic: robot/+/status
        print('RobotProvider: Message type: robot_status');
        final status = data['status'] as String?;
        if (status != null) {
          _handleRobotStatusUpdateForStep3(processedData);
        }
      } else if (topic.contains('/container/') && topic.contains('/status')) {
        // Topic: robot/+/container/+/status
        print('RobotProvider: Message type: container_status');

        // Extract container ID from topic (should be at index 3)
        if (parts.length >= 4) {
          final containerId = parts[3];
          processedData['containerId'] = containerId;
          print('RobotProvider: Container ID: $containerId');
          _handleContainerStatusUpdate(processedData);
        } else {
          print(
            'RobotProvider: Invalid container topic format - missing container ID',
          );
        }
      } else if (topic.contains('/trip/')) {
        // Topic: robot/+/trip/+
        print('RobotProvider: Message type: trip_progress');

        // Extract trip code from topic (should be at index 3)
        if (parts.length >= 4) {
          final tripCode = parts[3];
          processedData['tripCode'] = tripCode;
          print('RobotProvider: Trip code: $tripCode');

          final progress = data['progress'] as num?;
          if (progress != null) {
            updateRobotTripProgress(
              robotId: robotId,
              tripCode: tripCode,
              progress: progress is double ? progress : progress.toDouble(),
              payload: processedData,
            );
          } else {
            print('RobotProvider: Missing progress field for trip update');
          }
        } else {
          print('RobotProvider: Invalid trip topic format - missing trip code');
        }
      } else {
        print('RobotProvider: Unknown topic pattern: $topic');
        return;
      }

      print('RobotProvider: === MQTT UPDATE COMPLETED ===');
    } catch (e, stackTrace) {
      print('RobotProvider: Error handling MQTT robot status update: $e');
      print('RobotProvider: Stack trace: $stackTrace');
    }
  }

  /// Handle robot status updates (for step 3 - robot selection)
  void _handleRobotStatusUpdateForStep3(Map<String, dynamic> data) {
    final robotId = data['robotId'] as String;
    final status = data['status'] as String;

    // Only process robot status updates where status = "free"
    if (status != 'free') {
      print('RobotProvider: ⏩ Skipping non-free robot status: $status');
      return;
    }

    print(
      'RobotProvider: 🟢 Robot $robotId status is FREE - processing for step 3 UI refresh!',
    );

    // Get current robots or create empty list
    final currentState = state;
    final allRobots = currentState.isLoaded
        ? [...currentState.freeRobots, ...currentState.busyRobots]
        : <Robot>[];

    print('RobotProvider: Current robot count: ${allRobots.length}');
    print(
      'RobotProvider: Current robot IDs: ${allRobots.map((r) => r.robotCode).join(", ")}',
    );

    // Check if robot exists, if not create it
    Robot? existingRobot;
    try {
      existingRobot = allRobots.firstWhere(
        (robot) => robot.robotCode == robotId,
      );
      print('RobotProvider: Found existing robot: ${existingRobot.robotCode}');
    } catch (e) {
      existingRobot = null;
      print('RobotProvider: Robot $robotId not found - creating new robot');
    }

    List<Robot> updatedRobots;

    if (existingRobot == null) {
      // Create a new robot with free status
      final newRobot = _createRobotFromMqtt(robotId, status);
      updatedRobots = [...allRobots, newRobot];
      print('RobotProvider: ✅ Created new robot: ${newRobot.robotCode}');
    } else {
      // Update existing robot status
      updatedRobots = allRobots.map((robot) {
        if (robot.robotCode == robotId) {
          return robot.copyWith(status: status, online: true);
        }
        return robot;
      }).toList();
      print('RobotProvider: ✅ Updated existing robot: $robotId');
    }

    // Update state and trigger UI refresh for step 3
    _updateStateWithRobots(
      updatedRobots,
      'Robot $robotId status updated via MQTT',
    );
  }

  /// Handle container status updates (for step 4 - container selection)
  void _handleContainerStatusUpdate(Map<String, dynamic> data) {
    final robotId = data['robotId'] as String;
    final containerId = data['containerId'] as String?;
    final status = data['status'] as String;

    if (containerId == null) {
      print('RobotProvider: Container update missing containerId');
      return;
    }

    print(
      'RobotProvider: 🔵 Container $containerId status update: $status for robot $robotId (step 4)',
    );

    // Get current robots
    final currentState = state;
    if (!currentState.isLoaded) {
      print('RobotProvider: Robot state not loaded, ignoring container update');
      return;
    }

    final allRobots = [...currentState.freeRobots, ...currentState.busyRobots];

    // Check if robot exists, if not create it
    Robot? existingRobot;
    try {
      existingRobot = allRobots.firstWhere(
        (robot) => robot.robotCode == robotId,
      );
      print('RobotProvider: Found existing robot: ${existingRobot.robotCode}');
    } catch (e) {
      existingRobot = null;
      print(
        'RobotProvider: Robot $robotId not found for container update - creating new robot',
      );
    }

    List<Robot> updatedRobots;

    if (existingRobot == null) {
      // Create a new robot with the container
      final newContainer = _createContainerFromMqtt(containerId, status);
      final newRobot = _createRobotFromMqtt(robotId, 'free').copyWith(
        freeContainers: [newContainer],
        totalFreeContainers: newContainer.isAvailable ? 1 : 0,
      );
      updatedRobots = [...allRobots, newRobot];
      print(
        'RobotProvider: ✅ Created new robot $robotId with container $containerId',
      );
    } else {
      // Update existing robot's containers
      updatedRobots = allRobots.map((robot) {
        if (robot.robotCode == robotId) {
          // Check if container exists, if not create it
          final existingContainerIndex = robot.freeContainers.indexWhere(
            (container) => container.containerCode == containerId,
          );

          List<Container> updatedContainers;

          if (existingContainerIndex != -1) {
            // Update existing container
            updatedContainers = robot.freeContainers.map((container) {
              if (container.containerCode == containerId) {
                print(
                  'RobotProvider: ✅ Updating existing container ${container.containerCode} from ${container.status} to $status',
                );
                return container.copyWith(status: status);
              }
              return container;
            }).toList();
          } else {
            // Create new container if it doesn't exist
            print(
              'RobotProvider: ✅ Creating new container $containerId with status $status for robot $robotId',
            );
            final newContainer = _createContainerFromMqtt(containerId, status);
            updatedContainers = [...robot.freeContainers, newContainer];
          }

          // Calculate total free containers
          final totalFree = updatedContainers
              .where((c) => c.isAvailable)
              .length;

          print(
            'RobotProvider: Robot $robotId now has $totalFree free containers out of ${updatedContainers.length} total',
          );

          return robot.copyWith(
            freeContainers: updatedContainers,
            totalFreeContainers: totalFree,
          );
        }
        return robot;
      }).toList();
    }

    // Update state and trigger container availability callback
    _updateStateWithRobots(
      updatedRobots,
      'Container $containerId updated via MQTT',
    );

    // Trigger container callback for step 4 UI refresh
    onContainersAvailable?.call();
  }

  /// Handle robot location updates from MQTT
  void _handleRobotLocationUpdate(Map<String, dynamic> data) {
    final robotId = data['robotId'] as String;

    // Extract location from the payload
    // Payload format: {"roomCode": "DE-105", "lat": 21.71, "lon": 21.123}
    final roomCode = data['roomCode'] as String?;
    final lat = data['lat'];
    final lon = data['lon'];

    String? location;

    if (roomCode != null) {
      // Use room code as the primary location indicator
      location = roomCode;
      print('RobotProvider: 📍 Robot $robotId location update: $location');

      // Optionally, you can also log coordinates if available
      if (lat != null && lon != null) {
        print(
          'RobotProvider: 📍 Robot $robotId coordinates: lat=$lat, lon=$lon',
        );
      }
    } else if (lat != null && lon != null) {
      // Fallback to coordinates if room code is not available
      location = 'Lat: $lat, Lon: $lon';
      print('RobotProvider: 📍 Robot $robotId location update: $location');
    } else {
      print(
        'RobotProvider: Location update missing location data for robot $robotId',
      );
      print('RobotProvider: Received data: $data');
      return;
    }

    // Get current robots
    final currentState = state;
    if (!currentState.isLoaded) {
      print('RobotProvider: Robot state not loaded, ignoring location update');
      return;
    }

    final allRobots = [...currentState.freeRobots, ...currentState.busyRobots];

    // Find and update the robot's location
    Robot? existingRobot;
    try {
      existingRobot = allRobots.firstWhere(
        (robot) => robot.robotCode == robotId,
      );
    } catch (e) {
      existingRobot = null;
      print(
        'RobotProvider: Robot $robotId not found for location update - creating new robot',
      );
    }

    List<Robot> updatedRobots;

    if (existingRobot == null) {
      // Create a new robot with the location
      final newRobot = _createRobotFromMqtt(
        robotId,
        'free',
      ).copyWith(currentLocation: location);
      updatedRobots = [...allRobots, newRobot];
      print(
        'RobotProvider: ✅ Created new robot $robotId with location $location',
      );
    } else {
      // Update existing robot's location
      updatedRobots = allRobots.map((robot) {
        if (robot.robotCode == robotId) {
          print(
            'RobotProvider: ✅ Updating robot $robotId location from ${robot.currentLocation} to $location',
          );
          return robot.copyWith(currentLocation: location);
        }
        return robot;
      }).toList();
    }

    // Update state
    _updateStateWithRobots(
      updatedRobots,
      'Robot $robotId location updated via MQTT to $location',
    );
  }

  /// Handle robot battery updates from MQTT
  void _handleRobotBatteryUpdate(Map<String, dynamic> data) {
    final robotId = data['robotId'] as String;
    final battery = data['battery'];

    // Handle both string and integer battery values
    int? batteryLevel;
    if (battery is int) {
      batteryLevel = battery;
    } else if (battery is String) {
      batteryLevel = int.tryParse(battery);
    }

    if (batteryLevel == null) {
      print(
        'RobotProvider: Battery update missing or invalid battery data: $battery',
      );
      return;
    }

    // Ensure battery level is within valid range (0-100)
    batteryLevel = batteryLevel.clamp(0, 100);

    print('RobotProvider: 🔋 Robot $robotId battery update: $batteryLevel%');

    // Get current robots
    final currentState = state;
    if (!currentState.isLoaded) {
      print('RobotProvider: Robot state not loaded, ignoring battery update');
      return;
    }

    final allRobots = [...currentState.freeRobots, ...currentState.busyRobots];

    // Find and update the robot's battery
    Robot? existingRobot;
    try {
      existingRobot = allRobots.firstWhere(
        (robot) => robot.robotCode == robotId,
      );
    } catch (e) {
      existingRobot = null;
      print('RobotProvider: Robot $robotId not found for battery update');
    }

    List<Robot> updatedRobots;

    if (existingRobot == null) {
      // Create a new robot with the battery level
      final newRobot = _createRobotFromMqtt(
        robotId,
        'free',
      ).copyWith(batteryLevel: batteryLevel);
      updatedRobots = [...allRobots, newRobot];
      print(
        'RobotProvider: ✅ Created new robot $robotId with battery $batteryLevel%',
      );
    } else {
      // Update existing robot's battery
      updatedRobots = allRobots.map((robot) {
        if (robot.robotCode == robotId) {
          print(
            'RobotProvider: ✅ Updating robot $robotId battery from ${robot.batteryLevel}% to $batteryLevel%',
          );
          return robot.copyWith(batteryLevel: batteryLevel);
        }
        return robot;
      }).toList();
    }

    // Update state
    _updateStateWithRobots(
      updatedRobots,
      'Robot $robotId battery updated via MQTT',
    );
  }

  /// Create a new robot from MQTT data when robot doesn't exist in state
  Robot _createRobotFromMqtt(String robotId, String status) {
    print('RobotProvider: Creating robot $robotId with status: $status');

    // Create mock containers for the robot
    final containers = _createMockContainers(robotId);

    // Create robot with enhanced mock data
    final robot = Robot(
      robotCode: robotId,
      name: 'Robot ${robotId.replaceAll('ROBOT-', '')}',
      status: status,
      online: status == 'free',
      batteryLevel: _generateMockBatteryLevel(robotId.replaceAll('ROBOT-', '')),
      currentLocation: _generateMockLocation(robotId.replaceAll('ROBOT-', '')),
      estimatedArrival: _generateMockETA(robotId.replaceAll('ROBOT-', '')),
      freeContainers: containers,
      totalFreeContainers: containers.where((c) => c.isAvailable).length,
    );

    print('RobotProvider: Created robot: ${robot.displayName}');
    print('RobotProvider: - Status: ${robot.status}');
    print('RobotProvider: - Is Available: ${robot.isAvailable}');
    print('RobotProvider: - Containers: ${robot.totalFreeContainers}');

    return robot;
  }

  /// Create mock containers for a robot
  List<Container> _createMockContainers(String robotId) {
    // Create 2-3 containers per robot
    return List.generate(2, (index) {
      final containerIndex = index + 1;
      final containerCode =
          '${robotId.replaceAll('ROBOT-', 'R')}_C-$containerIndex';

      return Container(
        containerCode: containerCode,
        name: 'Container $containerIndex',
        status: 'free', // Start with free status
        capacity: '5kg',
        dimensions: '30x20x15cm',
      );
    });
  }

  /// Create a single container from MQTT data
  Container _createContainerFromMqtt(String containerId, String status) {
    print(
      'RobotProvider: Creating container $containerId with status: $status',
    );

    // Extract container number from container ID (e.g., R-001_C-1 -> 1)
    final containerNumber = containerId.split('_C-').last;

    return Container(
      containerCode: containerId,
      name: 'Container $containerNumber',
      status: status,
      capacity: '5kg',
      dimensions: '30x20x15cm',
    );
  }

  /// Generate mock battery level based on robot ID
  int _generateMockBatteryLevel(String robotNumber) {
    // Generate deterministic battery levels based on robot number
    final robotNum = int.tryParse(robotNumber) ?? 1;
    return 70 + (robotNum * 5) % 25; // Range: 70-95%
  }

  /// Generate mock location based on robot ID
  String _generateMockLocation(String robotNumber) {
    final locations = [
      'Charging Station A',
      'Warehouse Floor B',
      'Loading Dock C',
      'Storage Area D',
      'Processing Zone E',
    ];
    final robotNum = int.tryParse(robotNumber) ?? 1;
    return locations[(robotNum - 1) % locations.length];
  }

  /// Generate mock ETA based on robot ID
  String _generateMockETA(String robotNumber) {
    final robotNum = int.tryParse(robotNumber) ?? 1;
    final minutes = 2 + (robotNum * 3) % 15; // Range: 2-17 minutes
    return '${minutes}min';
  }

  /// Update state with new robot list and trigger callbacks if robots become available
  void _updateStateWithRobots(List<Robot> updatedRobots, String message) {
    // Store previous state for comparison
    final previousFreeRobotCount = state.isLoaded ? state.freeRobots.length : 0;
    final previousTotalFreeContainers = state.isLoaded
        ? state.totalFreeContainers
        : 0;

    // Separate updated robots into free and busy
    final freeRobots = updatedRobots
        .where((robot) => robot.isAvailable)
        .toList();
    final busyRobots = updatedRobots
        .where((robot) => !robot.isAvailable)
        .toList();

    // Calculate total free containers
    final totalFreeContainers = freeRobots
        .map((robot) => robot.totalFreeContainers)
        .fold<int>(0, (sum, count) => sum + count);

    // Update state with real-time data
    state = RobotState.loaded(
      freeRobots: freeRobots,
      busyRobots: busyRobots,
      totalFreeContainers: totalFreeContainers,
      message: '$message at ${DateTime.now().toLocal()}',
    );

    print(
      'RobotProvider: State updated - Free robots: ${freeRobots.length}, Busy robots: ${busyRobots.length}, Total free containers: $totalFreeContainers',
    );
    print('RobotProvider: 🔄 UI should reload now!');

    // Check if robots became available and trigger callback for UI refresh
    final robotsBecameAvailable =
        freeRobots.length > previousFreeRobotCount ||
        totalFreeContainers > previousTotalFreeContainers;

    if (robotsBecameAvailable) {
      print(
        'RobotProvider: 🟢 Robots became available! Triggering UI refresh callback...',
      );
      print(
        'RobotProvider: Previous: ${previousFreeRobotCount} free robots, ${previousTotalFreeContainers} free containers',
      );
      print(
        'RobotProvider: Current: ${freeRobots.length} free robots, ${totalFreeContainers} free containers',
      );
      onRobotsAvailable?.call();
    } else {
      print(
        'RobotProvider: No new robots became available (${previousFreeRobotCount} -> ${freeRobots.length} free robots)',
      );
    }
  }

  /// Load all available robots
  Future<void> loadRobots() async {
    if (state.isLoading) return; // Prevent multiple simultaneous requests

    state = const RobotState.loading();

    try {
      final response = await RobotService.requestRobotStatus();

      if (response != null && response.success) {
        final allRobots = response.data.freeRobots;

        // Enhance robots with mock data for better UI display
        final enhancedRobots = allRobots
            .map((robot) => _enhanceRobotData(robot))
            .toList();

        // Separate free and busy robots
        final freeRobots = enhancedRobots
            .where((robot) => robot.isAvailable)
            .toList();
        final busyRobots = enhancedRobots
            .where((robot) => !robot.isAvailable)
            .toList();

        // Calculate total free containers
        final totalFreeContainers = freeRobots
            .map((robot) => robot.totalFreeContainers)
            .fold(0, (sum, count) => sum + count);

        state = RobotState.loaded(
          freeRobots: freeRobots,
          busyRobots: busyRobots,
          totalFreeContainers: totalFreeContainers,
          message: response.data.message,
        );

        print(
          'RobotProvider: Successfully loaded ${freeRobots.length} free robots and ${busyRobots.length} busy robots',
        );
        print('RobotProvider: 🔄 Robot data loaded - UI should refresh now!');
        print(
          'RobotProvider: Free robot IDs: ${freeRobots.map((r) => r.robotCode).join(", ")}',
        );
      } else {
        final errorMessage = response?.message ?? 'Failed to load robots';
        state = RobotState.error(errorMessage: errorMessage);
        print('RobotProvider: Error loading robots: $errorMessage');
      }
    } catch (e, stackTrace) {
      final errorMessage = 'Error loading robots: $e';
      state = RobotState.error(errorMessage: errorMessage);
      print('RobotProvider: Exception loading robots: $e');
      print('RobotProvider: Stack trace: $stackTrace');
    }
  }

  /// Enhance robot data with mock information for better UI display
  Robot _enhanceRobotData(Robot robot) {
    // Extract robot number for deterministic data generation
    final robotNumber = robot.robotCode.replaceAll('ROBOT-', '');

    return robot.copyWith(
      batteryLevel:
          robot.batteryLevel ?? _generateMockBatteryLevel(robotNumber),
      currentLocation:
          robot.currentLocation ?? _generateMockLocation(robotNumber),
      estimatedArrival: robot.estimatedArrival ?? _generateMockETA(robotNumber),
    );
  }

  /// Load specific robots by codes
  Future<void> loadSpecificRobots(List<String> robotCodes) async {
    if (state.isLoading) return;

    state = const RobotState.loading();

    try {
      final response = await RobotService.requestSpecificRobotStatus(
        robotCodes,
      );

      if (response != null && response.success) {
        final allRobots = response.data.freeRobots;

        // Enhance robots with mock data for better UI display
        final enhancedRobots = allRobots
            .map((robot) => _enhanceRobotData(robot))
            .toList();

        // Separate free and busy robots
        final freeRobots = enhancedRobots
            .where((robot) => robot.isAvailable)
            .toList();
        final busyRobots = enhancedRobots
            .where((robot) => !robot.isAvailable)
            .toList();

        // Calculate total free containers
        final totalFreeContainers = freeRobots
            .map((robot) => robot.totalFreeContainers)
            .fold(0, (sum, count) => sum + count);

        state = RobotState.loaded(
          freeRobots: freeRobots,
          busyRobots: busyRobots,
          totalFreeContainers: totalFreeContainers,
          message: response.data.message,
        );
      } else {
        final errorMessage =
            response?.message ?? 'Failed to load specific robots';
        state = RobotState.error(errorMessage: errorMessage);
      }
    } catch (e) {
      final errorMessage = 'Error loading specific robots: $e';
      state = RobotState.error(errorMessage: errorMessage);
    }
  }

  /// Refresh robot data
  Future<void> refresh() async {
    await loadRobots();
  }

  /// Reset state to initial
  void reset() {
    state = const RobotState.initial();
  }

  /// Update robot status from MQTT payload handler
  /// This method is called by the global payload handler
  void updateRobotStatus({
    required String robotId,
    required String status,
    required Map<String, dynamic> payload,
  }) {
    try {
      print(
        'RobotProvider: External update for robot $robotId status: $status',
      );

      // Re-use existing handler for consistency
      _handleRobotStatusUpdate(payload);
    } catch (e) {
      print('RobotProvider: Error in updateRobotStatus: $e');
    }
  }

  /// Update robot location from MQTT payload handler
  void updateRobotLocation({
    required String robotId,
    required String location,
    dynamic coordinates,
    required Map<String, dynamic> payload,
  }) {
    try {
      print(
        'RobotProvider: External update for robot $robotId location: $location',
      );

      // Create a location update payload and process it
      final locationData = {
        'robotId': robotId,
        'location': location,
        'coordinates': coordinates,
        'messageType': 'robot_location',
        ...payload,
      };

      _handleRobotLocationUpdate(locationData);
    } catch (e) {
      print('RobotProvider: Error in updateRobotLocation: $e');
    }
  }

  /// Update robot trip progress from MQTT payload handler
  void updateRobotTripProgress({
    required String robotId,
    required String tripCode,
    required double progress,
    required Map<String, dynamic> payload,
  }) {
    try {
      // Get current state
      final currentState = state;
      if (!currentState.isLoaded) return;

      // Find the robot
      final allRobots = [
        ...currentState.freeRobots,
        ...currentState.busyRobots,
      ];
      final robotIndex = allRobots.indexWhere((r) => r.robotCode == robotId);

      if (robotIndex >= 0) {
        final robot = allRobots[robotIndex];

        // Update robot with trip info (using available fields)
        final progressPercentage = (progress * 100).toInt();
        final updatedRobot = robot.copyWith(
          status: 'busy', // Mark as busy while on trip
          name: '${robot.name ?? robot.displayName} (Trip: $tripCode)',
          currentLocation: 'On delivery - ${progressPercentage}% complete',
          estimatedArrival: 'Progress: ${progressPercentage}%',
        );

        // Update busy robots list
        state = state.copyWith(
          busyRobots: [
            ...state.busyRobots.where((r) => r.robotCode != robotId),
            updatedRobot,
          ],
          // Remove from free robots if it was there
          freeRobots: [
            ...state.freeRobots.where((r) => r.robotCode != robotId),
          ],
        );

        print(
          'RobotProvider: Updated trip progress for robot $robotId: $progress',
        );
      }
    } catch (e) {
      print('RobotProvider: Error in updateRobotTripProgress: $e');
    }
  }
}

final robotProvider = StateNotifierProvider<RobotNotifier, RobotState>((ref) {
  return RobotNotifier();
});
