import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notification/notification_service.dart';
import '../storage/trip_storage_service.dart';
import 'mqtt_service.dart';
import '../../providers/robot/robot_provider.dart';

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

      // Handle robot status updates
      if (topic.contains('robot') && topic.contains('status')) {
        await _processRobotStatusMessage(data);
      }
      // Handle trip progress updates via format: robot/{robotCode}/trip
      else if (topic.contains('robot') && topic.contains('trip')) {
        await _processRobotTripMessage(data);
      }
      // Handle robot location updates
      else if (topic.contains('robot') && topic.contains('location')) {
        await _processRobotLocationMessage(data);
      }
      // Handle robot battery updates
      else if (topic.contains('robot') && topic.contains('battery')) {
        await _processRobotBatteryMessage(data);
      }
      // Handle robot container updates
      else if (topic.contains('robot') && topic.contains('container')) {
        await _processRobotContainerMessage(data);
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

  /// Process robot status messages
  Future<void> _processRobotStatusMessage(Map<String, dynamic> data) async {
    final robotId = data['robotId'] as String?;
    final status = data['status'] as String?;

    if (robotId == null || status == null) return;

    // Update robot state via provider
    if (_providerContainer != null) {
      try {
        _providerContainer!
            .read(robotProvider.notifier)
            .updateRobotStatus(robotId: robotId, status: status, payload: data);
      } catch (e) {
        print('MqttPayloadHandler: Error updating robot provider: $e');
      }
    }

    // Generate notifications based on status
    await _generateRobotStatusNotifications(robotId, status, data);
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

      // Extract trip data from payload
      final tripId = data['trip_id'] as String?;
      final progress = data['progress'] as num?;
      final status = data['status'] as int?;
      final startPoint = data['start_point'] as String?;
      final endPoint = data['end_point'] as String?;

      if (robotId.isEmpty || tripId == null) {
        print(
          'MqttPayloadHandler: Missing robot ID or trip_id from payload: robotId=$robotId, trip_id=$tripId',
        );
        return;
      }

      // Check if this data is from cache (has the marker we added)
      final isFromCache = data['fromCache'] == true;

      print(
        'MqttPayloadHandler: Processing robot trip - Robot: $robotId, Trip: $tripId, Status: $status (${_getStatusName(status)}), Progress: $progress, FromCache: $isFromCache',
      );

      // Persist trip progress (the _persistTripProgress method will check isFromCache again)
      await _persistTripProgress(tripId, data);

      // Update robot state if applicable
      if (_providerContainer != null && progress != null && status != null) {
        // Create an enhanced payload with all needed information
        final enhancedPayload = {
          ...data,
          'robotId': robotId,
          'tripCode': tripId, // For compatibility with existing code
          'start_point': startPoint,
          'end_point': endPoint,
          // For compatibility with other processors
          'messageType': 'trip_progress',
        };

        // Generate status-based notifications
        await _generateTripProgressNotifications(
          tripId,
          progress,
          status.toString(), // Convert int status to string for compatibility
          enhancedPayload,
        );
      }
    } catch (e) {
      print('MqttPayloadHandler: Error processing robot trip message: $e');
    }
  }

  /// Get human-readable status name
  String _getStatusName(int? status) {
    if (status == null) return 'Unknown';
    switch (status) {
      case 0:
        return 'Prepare';
      case 1:
        return 'Load';
      case 2:
        return 'On Going';
      case 3:
        return 'Delivered';
      case 4:
        return 'Finish';
      default:
        return 'Unknown($status)';
    }
  }

  /// Process robot location messages
  Future<void> _processRobotLocationMessage(Map<String, dynamic> data) async {
    final robotId = data['robotId'] as String?;
    final location = data['location'] as String?;

    if (robotId == null || location == null) return;

    // Update robot location via provider
    if (_providerContainer != null) {
      try {
        _providerContainer!
            .read(robotProvider.notifier)
            .updateRobotLocation(
              robotId: robotId,
              location: location,
              coordinates: data['coordinates'],
              payload: data,
            );
      } catch (e) {
        print('MqttPayloadHandler: Error updating robot location: $e');
      }
    }
  }

  /// Process robot battery messages
  Future<void> _processRobotBatteryMessage(Map<String, dynamic> data) async {
    final robotId = data['robotId'] as String?;
    final batteryLevel = data['battery_level'] as num?;

    if (robotId == null || batteryLevel == null) return;

    print(
      'MqttPayloadHandler: Robot battery update - Robot: $robotId, Battery: $batteryLevel%',
    );

    // Update robot status via provider with battery info
    if (_providerContainer != null) {
      try {
        // Add battery info to the data
        final enhancedData = {...data, 'messageType': 'battery'};

        _providerContainer!
            .read(robotProvider.notifier)
            .updateRobotStatus(
              robotId: robotId,
              status: 'battery_update',
              payload: enhancedData,
            );
      } catch (e) {
        print('MqttPayloadHandler: Error updating robot battery: $e');
      }
    }

    // Generate low battery notifications if needed
    if (batteryLevel <= 20) {
      await NotificationService().showPhase2Notification(
        title: 'Robot Battery Low',
        body: 'Robot $robotId battery is at ${batteryLevel}%',
      );
    }
  }

  /// Process robot container messages
  Future<void> _processRobotContainerMessage(Map<String, dynamic> data) async {
    final robotId = data['robotId'] as String?;
    final containerId = data['container_id'] as String?;
    final containerStatus = data['status'] as String?;

    if (robotId == null || containerId == null) return;

    print(
      'MqttPayloadHandler: Robot container update - Robot: $robotId, Container: $containerId, Status: $containerStatus',
    );

    // Update robot status via provider
    if (_providerContainer != null) {
      try {
        final enhancedData = {
          ...data,
          'messageType': 'container',
          'containerId': containerId,
        };

        _providerContainer!
            .read(robotProvider.notifier)
            .updateRobotStatus(
              robotId: robotId,
              status: containerStatus ?? 'container_update',
              payload: enhancedData,
            );
      } catch (e) {
        print('MqttPayloadHandler: Error updating robot container: $e');
      }
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

    // Update robot location if provided
    if (_providerContainer != null && newLocation != null) {
      try {
        _providerContainer!
            .read(robotProvider.notifier)
            .updateRobotLocation(
              robotId: robotId,
              location: newLocation,
              coordinates: data['coordinates'],
              payload: data,
            );
      } catch (e) {
        print(
          'MqttPayloadHandler: Error updating robot location after force move: $e',
        );
      }
    }
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

    // Update robot status to reflect warning
    if (_providerContainer != null) {
      try {
        final enhancedData = {
          ...data,
          'messageType': 'warning',
          'warningType': warningType,
          'severity': severity,
        };

        _providerContainer!
            .read(robotProvider.notifier)
            .updateRobotStatus(
              robotId: robotId,
              status: 'warning_$warningType',
              payload: enhancedData,
            );
      } catch (e) {
        print('MqttPayloadHandler: Error updating robot warning status: $e');
      }
    }
  }

  /// Generate notifications for robot status updates
  Future<void> _generateRobotStatusNotifications(
    String robotId,
    String status,
    Map<String, dynamic> data,
  ) async {
    // Check if we should send a notification for this status
    if (status.toLowerCase() == 'arrived') {
      final location = data['location'] as String?;

      if (location != null) {
        String notificationTitle = '';
        String notificationBody = '';
        bool shouldNotify = false;

        if (location.toLowerCase().contains('pickup')) {
          notificationTitle = 'Robot Arrived for Pickup';
          notificationBody =
              'Robot $robotId has arrived at pickup location. Please scan QR code to open container.';
          shouldNotify = true;
        } else if (location.toLowerCase().contains('delivery') ||
            location.toLowerCase().contains('destination')) {
          notificationTitle = 'Robot Arrived for Delivery';
          notificationBody =
              'Robot $robotId has arrived at delivery location. Please scan QR code to receive your package.';
          shouldNotify = true;
        }

        if (shouldNotify) {
          await NotificationService().showPhase1Notification(
            title: notificationTitle,
            body: notificationBody,
          );
        }
      }
    }
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
          if (topic.contains('robot') && topic.contains('status')) {
            await _processRobotStatusMessage(markedMessage);
          } else if (topic.contains('robot') && topic.contains('trip')) {
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
