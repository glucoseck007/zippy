import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notification/notification_service.dart';
import '../storage/trip_storage_service.dart';
import 'mqtt_service.dart';
import '../../providers/robot/robot_provider.dart';
import '../../models/dto/mqtt/robot_heartbeat_dto.dart';
import '../../models/dto/mqtt/robot_container_dto.dart';
import '../../models/dto/mqtt/trip_state_mqtt_dto.dart';

/// A service that handles all MQTT payload processing across app states
/// (active, background, launching, hidden, etc.)
class MqttPayloadHandler {
  static MqttPayloadHandler? _instance;
  static MqttPayloadHandler get instance =>
      _instance ??= MqttPayloadHandler._();

  MqttPayloadHandler._();
  ProviderContainer? _providerContainer;

  bool _isInitialized = false;
  Function(Map<String, dynamic>)? _originalCallback;

  // Initialize with a provider container for state updates
  Future<void> initialize(ProviderContainer container) async {
    if (_isInitialized) return;

    _providerContainer = container;
    _setupMessageHandler();

    _isInitialized = true;
    print('MqttPayloadHandler: Initialized');
  }

  // Set up global message handler
  void _setupMessageHandler() {
    _originalCallback = MqttService.onRobotStatusUpdate;
    MqttService.onRobotStatusUpdate = _globalMessageHandler;
    print('MqttPayloadHandler: Global message handler attached');
  }

  /// The main message handler that processes all MQTT payloads
  Future<void> _globalMessageHandler(Map<String, dynamic> data) async {
    try {
      print('MqttPayloadHandler: Processing message - ${data['topic']}');

      // Process by topic type
      final topic = data['topic'] as String?;
      if (topic == null) {
        print('MqttPayloadHandler: Missing topic in message');
        return;
      }

      // Handle robot heartbeat updates (format: robot/{robotCode}/heartbeat)
      if (topic.contains('robot') && topic.contains('heartbeat')) {
        await _processRobotHeartbeatMessage(data);
      }
      // Handle robot container updates (format: robot/{robotCode}/container)
      else if (topic.contains('robot') && topic.contains('container')) {
        await _processRobotContainerMessage(data);
      }
      // Handle trip progress updates via format: robot/{robotCode}/trip
      else if (topic.contains('robot') && topic.contains('trip') && !topic.contains('trip/state')) {
        await _processRobotTripMessage(data);
      }
      // Handle trip state updates via format: robot/{robotCode}/trip/state
      else if (topic.contains('robot') && topic.contains('trip/state')) {
        await _processRobotTripStateMessage(data);
      }
      // Handle robot location updates (format: robot/{robotCode}/location)
      else if (topic.contains('robot') && topic.contains('location')) {
        await _processRobotLocationMessage(data);
      }
      // Handle robot battery updates
      else if (topic.contains('robot') && topic.contains('battery')) {
        await _processRobotBatteryMessage(data);
      }
      // Handle robot QR code updates
      else if (topic.contains('robot') && topic.contains('qr-code')) {
        await _processRobotQrCodeMessage(data);
      }
      // Handle robot force move updates
      else if (topic.contains('robot') && topic.contains('force_move')) {
        await _processRobotForceMoveMessage(data);
      }
      // Handle robot warning updates
      else if (topic.contains('robot') && topic.contains('warning')) {
        await _processRobotWarningMessage(data);
      }

      // Forward to original callback if any (like UI-specific handlers)
      // We need to ensure the callback gets called with the same topic format
      // so the TripProgressScreen can process it
      if (_originalCallback != null) {
        _originalCallback!(data);
      }

      // Persist the latest payload for possible app launch
      await _persistPayload(topic, data);
    } catch (e) {
      print('MqttPayloadHandler: Error processing message: $e');
    }
  }

