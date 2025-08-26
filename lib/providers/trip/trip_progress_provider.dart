import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/storage/trip_storage_service.dart';
import '../../services/native/background_monitoring_service.dart';
import '../../state/trip/trip_progress_state.dart';

class TripProgressNotifier extends StateNotifier<TripProgressState> {
  final String tripCode;
  final String orderCode;
  final String robotCode;

  TripProgressNotifier({
    required this.tripCode,
    required this.orderCode,
    required this.robotCode,
  }) : super(const TripProgressInitial());

  /// Initialize trip progress by loading cached data
  Future<void> initialize() async {
    state = const TripProgressLoading();

    try {
      // Load cached trip progress first
      await _loadCachedTripProgress();

      // Update app activity timestamp
      await TripStorageService().updateAppActivityTimestamp();

      // Register background monitoring
      await BackgroundMonitoringService.instance.registerMonitoring(
        robotId: robotCode,
        orderId: orderCode,
        tripId: tripCode,
      );

      print('TripProgressProvider: Initialized successfully');
    } catch (e) {
      print('TripProgressProvider: Error during initialization: $e');
      state = TripProgressError(errorMessage: e.toString());
    }
  }

  /// Update trip details (start and end points)
  void updateTripDetails({
    required String? startPoint,
    required String? endPoint,
  }) {
    if (state is TripProgressLoaded) {
      final currentState = state as TripProgressLoaded;
      state = currentState.copyWith(
        tripStartPoint: startPoint,
        tripEndPoint: endPoint,
      );
      print(
        'TripProgressProvider: Updated trip details - Start: $startPoint, End: $endPoint',
      );
    }
  }

  /// Handle MQTT message and update progress/phase
  void handleMqttMessage(Map<String, dynamic> data) {
    try {
      print('TripProgressProvider: Processing MQTT message: $data');

      // Safely convert progress to double, handling both int and double types
      double? progress;
      final progressValue = data['progress'];
      if (progressValue is num) {
        progress = progressValue.toDouble();
      }

      final payloadStartPoint = data['start_point'] as String?;
      final payloadEndPoint = data['end_point'] as String?;

      if (progress == null) {
        print(
          'TripProgressProvider: Missing or invalid progress field in MQTT message',
        );
        return;
      }

      // Check if this data is from cache
      final isFromCache = data['fromCache'] == true;

      // Only store updates from live MQTT messages, not from cached data
      if (!isFromCache) {
        print('TripProgressProvider: Storing new progress update from MQTT');
        _storeRawProgressUpdate(data);
      }

      final currentState = state;
      if (currentState is! TripProgressLoaded) {
        print('TripProgressProvider: State not loaded, cannot process message');
        return;
      }

      // Use payload points or fall back to stored trip details
      final startPoint = payloadStartPoint ?? currentState.tripStartPoint;
      final endPoint = payloadEndPoint ?? currentState.tripEndPoint;

      // Simple progress update if we don't have trip details
      if (startPoint == null || endPoint == null) {
        _updateSimpleProgress(progress);
        return;
      }

      // Complex phase-based progress calculation
      _updatePhaseBasedProgress(
        progress: progress,
        payloadStartPoint: payloadStartPoint,
        payloadEndPoint: payloadEndPoint,
        tripStartPoint: currentState.tripStartPoint!,
        tripEndPoint: currentState.tripEndPoint!,
        currentState: currentState,
      );
    } catch (e) {
      print('TripProgressProvider: Error handling MQTT message: $e');
    }
  }

  /// Update simple progress without phase calculation
  void _updateSimpleProgress(double progress) {
    final currentState = state as TripProgressLoaded;

    // Check if progress is already a percentage (>1) or a decimal fraction
    final normalizedProgress = progress > 1 ? progress / 100.0 : progress;

    state = currentState.copyWith(progress: normalizedProgress);

    print(
      'TripProgressProvider: Simple progress update: ${(normalizedProgress * 100).toStringAsFixed(1)}%',
    );
    _saveTripProgress();
  }

