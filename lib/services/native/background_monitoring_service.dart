import 'background_service.dart';
import '../notification/notification_service.dart';

/// Service for handling background monitoring of trips
/// This service manages background task registration, notifications,
/// and QR scanning phases
class BackgroundMonitoringService {
  // Singleton pattern
  static final BackgroundMonitoringService _instance =
      BackgroundMonitoringService._internal();
  static BackgroundMonitoringService get instance => _instance;
  BackgroundMonitoringService._internal();

  // State tracking for QR scanning phases
  final Map<String, bool> _phase1NotificationsSent = {};
  final Map<String, bool> _phase2NotificationsSent = {};
  final Map<String, bool> _awaitingPhase1QR = {};
  final Map<String, bool> _awaitingPhase2QR = {};
  final Map<String, bool> _phase1QRScanned = {};
  final Map<String, bool> _phase2QRScanned = {};

  // Initialize notification service
  Future<bool> initializeNotifications() async {
    try {
      await NotificationService().initialize();
      print(
        'BackgroundMonitoringService: Notification service initialized successfully',
      );
      return true;
    } catch (e) {
      print(
        'BackgroundMonitoringService: Failed to initialize notification service: $e',
      );
      print(
        'BackgroundMonitoringService: App will continue without notifications',
      );
      return false;
    }
  }

  // Register background monitoring for a delivery
  Future<bool> registerMonitoring({
    required String robotId,
    required String orderId,
    required String tripId,
    String deliveryPhase = 'pickup', // Default to pickup phase
  }) async {
    try {
      await BackgroundService.registerMqttMonitoring(
        robotId: robotId,
        orderId: orderId,
        deliveryPhase: deliveryPhase,
      );

      print(
        'BackgroundMonitoringService: Background monitoring registered for robot $robotId',
      );
      return true;
    } catch (e) {
      print(
        'BackgroundMonitoringService: Failed to register background monitoring: $e',
      );
      return false;
    }
  }

  // Send pickup phase notification
  Future<void> showPickupPhaseNotification({
    required String tripId,
    String title = 'Robot Arrived',
    String body =
        'The delivery robot has arrived at the pickup location. Please scan your QR code to verify pickup.',
  }) async {
    if (_phase1NotificationsSent[tripId] == true) {
      print(
        'BackgroundMonitoringService: Pickup notification already sent for trip $tripId',
      );
      return;
    }

    try {
      await NotificationService().showPhase1Notification(
        title: title,
        body: body,
      );

      // Mark as sent and awaiting QR scan
      _phase1NotificationsSent[tripId] = true;
      _awaitingPhase1QR[tripId] = true;

      print(
        'BackgroundMonitoringService: Pickup phase notification sent for trip $tripId',
      );
    } catch (e) {
      print(
        'BackgroundMonitoringService: Failed to show pickup phase notification: $e',
      );
    }
  }

  // Send delivery phase notification
  Future<void> showDeliveryPhaseNotification({
    required String tripId,
    String title = 'Robot Arrived',
    String body =
        'The delivery robot has arrived at your location. Please scan your QR code to receive your delivery.',
  }) async {
    if (_phase2NotificationsSent[tripId] == true) {
      print(
        'BackgroundMonitoringService: Delivery notification already sent for trip $tripId',
      );
      return;
    }

    try {
      await NotificationService().showPhase2Notification(
        title: title,
        body: body,
      );

      // Mark as sent and awaiting QR scan
      _phase2NotificationsSent[tripId] = true;
      _awaitingPhase2QR[tripId] = true;

      print(
        'BackgroundMonitoringService: Delivery phase notification sent for trip $tripId',
      );
    } catch (e) {
      print(
        'BackgroundMonitoringService: Failed to show delivery phase notification: $e',
      );
    }
  }

  // Methods to update state of QR scanning phases
  void markPickupQRScanned(String tripId) {
    _phase1QRScanned[tripId] = true;
    _awaitingPhase1QR[tripId] = false;
  }

  void markDeliveryQRScanned(String tripId) {
    _phase2QRScanned[tripId] = true;
    _awaitingPhase2QR[tripId] = false;
  }

  // State getters
  bool isAwaitingPickupQR(String tripId) => _awaitingPhase1QR[tripId] == true;
  bool isAwaitingDeliveryQR(String tripId) => _awaitingPhase2QR[tripId] == true;
  bool isPickupQRScanned(String tripId) => _phase1QRScanned[tripId] == true;
  bool isDeliveryQRScanned(String tripId) => _phase2QRScanned[tripId] == true;
  bool wasPickupNotificationSent(String tripId) =>
      _phase1NotificationsSent[tripId] == true;
  bool wasDeliveryNotificationSent(String tripId) =>
      _phase2NotificationsSent[tripId] == true;

  // Load state from saved progress data
  void loadStateFromProgress(
    String tripId,
    Map<String, dynamic>? progressData,
  ) {
    if (progressData == null) return;

    _phase1QRScanned[tripId] = progressData['phase1QRScanned'] ?? false;
    _phase2QRScanned[tripId] = progressData['phase2QRScanned'] ?? false;
    _phase1NotificationsSent[tripId] =
        progressData['phase1NotificationSent'] ?? false;
    _phase2NotificationsSent[tripId] =
        progressData['phase2NotificationSent'] ?? false;
    _awaitingPhase1QR[tripId] = progressData['awaitingPhase1QR'] ?? false;
    _awaitingPhase2QR[tripId] = progressData['awaitingPhase2QR'] ?? false;

    print(
      'BackgroundMonitoringService: Loaded state for trip $tripId: $progressData',
    );
  }

  // Get current state for saving to persistent storage
  Map<String, bool> getTripState(String tripId) {
    return {
      'phase1QRScanned': _phase1QRScanned[tripId] ?? false,
      'phase2QRScanned': _phase2QRScanned[tripId] ?? false,
      'phase1NotificationSent': _phase1NotificationsSent[tripId] ?? false,
      'phase2NotificationSent': _phase2NotificationsSent[tripId] ?? false,
      'awaitingPhase1QR': _awaitingPhase1QR[tripId] ?? false,
      'awaitingPhase2QR': _awaitingPhase2QR[tripId] ?? false,
    };
  }
}