  /// Process robot heartbeat messages from topic: robot/{robotCode}/heartbeat
  /// Payload: {isAlive: bool, timestamp: string}
  Future<void> _processRobotHeartbeatMessage(Map<String, dynamic> data) async {
    try {
      final topic = data['topic'] as String?;
      if (topic == null) return;

      // Extract robot code from topic (format: robot/{robotCode}/heartbeat)
      final topicParts = topic.split('/');
      if (topicParts.length < 3 ||
          topicParts[0] != 'robot' ||
          topicParts[2] != 'heartbeat') {
        print(
          'MqttPayloadHandler: Invalid robot heartbeat topic format: $topic',
        );
        return;
      }

      final robotCode = topicParts[1];

      // Create heartbeat DTO from payload
      final heartbeatDto = RobotHeartbeatDto.fromJson(data);

      print(
        'MqttPayloadHandler: Robot heartbeat - Robot: $robotCode, Alive: ${heartbeatDto.isAlive}, Time: ${heartbeatDto.timestamp}',
      );

      // Update robot heartbeat via provider
      if (_providerContainer != null) {
        try {
          _providerContainer!
              .read(robotProvider.notifier)
              .updateRobotHeartbeat(robotCode, heartbeatDto);
        } catch (e) {
          print('MqttPayloadHandler: Error updating robot heartbeat: $e');
        }
      }
    } catch (e) {
      print('MqttPayloadHandler: Error processing robot heartbeat message: $e');
    }
  }

  /// Process robot trip messages (format: robot/{robotCode}/trip)
  /// Payload: {trip_id, progress, status, start_point, end_point}
  Future<void> _processRobotTripMessage(Map<String, dynamic> data) async {
    try {
      final topic = data['topic'] as String?;
      if (topic == null) return;

      // Extract robot code from topic (format: robot/{robotCode}/trip)
      final topicParts = topic.split('/');
      if (topicParts.length < 3 ||
          topicParts[0] != 'robot' ||
          topicParts[2] != 'trip') {
        print('MqttPayloadHandler: Invalid robot trip topic format: $topic');
        return;
      }

      final robotId = topicParts[1];

      // Create trip state DTO from payload
      final tripStateDto = TripStateMqttDto.fromJson(data);

      if (robotId.isEmpty || tripStateDto.tripId.isEmpty) {
        print(
          'MqttPayloadHandler: Missing robot ID or trip_id from payload: robotId=$robotId, trip_id=${tripStateDto.tripId}',
        );
        return;
      }

      // Check if this data is from cache (has the marker we added)
      final isFromCache = data['fromCache'] == true;

      print(
        'MqttPayloadHandler: Processing robot trip - Robot: $robotId, Trip: ${tripStateDto.tripId}, Status: ${tripStateDto.status} (${tripStateDto.statusName}), Progress: ${tripStateDto.progress}, FromCache: $isFromCache',
      );

      // Persist trip progress (the _persistTripProgress method will check isFromCache again)
      await _persistTripProgress(tripStateDto.tripId, data);

      // Update robot state if applicable
      if (_providerContainer != null) {
        // Create an enhanced payload with all needed information
        final enhancedPayload = {
          ...data,
          'robotId': robotId,
          'tripCode':
              tripStateDto.tripId, // For compatibility with existing code
          'start_point': tripStateDto.startPoint,
          'end_point': tripStateDto.endPoint,
          // For compatibility with other processors
          'messageType': 'trip_progress',
        };

        // Generate status-based notifications
        await _generateTripProgressNotifications(
          tripStateDto.tripId,
          tripStateDto.progress,
          tripStateDto.status
              .toString(), // Convert int status to string for compatibility
          enhancedPayload,
        );
      }
    } catch (e) {
      print('MqttPayloadHandler: Error processing robot trip message: $e');
    }
  }