  /// Update progress with phase-based calculation
  void _updatePhaseBasedProgress({
    required double progress,
    required String? payloadStartPoint,
    required String? payloadEndPoint,
    required String tripStartPoint,
    required String tripEndPoint,
    required TripProgressLoaded currentState,
  }) {
    TripProgressLoaded newState = currentState;

    if (payloadEndPoint == tripStartPoint) {
      // Phase 1: Robot going to pickup location
      final normalizedProgress = progress > 1 ? progress / 100.0 : progress;
      newState = currentState.copyWith(
        progress: normalizedProgress * 0.5, // Map to first half of progress bar
        hasPickupPhase: true,
      );

      print('TripProgressProvider: Phase 1 - Robot going to pickup location');
      print(
        'TripProgressProvider: Progress mapped to first half: ${(newState.progress * 100).toStringAsFixed(1)}%',
      );

      // Check if robot reached pickup location
      if (progress >= 100.0 && !currentState.phase1NotificationSent) {
        newState = newState.copyWith(
          awaitingPhase1QR: true,
          phase1NotificationSent: true,
        );

        // Trigger phase 1 notification callback
        _onPhase1Complete?.call();
        print(
          'TripProgressProvider: Phase 1 complete - Robot reached pickup location',
        );
      }
    } else if (payloadStartPoint == tripStartPoint) {
      // Handle instant phase 1 completion
      if (!currentState.hasDeliveryPhase &&
          !currentState.phase1NotificationSent) {
        newState = newState.copyWith(
          awaitingPhase1QR: true,
          phase1NotificationSent: true,
        );
        _onPhase1Complete?.call();
        print(
          'TripProgressProvider: Phase 1 completed instantly - Robot at pickup',
        );
      }

      // Phase 2: Robot going from pickup to delivery location
      final normalizedProgress = progress > 1 ? progress / 100.0 : progress;

      if (currentState.hasPickupPhase || currentState.phase1QRScanned) {
        // Second half of progress bar
        newState = newState.copyWith(
          progress: 0.5 + (normalizedProgress * 0.5),
          hasDeliveryPhase: true,
        );
        print(
          'TripProgressProvider: Phase 2 - Robot going from pickup to delivery (after pickup phase)',
        );
      } else {
        // Direct delivery without pickup phase
        newState = newState.copyWith(
          progress: normalizedProgress,
          hasDeliveryPhase: true,
        );
        print(
          'TripProgressProvider: Phase 2 - Direct delivery (no pickup phase seen)',
        );
      }

      // Check if robot reached delivery location
      if (progress >= 100.0 && !currentState.phase2NotificationSent) {
        newState = newState.copyWith(
          awaitingPhase2QR: true,
          phase2NotificationSent: true,
        );

        // Trigger phase 2 notification callback
        _onPhase2Complete?.call();
        print(
          'TripProgressProvider: Phase 2 complete - Robot reached delivery location',
        );
      }
    } else {
      print('TripProgressProvider: No phase match found - ignoring message');
      return;
    }

    state = newState;
    print(
      'TripProgressProvider: Final progress: ${(newState.progress * 100).toStringAsFixed(1)}%',
    );

    _saveTripProgress();
  }

  /// Handle Phase 1 QR code scanned
  void onPhase1QRScanned() {
    final currentState = state;
    if (currentState is TripProgressLoaded) {
      state = currentState.copyWith(
        phase1QRScanned: true,
        awaitingPhase1QR: false,
      );

      // Update background monitoring service
      BackgroundMonitoringService.instance.markPickupQRScanned(tripCode);
      _saveTripProgress();

      print('TripProgressProvider: Phase 1 QR scanned');
    }
  }

  /// Handle Phase 2 QR code scanned
  void onPhase2QRScanned() {
    final currentState = state;
    if (currentState is TripProgressLoaded) {
      state = currentState.copyWith(
        phase2QRScanned: true,
        awaitingPhase2QR: false,
      );

      // Update background monitoring service
      BackgroundMonitoringService.instance.markDeliveryQRScanned(tripCode);
      _saveTripProgress();

      print('TripProgressProvider: Phase 2 QR scanned');
    }
  }

