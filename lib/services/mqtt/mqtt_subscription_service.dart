import 'dart:async';
import 'mqtt_manager.dart';
import 'mqtt_service.dart';
import '../storage/trip_storage_service.dart';
import '../storage/persistent_mqtt_manager.dart';

/// Service for handling MQTT subscriptions and message processing
/// specifically for trip progress updates
class MqttSubscriptionService {
  // Singleton pattern
  static final MqttSubscriptionService _instance =
      MqttSubscriptionService._internal();
  static MqttSubscriptionService get instance => _instance;

  // Private constructor that sets up global handler
  MqttSubscriptionService._internal() {
    _setupGlobalMessageHandler();
  }

  // Callback for UI updates
  Function(Map<String, dynamic>)? onTripProgressUpdate;

  // State tracking
  final Map<String, String> _activeSubscriptions = {};

  // Set up global message handler that will process messages for all active trips
  void _setupGlobalMessageHandler() {
    // Store original callback for chaining
    final originalCallback = MqttService.onRobotStatusUpdate;

    // Set up our global handler
    MqttService.onRobotStatusUpdate = (data) {
      // First call the original handler (which might be the global handler)
      if (originalCallback != null) {
        originalCallback(data);
      }

      // Process all active subscriptions
      _processForActiveSubscriptions(data);

      // Forward to UI callback if available
      if (onTripProgressUpdate != null) {
        onTripProgressUpdate!(data);
      }
    };

    print('MqttSubscriptionService: Global message handler registered');
  }

  // Process messages for all active subscriptions
  void _processForActiveSubscriptions(Map<String, dynamic> data) {
    final topic = data['topic'] as String?;
    if (topic == null) return;

    // Check if this message is relevant to any of our active subscriptions
    _activeSubscriptions.forEach((tripCode, subscriptionTopic) {
      if (topic == subscriptionTopic || topic.contains(tripCode)) {
        // Extract robotCode from topic
        String? robotCode;
        if (topic.startsWith('robot/')) {
          final parts = topic.split('/');
          if (parts.length >= 2) {
            robotCode = parts[1];

            // Store raw progress update via TripStorageService for persistent storage
            final progress = data['progress'] as num?;
            if (progress != null) {
              TripStorageService().storeRawProgressUpdate(
                robotCode: robotCode,
                tripCode: tripCode,
                data: data,
              );
            }
          }
        }
      }
    });
  }

  // Initialize the MQTT connection and ensure it's ready for subscriptions
  Future<bool> initialize() async {
    try {
      // Ensure persistent MQTT manager is running
      if (!PersistentMqttManager.instance.isInitialized) {
        print('MqttSubscriptionService: Initializing persistent MQTT manager');
        await PersistentMqttManager.instance.initialize();
      }

      // Initialize MQTT manager
      final success = await MqttManager.initialize();

      if (success) {
        print('MqttSubscriptionService: MQTT initialized successfully');
        return true;
      } else {
        print(
          'MqttSubscriptionService: Failed to initialize MQTT connection, trying persistent manager force reconnect',
        );

        // Try force reconnect through persistent manager
        await PersistentMqttManager.instance.forceReconnect();

        // Wait a bit and try again
        await Future.delayed(const Duration(seconds: 2));
        final retrySuccess = await MqttManager.initialize();

        if (retrySuccess) {
          print('MqttSubscriptionService: MQTT retry successful');
          return true;
        } else {
          print('MqttSubscriptionService: MQTT retry failed');
          return false;
        }
      }
    } catch (e) {
      print('MqttSubscriptionService: Error initializing MQTT: $e');
      return false;
    }
  }

  // Subscribe to trip progress updates
  Future<bool> subscribeToTripProgress({
    required String robotCode,
    required String tripCode,
    Function(Map<String, dynamic>)? onMessage,
  }) async {
    try {
      final topic = 'robot/$robotCode/trip/$tripCode';

      // Store the callback if provided
      if (onMessage != null) {
        onTripProgressUpdate = onMessage;
      }

      // Register this trip/robot combination as active in our service
      // This lets our global message handler know which trips to process updates for
      _activeSubscriptions[tripCode] = topic;

      // Actually subscribe to the topic
      final success = await MqttService.subscribeToTopic(topic);
      if (success) {
        print('MqttSubscriptionService: Successfully subscribed to $topic');

        // Store active subscription for later reference
        _activeSubscriptions[tripCode] = topic;

        // Update app activity timestamp
        await TripStorageService().updateAppActivityTimestamp();

        return true;
      } else {
        print('MqttSubscriptionService: Failed to subscribe to $topic');
        return false;
      }
    } catch (e) {
      print('MqttSubscriptionService: Error in subscribeToTripProgress: $e');
      return false;
    }
  }

  // Note: We've replaced the individual message handler with a global handler
  // that processes messages for all active subscriptions

  // Unsubscribe from topic when no longer needed
  Future<bool> unsubscribeFromTripProgress(String tripCode) async {
    try {
      final topic = _activeSubscriptions[tripCode];
      if (topic == null) {
        print(
          'MqttSubscriptionService: No active subscription found for trip $tripCode',
        );
        return false;
      }

      final success = await MqttService.unsubscribeFromTopic(topic);

      if (success) {
        print('MqttSubscriptionService: Successfully unsubscribed from $topic');
        _activeSubscriptions.remove(tripCode);
        return true;
      } else {
        print('MqttSubscriptionService: Failed to unsubscribe from $topic');
        return false;
      }
    } catch (e) {
      print(
        'MqttSubscriptionService: Error in unsubscribeFromTripProgress: $e',
      );
      return false;
    }
  }

  // Check if subscribed to a specific trip
  bool isSubscribedToTrip(String tripCode) {
    return _activeSubscriptions.containsKey(tripCode);
  }

  // Debug method to test MQTT subscription status
  Future<Map<String, dynamic>> debugMqttStatus(
    String robotCode,
    String tripCode,
  ) async {
    final topic = 'robot/$robotCode/trip/$tripCode';
    final isSubscribed = MqttService.isSubscribedTo(topic);
    final allTopics = MqttService.subscribedTopics;

    // Get detailed MQTT service debug info
    final debugInfo = await MqttService.debugConnection();

    return {
      'tripCode': tripCode,
      'robotCode': robotCode,
      'topic': topic,
      'isSubscribed': isSubscribed,
      'allSubscribedTopics': allTopics,
      'mqttConnectionDetails': debugInfo,
      'activeSubscriptionsMap': _activeSubscriptions,
    };
  }
}