  /// Process robot trip state messages from topic: robot/{robotCode}/trip/state
  /// Payload: {trip_id (tripCode), progress, status, start_point, end_point}
  /// Specifically handles status 1 (QR verify first time) and status 4 (QR verify last time)
  Future<void> _processRobotTripStateMessage(Map<String, dynamic> data) async {
    try {
      final topic = data['topic'] as String?;
      if (topic == null) return;

      // Extract robot code from topic (format: robot/{robotCode}/trip/state)
      final topicParts = topic.split('/');
      if (topicParts.length < 4 ||
          topicParts[0] != 'robot' ||
          topicParts[2] != 'trip' ||
          topicParts[3] != 'state') {
        print(
          'MqttPayloadHandler: Invalid robot trip state topic format: $topic',
        );
        return;
      }

      final robotId = topicParts[1];

      // Create trip state DTO from payload
      final tripStateDto = TripStateMqttDto.fromJson(data);

      if (robotId.isEmpty || tripStateDto.tripId.isEmpty) {
        print(
          'MqttPayloadHandler: Missing robot ID or trip_id from trip state payload: robotId=$robotId, trip_id=${tripStateDto.tripId}',
        );
        return;
      }

      // Check if this data is from cache (has the marker we added)
      final isFromCache = data['fromCache'] == true;

      print(
        'MqttPayloadHandler: Processing robot trip state - Robot: $robotId, Trip: ${tripStateDto.tripId}, Status: ${tripStateDto.status} (${tripStateDto.statusName}), Progress: ${tripStateDto.progress}, FromCache: $isFromCache',
      );

      // Generate notifications for specific statuses (1 and 4)
      await _generateNotificationsForTripState(
        robotId,
        tripStateDto.tripId,
        tripStateDto.status,
        tripStateDto.startPoint,
        tripStateDto.endPoint,
      );

      // Update robot state if applicable and forward to UI
      if (_providerContainer != null) {
        // Create an enhanced payload with all needed information
        final enhancedPayload = {
          ...data,
          'robotId': robotId,
          'tripCode': tripStateDto.tripId,
          'start_point': tripStateDto.startPoint,
          'end_point': tripStateDto.endPoint,
          'messageType': 'trip_state',
        };

        // Forward to original callback for UI updates if any
        if (_originalCallback != null) {
          _originalCallback!(enhancedPayload);
        }
      }

      // Persist the trip state for possible app launch
      await _persistPayload(topic, data);
    } catch (e) {
      print('MqttPayloadHandler: Error processing robot trip state message: $e');
    }
  }

  /// Process robot location messages (payload will send roomCode)
  /// Note: This is kept for compatibility but only handles notifications
  /// Robot location updates should go through heartbeat/container messages
  Future<void> _processRobotLocationMessage(Map<String, dynamic> data) async {
    final robotId = data['robotId'] as String?;
    final location = data['location'] as String?;
    final roomCode = data['roomCode'] as String?;

    if (robotId == null) return;

    final locationInfo = location ?? roomCode ?? 'Unknown location';

    print(
      'MqttPayloadHandler: Robot location update - Robot: $robotId, Location: $locationInfo',
    );

    // Note: Robot provider doesn't have updateRobotLocation method
    // Location updates should be handled through other means or the provider needs this method
  }

  /// Process robot battery messages
  /// Note: Battery updates should be handled through heartbeat messages or require new provider method
  Future<void> _processRobotBatteryMessage(Map<String, dynamic> data) async {
    final robotId = data['robotId'] as String?;
    final batteryLevel = data['battery_level'] as num?;

    if (robotId == null || batteryLevel == null) return;

    print(
      'MqttPayloadHandler: Robot battery update - Robot: $robotId, Battery: $batteryLevel%',
    );

    // Note: Robot provider doesn't have updateRobotStatus method
    // Battery updates should be handled through other means or the provider needs this method

    // Generate low battery notifications if needed
    if (batteryLevel <= 20) {
      await NotificationService().showPhase2Notification(
        title: 'Robot Battery Low',
        body: 'Robot $robotId battery is at $batteryLevel%',
      );
    }
  }

  /// Process robot container messages from topic: robot/{robotCode}/container
  /// Payload: {isClosed: bool, status: string, weight: double}
  Future<void> _processRobotContainerMessage(Map<String, dynamic> data) async {
    try {
      final topic = data['topic'] as String?;
      if (topic == null) return;

      // Extract robot code from topic (format: robot/{robotCode}/container)
      final topicParts = topic.split('/');
      if (topicParts.length < 3 ||
          topicParts[0] != 'robot' ||
          topicParts[2] != 'container') {
        print(
          'MqttPayloadHandler: Invalid robot container topic format: $topic',
        );
        return;
      }

      final robotCode = topicParts[1];

      // Create container DTO from payload
      final containerDto = RobotContainerDto.fromJson(data);

      // Extract container ID from data or generate one
      final containerId = data['containerId'] as String? ?? 'container_1';

      print(
        'MqttPayloadHandler: Robot container update - Robot: $robotCode, Container: $containerId, Status: ${containerDto.status}, Closed: ${containerDto.isClosed}, Weight: ${containerDto.weight}',
      );

      // Update robot container via provider
      if (_providerContainer != null) {
        try {
          _providerContainer!
              .read(robotProvider.notifier)
              .updateRobotContainer(robotCode, containerId, containerDto);
        } catch (e) {
          print('MqttPayloadHandler: Error updating robot container: $e');
        }
      }

      // Generate notifications based on container status
      await _generateContainerNotifications(
        robotCode,
        containerId,
        containerDto,
      );
    } catch (e) {
      print('MqttPayloadHandler: Error processing robot container message: $e');
    }
  }

