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
      // Handle trip progress updates via format: trip/{tripCode}/progress
      else if (topic.contains('trip') && topic.contains('progress')) {
        await _processTripProgressMessage(data);
      }
      // Handle trip progress updates via format: robot/{robotCode}/trip/{tripCode}
      else if (topic.contains('robot') && topic.contains('trip')) {
        await _processRobotTripMessage(data);
      }
      // Handle robot location updates
      else if (topic.contains('robot') && topic.contains('location')) {
        await _processRobotLocationMessage(data);
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

  /// Process trip progress messages
  Future<void> _processTripProgressMessage(Map<String, dynamic> data) async {
    try {
      final topic = data['topic'] as String?;
      if (topic == null) return;

      // Extract trip code from topic (format: trip/{tripCode}/progress)
      final topicParts = topic.split('/');
      if (topicParts.length < 3) return;

      final tripCode = topicParts[1];
      final progress = data['progress'] as num?;
      final status = data['status'] as String?;
      final robotId = data['robotId'] as String?;

      if (tripCode.isEmpty) return;

      // Persist trip progress
      await _persistTripProgress(tripCode, data);

      // Update robot state if applicable
      if (robotId != null && _providerContainer != null && progress != null) {
        // Use existing robot provider methods to update state
        _providerContainer!
            .read(robotProvider.notifier)
            .updateRobotTripProgress(
              robotId: robotId,
              tripCode: tripCode,
              progress: progress is double ? progress : progress.toDouble(),
              payload: data,
            );
      }

      // Generate trip progress notifications
      await _generateTripProgressNotifications(
        tripCode,
        progress,
        status,
        data,
      );
    } catch (e) {
      print('MqttPayloadHandler: Error processing trip message: $e');
    }
  }

  /// Process robot trip messages (format: robot/{robotCode}/trip/{tripCode})
  Future<void> _processRobotTripMessage(Map<String, dynamic> data) async {
    try {
      final topic = data['topic'] as String?;
      if (topic == null) return;

      // Extract robot and trip codes from topic (format: robot/{robotCode}/trip/{tripCode})
      final topicParts = topic.split('/');
      if (topicParts.length < 4) {
        print('MqttPayloadHandler: Invalid robot trip topic format: $topic');
        return;
      }

      final robotId = topicParts[1];
      final tripCode = topicParts[3];
      final progress = data['progress'] as num?;

      if (robotId.isEmpty || tripCode.isEmpty) {
        print(
          'MqttPayloadHandler: Missing robot ID or trip code from topic: $topic',
        );
        return;
      }

      // Check if this data is from cache (has the marker we added)
      final isFromCache = data['fromCache'] == true;

      print(
        'MqttPayloadHandler: Processing robot trip - Robot: $robotId, Trip: $tripCode, FromCache: $isFromCache',
      );

      // Persist trip progress (the _persistTripProgress method will check isFromCache again)
      await _persistTripProgress(tripCode, data);

      // Update robot state if applicable
      if (_providerContainer != null && progress != null) {
        // Create an enhanced payload with all needed information
        final enhancedPayload = {
          ...data,
          'robotId': robotId,
          'tripCode': tripCode,
          // For compatibility with other processors
          'messageType': 'trip_progress',
        };

        // Use existing robot provider methods to update state
        _providerContainer!
            .read(robotProvider.notifier)
            .updateRobotTripProgress(
              robotId: robotId,
              tripCode: tripCode,
              progress: progress is double ? progress : progress.toDouble(),
              payload: enhancedPayload,
            );

        // Also send as a trip progress notification
        await _generateTripProgressNotifications(
          tripCode,
          progress,
          data['status'] as String?,
          enhancedPayload,
        );
      }
    } catch (e) {
      print('MqttPayloadHandler: Error processing robot trip message: $e');
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
        final notificationKey = 'trip_status_notified_${tripCode}_$status';
        final alreadyNotified = prefs.getBool(notificationKey) ?? false;

        if (!alreadyNotified) {
          switch (status.toLowerCase()) {
            case 'completed':
              notificationTitle = 'Trip Completed';
              notificationBody =
                  'Trip $tripCode has been completed successfully.';
              break;
            case 'cancelled':
              notificationTitle = 'Trip Cancelled';
              notificationBody = 'Trip $tripCode has been cancelled.';
              break;
          }

          if (notificationTitle != null) {
            await NotificationService().showPhase2Notification(
              title: notificationTitle,
              body: notificationBody!,
            );
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

      if (robotCode == null) {
        robotCode = data['robotId'] as String? ?? 'unknown';
      }

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
          } else if (topic.contains('trip') && topic.contains('progress')) {
            await _processTripProgressMessage(markedMessage);
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
