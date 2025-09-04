import 'package:zippy/models/entity/robot/robot.dart';

enum RobotStateStatus { initial, loading, loaded, error }

class RobotState {
  final RobotStateStatus status;
  final List<Robot> freeRobots;
  final List<Robot> busyRobots;
  final String? message;
  final String? errorMessage;

  const RobotState({
    required this.status,
    this.freeRobots = const [],
    this.busyRobots = const [],
    this.message,
    this.errorMessage,
  });

  const RobotState.initial()
    : status = RobotStateStatus.initial,
      freeRobots = const [],
      busyRobots = const [],
      message = null,
      errorMessage = null;

  const RobotState.loading()
    : status = RobotStateStatus.loading,
      freeRobots = const [],
      busyRobots = const [],
      message = null,
      errorMessage = null;

  RobotState.loaded({
    required this.freeRobots,
    required this.busyRobots,
    this.message,
  }) : status = RobotStateStatus.loaded,
       errorMessage = null;

  RobotState.error({
    required this.errorMessage,
    this.freeRobots = const [],
    this.busyRobots = const [],
  }) : status = RobotStateStatus.error,
       message = null;
  RobotState copyWith({
    RobotStateStatus? status,
    List<Robot>? freeRobots,
    List<Robot>? busyRobots,
    String? message,
    String? errorMessage,
  }) {
    return RobotState(
      status: status ?? this.status,
      freeRobots: freeRobots ?? this.freeRobots,
      busyRobots: busyRobots ?? this.busyRobots,
      message: message ?? this.message,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isLoading => status == RobotStateStatus.loading;
  bool get isLoaded => status == RobotStateStatus.loaded;
  bool get isError => status == RobotStateStatus.error;
  bool get hasData => freeRobots.isNotEmpty || busyRobots.isNotEmpty;
}