  /// Process robot QR code messages
  Future<void> _processRobotQrCodeMessage(Map<String, dynamic> data) async {
    final robotId = data['robotId'] as String?;
    final qrData = data['qr_data'] as String?;
    final action = data['action'] as String?;

    if (robotId == null || qrData == null) return;

    print(
      'MqttPayloadHandler: QR Code scanned - Robot: $robotId, Action: $action',
    );

    // Process QR code action (e.g., container open/close)
    if (action == 'container_opened') {
      await NotificationService().showPhase1Notification(
        title: 'Container Opened',
        body: 'Robot $robotId container has been opened',
      );
    } else if (action == 'container_closed') {
      await NotificationService().showPhase2Notification(
        title: 'Container Closed',
        body: 'Robot $robotId container has been closed',
      );
    }
  }

  /// Process robot force move messages
  Future<void> _processRobotForceMoveMessage(Map<String, dynamic> data) async {
    final robotId = data['robotId'] as String?;
    final newLocation = data['new_location'] as String?;
    final reason = data['reason'] as String?;

    if (robotId == null) return;

    print(
      'MqttPayloadHandler: Robot force move - Robot: $robotId, New Location: $newLocation, Reason: $reason',
    );

    // Notify about forced movement
    await NotificationService().showPhase1Notification(
      title: 'Robot Moved',
      body:
          'Robot $robotId has been moved${newLocation != null ? ' to $newLocation' : ''}${reason != null ? ' ($reason)' : ''}',
    );

    // Note: Robot provider doesn't have updateRobotLocation method
    // Location updates should be handled through other means or the provider needs this method
  }

  /// Process robot warning messages
  Future<void> _processRobotWarningMessage(Map<String, dynamic> data) async {
    final robotId = data['robotId'] as String?;
    final warningType = data['warning_type'] as String?;
    final warningMessage = data['message'] as String?;
    final severity = data['severity'] as String?;

    if (robotId == null || warningType == null) return;

    print(
      'MqttPayloadHandler: Robot warning - Robot: $robotId, Type: $warningType, Severity: $severity',
    );

    // Generate appropriate notifications
    final notificationTitle = 'Robot Warning';
    final notificationBody =
        warningMessage ?? 'Robot $robotId has a $warningType warning';

    await NotificationService().showPhase2Notification(
      title: notificationTitle,
      body: notificationBody,
    );

    // Note: Robot provider doesn't have updateRobotStatus method
    // Warning status updates should be handled through other means or the provider needs this method
  }

