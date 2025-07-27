import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zippy/models/entity/robot/robot.dart';
import 'package:zippy/services/robot/robot_service.dart';
import 'package:zippy/state/robot/robot_state.dart';

class RobotNotifier extends StateNotifier<RobotState> {
  RobotNotifier() : super(const RobotState.initial());

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

  /// Enhance robot data with mock information for better UI display
  Robot _enhanceRobotData(Robot robot) {
    // Generate mock data based on robot code for consistent display
    final robotNumber = robot.robotCode.replaceAll('ROBOT-', '');
    final mockBatteryLevel = _generateMockBatteryLevel(robotNumber);
    final mockLocation = _generateMockLocation(robotNumber);
    final mockETA = _generateMockETA(robotNumber);

    // Enhance containers with display information
    final enhancedContainers = robot.freeContainers.map((container) {
      return container.copyWith(
        capacity: '5kg', // Standard capacity
        dimensions: '30x20x15cm', // Standard dimensions
        name: container.displayName, // Use the computed display name
      );
    }).toList();

    return robot.copyWith(
      name: robot.displayName,
      batteryLevel: mockBatteryLevel,
      currentLocation: mockLocation,
      estimatedArrival: mockETA,
      freeContainers: enhancedContainers,
    );
  }

  /// Generate mock battery level based on robot code
  int _generateMockBatteryLevel(String robotNumber) {
    try {
      final number = int.parse(robotNumber);
      // Generate consistent battery levels between 60-95%
      return 60 + ((number * 7) % 36);
    } catch (e) {
      return 75; // Default battery level
    }
  }

  /// Generate mock location based on robot code
  String _generateMockLocation(String robotNumber) {
    try {
      final number = int.parse(robotNumber);
      final locations = [
        'Charging Station A',
        'Warehouse B',
        'Main Hub',
        'Storage Area C',
        'Dock Station',
        'Service Bay',
      ];
      return locations[number % locations.length];
    } catch (e) {
      return 'Main Hub';
    }
  }

  /// Generate mock ETA based on robot code
  String _generateMockETA(String robotNumber) {
    try {
      final number = int.parse(robotNumber);
      final etas = [
        '3 minutes',
        '5 minutes',
        '7 minutes',
        '4 minutes',
        '6 minutes',
        '8 minutes',
      ];
      return etas[number % etas.length];
    } catch (e) {
      return '5 minutes';
    }
  }
}

// Provider definition
final robotProvider = StateNotifierProvider<RobotNotifier, RobotState>((ref) {
  return RobotNotifier();
});
