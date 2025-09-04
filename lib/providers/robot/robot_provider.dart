import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zippy/models/entity/robot/robot.dart';
import 'package:zippy/models/entity/robot/container.dart';
import 'package:zippy/models/dto/mqtt/robot_heartbeat_dto.dart';
import 'package:zippy/models/dto/mqtt/robot_container_dto.dart';
import 'package:zippy/services/robot/robot_service.dart';
import 'package:zippy/state/robot/robot_state.dart';

class RobotNotifier extends StateNotifier<RobotState> {
  /// Callback for when robots become available (for UI refresh)
  static Function()? onRobotsAvailable;

  RobotNotifier() : super(const RobotState.initial());

  /// Load all robots from /api/robots
  Future<void> loadRobots() async {
    if (state.isLoading) return; // Prevent multiple simultaneous requests

    state = const RobotState.loading();

    try {
      final response = await RobotService.fetchAllRobots();

      if (response != null && response.success) {
        final allRobots = response.data;

        // Enhance robots with UI-friendly data
        final enhancedRobots = allRobots
            .map((robot) => _enhanceRobotData(robot))
            .toList();

        // Categorize robots based on their current status
        final freeRobots = enhancedRobots
            .where((robot) => robot.currentStatus == 'free')
            .toList();
        final busyRobots = enhancedRobots
            .where((robot) => robot.currentStatus != 'free')
            .toList();

        state = RobotState.loaded(
          freeRobots: freeRobots,
          busyRobots: busyRobots,
          message: response.message,
        );

        print(
          'RobotProvider: Successfully loaded ${freeRobots.length} free robots and ${busyRobots.length} busy robots',
        );
        print('RobotProvider: 🔄 Robot data loaded - UI should refresh now!');
        print(
          'RobotProvider: Free robot IDs: ${freeRobots.map((r) => r.robotCode).join(", ")}',
        );

        // Trigger callback for UI refresh
        onRobotsAvailable?.call();
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

  /// Enhance robot data with additional UI-friendly information
  Robot _enhanceRobotData(Robot robot) {
    // Parse battery status as percentage
    int batteryLevel = 75; // default
    try {
      batteryLevel = double.parse(robot.batteryStatus).round();
    } catch (e) {
      // Keep default if parsing fails
    }

    return robot.copyWith(
      batteryLevel: batteryLevel,
      status: 'free', // All robots are available for booking
      online: true,
    );
  }

  /// Handle robot heartbeat MQTT message from topic: robot/+/heartbeat
  void updateRobotHeartbeat(String robotCode, RobotHeartbeatDto heartbeat) {
    if (!state.isLoaded) return;

    final currentRobots = [...state.freeRobots, ...state.busyRobots];
    final robotIndex = currentRobots.indexWhere((r) => r.code == robotCode);

    if (robotIndex == -1) {
      print('RobotProvider: Robot $robotCode not found for heartbeat update');
      return;
    }

    final updatedRobots = List<Robot>.from(currentRobots);
    updatedRobots[robotIndex] = updatedRobots[robotIndex].copyWith(
      isAlive: heartbeat.isAlive,
      lastHeartbeat: heartbeat.timestamp,
    );

    _updateStateWithRobots(updatedRobots);
    print(
      'RobotProvider: Updated heartbeat for robot $robotCode - alive: ${heartbeat.isAlive}',
    );
  }

  /// Handle robot container MQTT message from topic: robot/+/container
  void updateRobotContainer(
    String robotCode,
    String containerId,
    RobotContainerDto containerData,
  ) {
    if (!state.isLoaded) return;

    final currentRobots = [...state.freeRobots, ...state.busyRobots];
    final robotIndex = currentRobots.indexWhere((r) => r.code == robotCode);

    if (robotIndex == -1) {
      print('RobotProvider: Robot $robotCode not found for container update');
      return;
    }

    final robot = currentRobots[robotIndex];
    final updatedContainers = List<Container>.from(robot.containers);

    // Find existing container or add new one
    final containerIndex = updatedContainers.indexWhere(
      (c) => c.containerId == containerId,
    );

    final updatedContainer = Container(
      containerId: containerId,
      isClosed: containerData.isClosed,
      status: containerData.status,
      weight: containerData.weight,
    );

    if (containerIndex == -1) {
      updatedContainers.add(updatedContainer);
    } else {
      updatedContainers[containerIndex] = updatedContainer;
    }

    final updatedRobots = List<Robot>.from(currentRobots);
    updatedRobots[robotIndex] = robot.copyWith(containers: updatedContainers);

    _updateStateWithRobots(updatedRobots);
    print(
      'RobotProvider: Updated container $containerId for robot $robotCode - status: ${containerData.status}',
    );
  }

  /// Helper method to update state with new robot list
  void _updateStateWithRobots(List<Robot> allRobots) {
    final freeRobots = allRobots
        .where((robot) => robot.currentStatus == 'free')
        .toList();
    final busyRobots = allRobots
        .where((robot) => robot.currentStatus != 'free')
        .toList();

    state = RobotState.loaded(
      freeRobots: freeRobots,
      busyRobots: busyRobots,
      message: state.message,
    );

    // Trigger callback for UI refresh
    onRobotsAvailable?.call();
  }
}

// Provider instance
final robotProvider = StateNotifierProvider<RobotNotifier, RobotState>((ref) {
  return RobotNotifier();
});