  /// Generate notifications for trip progress updates
  Future<void> _generateTripProgressNotifications(
    String tripCode,
    num? progress,
    String? status,
    Map<String, dynamic> data,
  ) async {
    try {
      // Get stored preferences to check what notifications we've already sent
      final prefs = await SharedPreferences.getInstance();
      String? notificationTitle;
      String? notificationBody;

      // Handle status-based notifications
      if (status != null) {
        final statusInt = int.tryParse(status);
        final notificationKey = 'trip_status_notified_${tripCode}_$status';
        final alreadyNotified = prefs.getBool(notificationKey) ?? false;

        if (!alreadyNotified && statusInt != null) {
          // Check if this is a phase completion notification
          final normalizedProgress = progress != null
              ? (progress > 1 ? progress / 100.0 : progress.toDouble())
              : 0.0;

          switch (statusInt) {
            case 1: // Load - Robot ready for loading at pickup (Phase 1 complete)
              if (normalizedProgress >= 1.0) {
                notificationTitle = 'Robot Ready for Loading';
                notificationBody =
                    'Robot has arrived at pickup location. Please scan QR code to load your items.';
              }
              break;
            case 3: // Delivered - Robot ready for unloading at delivery (Phase 2 complete)
              if (normalizedProgress >= 1.0) {
                notificationTitle = 'Robot Ready for Unloading';
                notificationBody =
                    'Robot has arrived at delivery location. Please scan QR code to receive your items.';
              }
              break;
            case 4: // Finish - Trip completed
              notificationTitle = 'Trip Completed';
              notificationBody =
                  'Trip $tripCode has been completed successfully!';
              break;
          }

          if (notificationTitle != null) {
            // Use appropriate notification type based on status
            if (statusInt == 1) {
              await NotificationService().showPhase1Notification(
                title: notificationTitle,
                body: notificationBody!,
              );
            } else {
              await NotificationService().showPhase2Notification(
                title: notificationTitle,
                body: notificationBody!,
              );
            }
            await prefs.setBool(notificationKey, true);
          }
        }
      }

      // Handle progress-based notifications
      if (progress != null) {
        // Convert to percentage for consistent handling
        final currentProgress = progress > 1
            ? progress.round()
            : (progress * 100).round();
        final lastNotifiedProgress =
            prefs.getInt('last_notified_progress_$tripCode') ?? 0;

        // Send notifications at key milestones if we haven't already
        if (currentProgress >= 100 && lastNotifiedProgress < 100) {
          notificationTitle = 'Trip Completed';
          notificationBody =
              'Trip $tripCode has been completed successfully! Your package has been delivered.';
          await prefs.setInt('last_notified_progress_$tripCode', 100);

          await NotificationService().showPhase2Notification(
            title: notificationTitle,
            body: notificationBody,
          );
        } else if (currentProgress >= 75 && lastNotifiedProgress < 75) {
          notificationTitle = 'Trip Progress Update';
          notificationBody = 'Your delivery is 75% complete.';
          await prefs.setInt('last_notified_progress_$tripCode', 75);

          await NotificationService().showProgressNotification(
            title: notificationTitle,
            body: notificationBody,
            progress: 0.75,
          );
        } else if (currentProgress >= 50 && lastNotifiedProgress < 50) {
          notificationTitle = 'Trip Progress Update';
          notificationBody = 'Your delivery is 50% complete.';
          await prefs.setInt('last_notified_progress_$tripCode', 50);

          await NotificationService().showProgressNotification(
            title: notificationTitle,
            body: notificationBody,
            progress: 0.5,
          );
        } else if (currentProgress >= 25 && lastNotifiedProgress < 25) {
          notificationTitle = 'Trip Progress Update';
          notificationBody = 'Your delivery is 25% complete.';
          await prefs.setInt('last_notified_progress_$tripCode', 25);

          await NotificationService().showProgressNotification(
            title: notificationTitle,
            body: notificationBody,
            progress: 0.25,
          );
        }
      }
    } catch (e) {
      print('MqttPayloadHandler: Error generating trip notifications: $e');
    }
  }