  /// Load cached trip progress from storage
  Future<void> _loadCachedTripProgress() async {
    try {
      final tripData = await TripStorageService().loadCachedTripProgress(
        tripCode,
        robotCode: robotCode,
      );

      if (tripData != null) {
        // Safely convert progress from cached data (might be int or double)
        double progress = 0.0;
        final progressValue = tripData['progress'];
        if (progressValue is num) {
          progress = progressValue.toDouble();
        }

        state = TripProgressLoaded(
          progress: progress,
          tripStartPoint: tripData['start_point'] as String?,
          tripEndPoint: tripData['end_point'] as String?,
          hasPickupPhase: tripData['hasPickupPhase'] as bool? ?? false,
          hasDeliveryPhase: tripData['hasDeliveryPhase'] as bool? ?? false,
          phase1QRScanned: tripData['phase1QRScanned'] as bool? ?? false,
          phase2QRScanned: tripData['phase2QRScanned'] as bool? ?? false,
          phase1NotificationSent:
              tripData['phase1NotificationSent'] as bool? ?? false,
          phase2NotificationSent:
              tripData['phase2NotificationSent'] as bool? ?? false,
          awaitingPhase1QR: tripData['awaitingPhase1QR'] as bool? ?? false,
          awaitingPhase2QR: tripData['awaitingPhase2QR'] as bool? ?? false,
        );

        // Update background monitoring service state
        BackgroundMonitoringService.instance.loadStateFromProgress(
          tripCode,
          tripData,
        );

        print('TripProgressProvider: Loaded cached progress data');
      } else {
        // Initialize with empty state
        state = const TripProgressLoaded(
          progress: 0.0,
          tripStartPoint: null,
          tripEndPoint: null,
          hasPickupPhase: false,
          hasDeliveryPhase: false,
          phase1QRScanned: false,
          phase2QRScanned: false,
          phase1NotificationSent: false,
          phase2NotificationSent: false,
          awaitingPhase1QR: false,
          awaitingPhase2QR: false,
        );
        print(
          'TripProgressProvider: No cached data found, initialized with empty state',
        );
      }
    } catch (e) {
      print('TripProgressProvider: Error loading cached progress: $e');
      throw e;
    }
  }

  /// Save current progress to storage
  Future<void> _saveTripProgress() async {
    try {
      final currentState = state;
      if (currentState is TripProgressLoaded) {
        await TripStorageService().saveTripProgress(
          tripCode: tripCode,
          orderCode: orderCode,
          robotCode: robotCode,
          progress: currentState.progress,
          hasPickupPhase: currentState.hasPickupPhase,
          hasDeliveryPhase: currentState.hasDeliveryPhase,
          phase1QRScanned: currentState.phase1QRScanned,
          phase2QRScanned: currentState.phase2QRScanned,
          phase1NotificationSent: currentState.phase1NotificationSent,
          phase2NotificationSent: currentState.phase2NotificationSent,
          awaitingPhase1QR: currentState.awaitingPhase1QR,
          awaitingPhase2QR: currentState.awaitingPhase2QR,
        );

        print(
          'TripProgressProvider: Saved progress to cache - ${(currentState.progress * 100).toStringAsFixed(1)}%',
        );
      }
    } catch (e) {
      print('TripProgressProvider: Error saving progress: $e');
    }
  }

  /// Store raw progress update
  Future<void> _storeRawProgressUpdate(Map<String, dynamic> data) async {
    try {
      await TripStorageService().storeRawProgressUpdate(
        robotCode: robotCode,
        tripCode: tripCode,
        data: data,
      );
    } catch (e) {
      print('TripProgressProvider: Error storing raw progress update: $e');
    }
  }

  /// Clear cached progress (when trip completes)
  Future<void> clearCache() async {
    try {
      await TripStorageService().clearTripProgressCache(tripCode);
      print('TripProgressProvider: Cleared cached progress data');
    } catch (e) {
      print('TripProgressProvider: Error clearing cache: $e');
    }
  }

  /// Callbacks for phase completion events
  VoidCallback? _onPhase1Complete;
  VoidCallback? _onPhase2Complete;

  /// Set callback for phase 1 completion
  void setOnPhase1Complete(VoidCallback callback) {
    _onPhase1Complete = callback;
  }

  /// Set callback for phase 2 completion
  void setOnPhase2Complete(VoidCallback callback) {
    _onPhase2Complete = callback;
  }
}

/// Provider factory function
StateNotifierProvider<TripProgressNotifier, TripProgressState>
tripProgressProvider({
  required String tripCode,
  required String orderCode,
  required String robotCode,
}) {
  return StateNotifierProvider<TripProgressNotifier, TripProgressState>((ref) {
    return TripProgressNotifier(
      tripCode: tripCode,
      orderCode: orderCode,
      robotCode: robotCode,
    );
  });
}