  /// Generate notifications for trip state updates (robot/+/trip/state)
  /// Specifically handles status 1 (QR verify first time) and status 4 (QR verify last time)
  Future<void> _generateNotificationsForTripState(
    String robotId,
    String tripId,
    int status,
    String startPoint,
    String endPoint,
  ) async {
    try {
      // Get stored preferences to check what notifications we've already sent
      final prefs = await SharedPreferences.getInstance();
      
      // Use a global key to prevent duplicates across all notification sources
      final notificationKey = 'global_trip_state_notified_${tripId}_$status';
      final alreadyNotified = prefs.getBool(notificationKey) ?? false;

      // Only send notification if we haven't already sent it for this trip and status
      if (alreadyNotified) {
        print(
          'MqttPayloadHandler: Trip state notification already sent for trip $tripId status $status (deduplication)',
        );
        return;
      }

      // Additional check: store timestamp to prevent rapid duplicates
      final timestampKey = 'global_trip_state_timestamp_${tripId}_$status';
      final lastNotificationTime = prefs.getInt(timestampKey) ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final timeSinceLastNotification = currentTime - lastNotificationTime;
      
      // Prevent notifications within 10 seconds of each other for same trip/status
      if (timeSinceLastNotification < 10000) {
        print(
          'MqttPayloadHandler: Trip state notification rate-limited for trip $tripId status $status',
        );
        return;
      }

      // Handle specific statuses for QR code verification
      switch (status) {
        case 1: // QR verify first time (scan QR for loading items)
          final notificationTitle = 'QR Code Required - Loading';
          final notificationBody =
              'Please scan QR code at ${startPoint.isNotEmpty ? startPoint : 'pickup location'} to load your items into Robot $robotId.';
          
          await NotificationService().showPhase1Notification(
            title: notificationTitle,
            body: notificationBody,
          );
          
          // Mark this notification as sent with timestamp
          await prefs.setBool(notificationKey, true);
          await prefs.setInt(timestampKey, currentTime);
          
          print(
            'MqttPayloadHandler: Trip state notification sent - $notificationTitle (Trip: $tripId, Status: $status)',
          );
          break;
        case 4: // QR verify last time (scan QR for unloading items)
          final notificationTitle = 'QR Code Required - Delivery';
          final notificationBody =
              'Please scan QR code at ${endPoint.isNotEmpty ? endPoint : 'delivery location'} to collect your items from Robot $robotId.';
          
          await NotificationService().showPhase2Notification(
            title: notificationTitle,
            body: notificationBody,
          );
          
          // Mark this notification as sent with timestamp
          await prefs.setBool(notificationKey, true);
          await prefs.setInt(timestampKey, currentTime);
          
          print(
            'MqttPayloadHandler: Trip state notification sent - $notificationTitle (Trip: $tripId, Status: $status)',
          );
          break;
        default:
          // No notifications for other statuses from trip/state topic
          print(
            'MqttPayloadHandler: Trip state status $status does not require notification',
          );
          return;
      }
    } catch (e) {
      print('MqttPayloadHandler: Error generating trip state notifications: $e');
    }
  }

  /// Clear notification flags for a completed trip to allow future notifications
  Future<void> clearTripNotificationFlags(String tripId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear all status flags for this trip
      for (int status = 1; status <= 4; status++) {
        final notificationKey = 'global_trip_state_notified_${tripId}_$status';
        final timestampKey = 'global_trip_state_timestamp_${tripId}_$status';
        
        await prefs.remove(notificationKey);
        await prefs.remove(timestampKey);
      }
      
      print('MqttPayloadHandler: Cleared notification flags for completed trip $tripId');
    } catch (e) {
      print('MqttPayloadHandler: Error clearing trip notification flags: $e');
    }
  }

  /// Generate notifications for container updates
  Future<void> _generateContainerNotifications(
    String robotCode,
    String containerId,
    RobotContainerDto containerDto,
  ) async {
    try {
      // Notify when container is opened (becomes available)
      if (containerDto.status == 'free' && !containerDto.isClosed) {
        await NotificationService().showPhase1Notification(
          title: 'Container Available',
          body:
              'Robot $robotCode container $containerId is now available for loading',
        );
      }
      // Notify when container is closed and occupied
      else if (containerDto.status != 'free' &&
          containerDto.isClosed &&
          containerDto.weight > 0) {
        await NotificationService().showPhase2Notification(
          title: 'Container Loaded',
          body:
              'Robot $robotCode container $containerId has been loaded (${containerDto.weight}kg)',
        );
      }
    } catch (e) {
      print('MqttPayloadHandler: Error generating container notifications: $e');
    }
  }

  /// Persist payload for possible future use (app relaunch, etc.)
  Future<void> _persistPayload(String topic, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Store by topic with timestamp
      final storageKey = 'mqtt_payload_${_sanitizeTopicForStorage(topic)}';
      final payloadWithMeta = {
        ...data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await prefs.setString(storageKey, jsonEncode(payloadWithMeta));

      // Also maintain a list of latest payloads
      final latestPayloadsList =
          prefs.getStringList('latest_mqtt_payloads') ?? [];
      if (!latestPayloadsList.contains(storageKey)) {
        latestPayloadsList.add(storageKey);
        // Keep list size manageable
        if (latestPayloadsList.length > 20) {
          latestPayloadsList.removeAt(0);
        }
        await prefs.setStringList('latest_mqtt_payloads', latestPayloadsList);
      }
    } catch (e) {
      print('MqttPayloadHandler: Error persisting payload: $e');
    }
  }

  /// Persist trip progress specifically
  Future<void> _persistTripProgress(
    String tripCode,
    Map<String, dynamic> data,
  ) async {
    try {
      // Check if this data is from cache (has the marker we added)
      final isFromCache = data['fromCache'] == true;

      // Skip storage if data is from cache to prevent feedback loops
      if (isFromCache) {
        print(
          'MqttPayloadHandler: Skipping storage for cached data to prevent feedback loop',
        );
        return;
      }

      // Extract robotCode from topic or data
      String? robotCode;
      final topic = data['topic'] as String?;
      if (topic != null && topic.startsWith('robot/')) {
        final parts = topic.split('/');
        if (parts.length >= 2) {
          robotCode = parts[1];
        }
      }

      robotCode ??= data['robotId'] as String? ?? 'unknown';

      // Use the TripStorageService for consistent storage across the app
      // This ensures all trip progress updates go through the same path
      await TripStorageService().storeRawProgressUpdate(
        robotCode: robotCode,
        tripCode: tripCode,
        data: data,
      );

      print(
        'MqttPayloadHandler: Persisted trip progress via TripStorageService',
      );
    } catch (e) {
      print('MqttPayloadHandler: Error persisting trip progress: $e');
    }
  }

  /// Helper to sanitize topic for storage keys
  String _sanitizeTopicForStorage(String topic) {
    return topic.replaceAll('/', '_');
  }

  /// Load latest messages for all subscribed topics
  /// Useful when the app is launched to restore state
  Future<List<Map<String, dynamic>>> loadLatestMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final latestPayloadsList =
          prefs.getStringList('latest_mqtt_payloads') ?? [];

      print(
        'MqttPayloadHandler: Found ${latestPayloadsList.length} stored payload keys',
      );

      // Map to keep only the latest message for each trip code
      final Map<String, Map<String, dynamic>> latestByTripCode = {};
      final now = DateTime.now().millisecondsSinceEpoch;
      final maxAge = 24 * 60 * 60 * 1000; // 24 hours in milliseconds

      for (final key in latestPayloadsList) {
        final json = prefs.getString(key);
        if (json != null) {
          try {
            final data = jsonDecode(json) as Map<String, dynamic>;

            // Extract trip code from topic or data
            String? tripCode;
            final topic = data['topic'] as String?;
            if (topic != null) {
              if (topic.contains('trip/')) {
                final parts = topic.split('/');
                if (parts.length >= 2) {
                  tripCode = parts[1];
                }
              } else if (topic.contains('/trip/')) {
                final parts = topic.split('/');
                for (int i = 0; i < parts.length - 1; i++) {
                  if (parts[i] == 'trip') {
                    tripCode = parts[i + 1];
                    break;
                  }
                }
              }
            }

            // Skip if we can't determine trip code
            if (tripCode == null) {
              continue;
            }

            // Check if message is too old
            final timestamp = data['timestamp'] as int? ?? 0;
            final age = now - timestamp;
            if (age > maxAge) {
              print(
                'MqttPayloadHandler: Skipping expired payload for trip $tripCode (age: ${(age / (1000 * 60)).round()} minutes)',
              );
              continue;
            }

            // Check if this is newer than what we have for this trip code
            if (!latestByTripCode.containsKey(tripCode) ||
                (latestByTripCode[tripCode]!['timestamp'] as int? ?? 0) <
                    timestamp) {
              latestByTripCode[tripCode] = data;
              print(
                'MqttPayloadHandler: Found newer payload for trip $tripCode with timestamp $timestamp',
              );
            }
          } catch (e) {
            print('MqttPayloadHandler: Error parsing stored payload: $e');
          }
        }
      }

      // Convert the map to a list for return
      final results = latestByTripCode.values.toList();
      print(
        'MqttPayloadHandler: Returning ${results.length} latest messages after filtering',
      );
      return results;
    } catch (e) {
      print('MqttPayloadHandler: Error loading latest messages: $e');
      return [];
    }
  }

  /// Restore app state from stored payloads
  Future<void> restoreStateFromStoredPayloads() async {
    if (_providerContainer == null) return;

    try {
      // First, get a list of all active trip codes from TripStorageService
      final tripStorageService = TripStorageService();
      final activeTripCodes = await tripStorageService.getAllActiveTripCodes();

      print(
        'MqttPayloadHandler: Found ${activeTripCodes.length} active trips in TripStorageService',
      );

      // Load messages from mqtt_payload storage
      final messages = await loadLatestMessages();
      print(
        'MqttPayloadHandler: Loaded ${messages.length} messages from mqtt_payload storage',
      );

      // Process messages only if they're relevant to active trips
      final validMessages = <Map<String, dynamic>>[];

      for (final message in messages) {
        try {
          // Extract trip code from topic or data
          String? tripCode;
          final topic = message['topic'] as String?;
          if (topic == null) continue;

          if (topic.contains('trip/')) {
            final parts = topic.split('/');
            for (int i = 0; i < parts.length - 1; i++) {
              if (i + 1 < parts.length && parts[i] == 'trip') {
                tripCode = parts[i + 1];
                break;
              }
            }
          } else if (topic.contains('/trip/')) {
            final parts = topic.split('/');
            for (int i = 0; i < parts.length - 1; i++) {
              if (i + 1 < parts.length && parts[i] == 'trip') {
                tripCode = parts[i + 1];
                break;
              }
            }
          }

          // Skip messages not related to any active trip
          if (tripCode == null || !activeTripCodes.contains(tripCode)) {
            continue;
          }

          // For trip progress messages, check if we have more recent data in TripStorageService
          if (topic.contains('trip') || topic.contains('/trip/')) {
            final timestamp = message['timestamp'] as int? ?? 0;
            final cachedData = await tripStorageService.loadCachedTripProgress(
              tripCode,
            );

            if (cachedData != null) {
              final cachedTimestamp = cachedData['timestamp'] as int? ?? 0;

              // Skip if TripStorageService has more recent data
              if (cachedTimestamp > timestamp) {
                print(
                  'MqttPayloadHandler: Skipping mqtt_payload for trip $tripCode as TripStorageService has newer data',
                );
                continue;
              }
            }
          }

          // Add to valid messages if it passed all checks
          validMessages.add(message);
        } catch (e) {
          print('MqttPayloadHandler: Error checking message relevance: $e');
        }
      }

      print(
        'MqttPayloadHandler: Restoring state from ${validMessages.length} valid payloads after filtering',
      );

      // Process only valid messages
      for (final message in validMessages) {
        try {
          final topic = message['topic'] as String?;
          if (topic == null) continue;

          // Mark the message as coming from cache to prevent feedback loops
          final markedMessage = {
            ...message,
            'fromCache': true, // Add marker to prevent re-storing
          };

          // Re-process each message based on topic type
          if (topic.contains('robot') && topic.contains('heartbeat')) {
            await _processRobotHeartbeatMessage(markedMessage);
          } else if (topic.contains('robot') && topic.contains('container')) {
            await _processRobotContainerMessage(markedMessage);
          } else if (topic.contains('robot') && topic.contains('trip/state')) {
            await _processRobotTripStateMessage(markedMessage);
          } else if (topic.contains('robot') && topic.contains('trip') && !topic.contains('trip/state')) {
            await _processRobotTripMessage(markedMessage);
          } else if (topic.contains('robot') && topic.contains('location')) {
            await _processRobotLocationMessage(markedMessage);
          }
        } catch (e) {
          print('MqttPayloadHandler: Error processing stored message: $e');
        }
      }
    } catch (e) {
      print('MqttPayloadHandler: Error in restoreStateFromStoredPayloads: $e');
    }
  }

  /// Clean up resources
  void dispose() {
    // Restore original callback if any
    if (_originalCallback != null) {
      MqttService.onRobotStatusUpdate = _originalCallback;
    }
    _isInitialized = false;
    print('MqttPayloadHandler: Disposed');
  }
}
