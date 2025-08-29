import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../notification/notification_service.dart';

/// MQTT service for handling real-time robot status updates
class MqttService {
  static MqttServerClient? _client;
  static bool _isConnected = false;
  static String? _clientId;
  static final List<String> _subscribedTopics = [];

  /// Callback for robot status updates
  static Function(Map<String, dynamic>)? onRobotStatusUpdate;

  /// Get list of subscribed topics
  static List<String> get subscribedTopics =>
      List.unmodifiable(_subscribedTopics);

  /// Check if subscribed to a specific topic
  static bool isSubscribedTo(String topic) => _subscribedTopics.contains(topic);

  /// Initialize MQTT connection
  static Future<bool> initialize({
    required String brokerHost,
    required int brokerPort,
    String? username,
    String? password,
    String? clientId,
  }) async {
    try {
      _clientId =
          clientId ?? 'zippy_mobile_${DateTime.now().millisecondsSinceEpoch}';

      _client = MqttServerClient.withPort(brokerHost, _clientId!, brokerPort);
      _client!.logging(on: true);
      _client!.setProtocolV311();
      _client!.keepAlivePeriod = 30; // Longer keep alive
      _client!.connectTimeoutPeriod = 10000; // Increased timeout to 10 seconds
      _client!.autoReconnect = true;

      // Set up connection message
      final connMess = MqttConnectMessage()
          .withClientIdentifier(_clientId!)
          .withWillTopic('clients/disconnect')
          .withWillMessage('Client $_clientId disconnected')
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);

      if (username != null && password != null) {
        connMess.authenticateAs(username, password);
      }

      _client!.connectionMessage = connMess;

      // Set up callbacks
      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;
      _client!.onUnsubscribed = _onUnsubscribed;
      _client!.onSubscribed = _onSubscribed;
      _client!.onAutoReconnect = _onAutoReconnect;

      print(
        'MqttService: Connecting to MQTT broker at $brokerHost:$brokerPort...',
      );
      print('MqttService: Using client ID: $_clientId');
      if (username != null) {
        print('MqttService: Using authentication with username: $username');
      }

      print('MqttService: Initiating connection...');
      final status = await _client!.connect();
      print('MqttService: Connection attempt completed');

      if (status!.state == MqttConnectionState.connected) {
        _isConnected = true;
        print('MqttService: Successfully connected to MQTT broker');
        print('MqttService: Connection state: ${status.state}');
        print('MqttService: Return code: ${status.returnCode}');

        // Subscribe to robot status topic
        await _subscribeToRobotStatus();

        return true;
      } else {
        print('MqttService: Failed to connect to MQTT broker: ${status.state}');
        print('MqttService: Connection return code: ${status.returnCode}');
        print(
          'MqttService: Connection reason: ${_getConnectionFailureReason(status.returnCode)}',
        );
        _client = null;
        return false;
      }
    } catch (e) {
      print('MqttService: Error initializing MQTT connection: $e');
      _client = null;
      _isConnected = false;
      return false;
    }
  }

  /// Subscribe to robot status updates
  static Future<void> _subscribeToRobotStatus() async {
    if (_client == null || !_isConnected) {
      print('MqttService: Cannot subscribe - client not connected');
      return;
    }

    // Subscribe to robot status updates (matching the actual topic pattern)
    const robotLocationTopic = 'robot/+/location';
    const robotBatteryTopic = 'robot/+/battery';
    const robotStatusTopic = 'robot/+/status';
    const containerStatusTopic = 'robot/+/container';
    const tripTopic = 'robot/+/trip';
    const qrCodeTopic = 'robot/+/qr-code';
    const forcMoveTopic = 'robot/+/force_move';
    const warningTopic = 'robot/+/warning';

    final topics = [
      robotLocationTopic,
      robotBatteryTopic,
      robotStatusTopic,
      containerStatusTopic,
      tripTopic,
      qrCodeTopic,
      forcMoveTopic,
      warningTopic,
    ];

    print('MqttService: Subscribing to topics:');
    print('  - Robot location: $robotLocationTopic');
    print('  - Robot battery: $robotBatteryTopic');
    print('  - Robot status: $robotStatusTopic');
    print('  - Container status: $containerStatusTopic');
    print('  - Trip progress: $tripTopic');
    print('  - QR code: $qrCodeTopic');
    print('  - Force move: $forcMoveTopic');
    print('  - Warning: $warningTopic');

    // Subscribe to all topics
    for (final topic in topics) {
      final subscription = _client!.subscribe(topic, MqttQos.atLeastOnce);

      if (subscription != null) {
        _subscribedTopics.add(topic);
        print('MqttService: Successfully subscribed to $topic');
      } else {
        print('MqttService: Failed to subscribe to $topic');
      }
    }

    // Listen for messages
    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>> c) async {
      final recMess = c[0].payload as MqttPublishMessage;
      final message = MqttPublishPayload.bytesToStringAsString(
        recMess.payload.message,
      );
      final topic = c[0].topic;

      print('MqttService: Received message on topic $topic: $message');

      try {
        final data = json.decode(message) as Map<String, dynamic>;

        // Add topic information to the data
        data['topic'] = topic;

        // Extract robot ID from topic and determine message type
        final topicParts = topic.split('/');
        if (topicParts.length >= 3 && topicParts[0] == 'robot') {
          data['robotId'] = topicParts[1];

          // Determine message type based on topic structure
          if (topicParts.length >= 4 && topicParts[2] == 'container') {
            // robot/{robotId}/container/{containerId} or robot/{robotId}/container
            if (topicParts.length >= 4) {
              data['containerId'] = topicParts[3];
            }
            data['messageType'] = 'container_status';
            data['isContainerStatus'] = true;
          } else if (topicParts.length == 3) {
            // robot/{robotId}/{type}
            final messageType = topicParts[2];
            switch (messageType) {
              case 'status':
                data['messageType'] = 'robot_status';
                data['isRobotStatus'] = true;
                break;
              case 'location':
                data['messageType'] = 'robot_location';
                data['isLocationUpdate'] = true;
                break;
              case 'battery':
                data['messageType'] = 'robot_battery';
                data['isBatteryUpdate'] = true;
                break;
              case 'trip':
                data['messageType'] = 'trip_progress';
                data['isTripProgress'] = true;
                break;
              case 'qr-code':
                data['messageType'] = 'qr_code';
                data['isQrCode'] = true;
                break;
              case 'force_move':
                data['messageType'] = 'force_move';
                data['isForceMove'] = true;
                break;
              case 'warning':
                data['messageType'] = 'warning';
                data['isWarning'] = true;
                break;
              default:
                data['messageType'] = 'unknown';
                print('MqttService: Unknown message type: $messageType');
            }
          } else {
            data['messageType'] = 'unknown_topic_structure';
            print('MqttService: Unknown topic structure: $topic');
          }
        } else {
          data['messageType'] = 'invalid_topic';
          print('MqttService: Invalid topic format: $topic');
        }

        // Process background notifications for delivery status
        await _processBackgroundNotification(data);

        // Call the callback if set (for active UI updates)
        onRobotStatusUpdate?.call(data);
      } catch (e) {
        print('MqttService: Error parsing robot status message: $e');
      }
    });
  }

  /// Subscribe to a custom topic
  static Future<bool> subscribeToTopic(String topic) async {
    if (_client == null || !_isConnected) {
      print('MqttService: Cannot subscribe to $topic - client not connected');
      return false;
    }

    try {
      print('MqttService: Subscribing to custom topic: $topic');

      final subscription = _client!.subscribe(topic, MqttQos.atLeastOnce);

      if (subscription != null) {
        if (!_subscribedTopics.contains(topic)) {
          _subscribedTopics.add(topic);
        }
        print('MqttService: Successfully subscribed to $topic');
        return true;
      } else {
        print('MqttService: Failed to subscribe to $topic');
        return false;
      }
    } catch (e) {
      print('MqttService: Error subscribing to topic $topic: $e');
      return false;
    }
  }

  /// Unsubscribe from a custom topic
  static Future<bool> unsubscribeFromTopic(String topic) async {
    if (_client == null || !_isConnected) {
      print(
        'MqttService: Cannot unsubscribe from $topic - client not connected',
      );
      return false;
    }

    try {
      print('MqttService: Unsubscribing from topic: $topic');

      _client!.unsubscribe(topic);
      _subscribedTopics.remove(topic);

      print('MqttService: Successfully unsubscribed from $topic');
      return true;
    } catch (e) {
      print('MqttService: Error unsubscribing from topic $topic: $e');
      return false;
    }
  }

  /// Publish a message to a topic
  static Future<bool> publish(
    String topic,
    Map<String, dynamic> message,
  ) async {
    if (_client == null || !_isConnected) {
      print('MqttService: Cannot publish - client not connected');
      return false;
    }

    try {
      final payload = json.encode(message);
      final builder = MqttClientPayloadBuilder();
      builder.addString(payload);

      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      print('MqttService: Published message to topic $topic: $payload');
      return true;
    } catch (e) {
      print('MqttService: Error publishing message: $e');
      return false;
    }
  }

  // Disconnect from MQTT broker
  static Future<void> disconnect() async {
    if (_client != null) {
      print('MqttService: Disconnecting from MQTT broker...');
      _client!.disconnect();
      _client = null;
      _isConnected = false;
      onRobotStatusUpdate = null;
    }
  }

  // Callback functions
  static void _onConnected() {
    _isConnected = true;
    print('MqttService: MQTT client connected');
  }

  static void _onDisconnected() {
    _isConnected = false;
    print('MqttService: MQTT client disconnected');
  }

  static void _onSubscribed(String topic) {
    if (!_subscribedTopics.contains(topic)) {
      _subscribedTopics.add(topic);
    }
    print('MqttService: Successfully subscribed to topic: $topic');
    print('MqttService: Current subscribed topics: $_subscribedTopics');
  }

  static void _onUnsubscribed(String? topic) {
    if (topic != null) {
      _subscribedTopics.remove(topic);
    }
    print('MqttService: Unsubscribed from topic: $topic');
    print('MqttService: Current subscribed topics: $_subscribedTopics');
  }

  static void _onAutoReconnect() {
    print('MqttService: Auto-reconnecting to MQTT broker...');
  }

  /// Check if connected
  static bool get isConnected => _isConnected;

  /// Get client ID
  static String? get clientId => _clientId;

  /// Debug method to check current subscription status
  static void debugSubscriptionStatus() {
    print('MqttService Debug Info:');
    print('  - Connected: $_isConnected');
    print('  - Client ID: $_clientId');
    print('  - Subscribed topics: $_subscribedTopics');
    print('  - Client null: ${_client == null}');
    if (_client != null) {
      print('  - Client connection state: ${_client!.connectionStatus?.state}');
    }
  }

  /// Debug method to test MQTT connectivity and troubleshoot issues
  static Future<Map<String, dynamic>> debugConnection() async {
    final debugInfo = <String, dynamic>{
      'client_exists': _client != null,
      'is_connected': _isConnected,
      'client_id': _clientId,
      'subscribed_topics': _subscribedTopics,
      'timestamp': DateTime.now().toIso8601String(),
    };

    print('=== MQTT Debug Information ===');
    print('Client exists: ${_client != null}');
    print('Is connected: $_isConnected');
    print('Client ID: $_clientId');
    print('Subscribed topics: $_subscribedTopics');

    if (_client != null) {
      print('Client state: ${_client!.connectionStatus?.state}');
      print('Client return code: ${_client!.connectionStatus?.returnCode}');
      debugInfo['client_state'] = _client!.connectionStatus?.state.toString();
      debugInfo['return_code'] = _client!.connectionStatus?.returnCode
          .toString();
    }

    print('==============================');

    return debugInfo;
  }

  /// Force reconnection (for testing/debugging)
  static Future<bool> forceReconnect() async {
    print('MqttService: Force reconnecting...');

    if (_client != null) {
      try {
        _client!.disconnect();
      } catch (e) {
        print('MqttService: Error during disconnect: $e');
      }
    }

    _isConnected = false;
    _client = null;
    _subscribedTopics.clear();

    // Wait a bit before reconnecting
    await Future.delayed(const Duration(seconds: 2));

    // Try to reinitialize with last known good config
    return await initialize(
      brokerHost: '36.50.135.207', // MQTT broker host
      brokerPort: 1883,
      username: 'khanhnc',
      password: '12345678',
    );
  }

  /// Test network connectivity to MQTT broker
  static Future<bool> testNetworkConnectivity() async {
    try {
      print('MqttService: Testing network connectivity to MQTT broker...');

      // Create a simple test client
      final testClientId =
          'zippy_test_${DateTime.now().millisecondsSinceEpoch}';
      final testClient = MqttServerClient.withPort(
        '36.50.135.207', // MQTT broker host
        testClientId,
        1883,
      );

      testClient.logging(on: true);
      testClient.setProtocolV311();
      testClient.keepAlivePeriod = 20;
      testClient.connectTimeoutPeriod = 5000;
      testClient.autoReconnect = false;

      final connMess = MqttConnectMessage()
          .withClientIdentifier(testClientId)
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);

      connMess.authenticateAs('khanhnc', '12345678');
      testClient.connectionMessage = connMess;

      print('MqttService: Attempting test connection...');
      final status = await testClient.connect();

      final isConnected = status?.state == MqttConnectionState.connected;
      print('MqttService: Test connection result: $isConnected');

      if (isConnected) {
        print('MqttService: Network connectivity test passed');
        testClient.disconnect();
      } else {
        print('MqttService: Network connectivity test failed');
        print('MqttService: Status: ${status?.state}');
        print('MqttService: Return code: ${status?.returnCode}');
      }

      return isConnected;
    } catch (e) {
      print('MqttService: Network connectivity test error: $e');
      return false;
    }
  }

  /// Get human-readable connection failure reason
  static String _getConnectionFailureReason(MqttConnectReturnCode? returnCode) {
    if (returnCode == null) return 'Unknown';
    return returnCode.toString();
  }

  /// Process background notifications for robot status updates
  static Future<void> _processBackgroundNotification(
    Map<String, dynamic> data,
  ) async {
    try {
      final messageType = data['messageType'] as String?;
      final robotId = data['robotId'] as String?;

      switch (messageType) {
        case 'robot_status':
          await _processRobotStatusNotification(data, robotId);
          break;
        case 'warning':
          await _processWarningNotification(data, robotId);
          break;
        case 'trip_progress':
          await _processTripProgressNotification(data, robotId);
          break;
        case 'qr_code':
          await _processQrCodeNotification(data, robotId);
          break;
        case 'force_move':
          await _processForceMoveNotification(data, robotId);
          break;
        case 'battery':
          await _processBatteryNotification(data, robotId);
          break;
        // Container status, location updates don't usually need notifications
        default:
          // Log other message types for debugging
          print(
            'MqttService: Background processing for $messageType - no notification needed',
          );
      }
    } catch (e) {
      print('MqttService: Error processing background notification: $e');
      // Continue silently - notifications are not critical for app function
    }
  }

  /// Process robot status notifications
  static Future<void> _processRobotStatusNotification(
    Map<String, dynamic> data,
    String? robotId,
  ) async {
    final status = data['status'] as String?;
    final location = data['location'] as String?;

    if (robotId != null && status != null) {
      String? notificationTitle;
      String? notificationBody;

      // Check for pickup arrival (robot reached pickup location)
      if (status.toLowerCase() == 'arrived' && location != null) {
        if (location.toLowerCase().contains('pickup') ||
            location.toLowerCase().contains('start') ||
            location.toLowerCase().contains('origin')) {
          notificationTitle = 'Robot Arrived at Pickup';
          notificationBody =
              'Robot $robotId has arrived at pickup location. Please scan QR code to open container.';
        }
        // Check for delivery arrival (robot reached delivery location)
        else if (location.toLowerCase().contains('delivery') ||
            location.toLowerCase().contains('destination') ||
            location.toLowerCase().contains('end')) {
          notificationTitle = 'Robot Arrived at Delivery';
          notificationBody =
              'Robot $robotId has arrived at delivery location. Please scan QR code to receive your package.';
        }
      }

      // Send notification if we have a relevant status update
      if (notificationTitle != null && notificationBody != null) {
        await NotificationService().showPhase1Notification(
          title: notificationTitle,
          body: notificationBody,
        );
        print(
          'MqttService: Robot status notification sent - $notificationTitle',
        );
      }
    }
  }

  /// Process warning notifications
  static Future<void> _processWarningNotification(
    Map<String, dynamic> data,
    String? robotId,
  ) async {
    final warningType = data['warning_type'] as String?;
    final warningMessage = data['message'] as String?;
    final severity = data['severity'] as String?;

    if (robotId != null && warningMessage != null) {
      String notificationTitle = 'Robot Warning';
      String notificationBody = 'Robot $robotId: $warningMessage';

      // Customize title based on severity
      if (severity != null) {
        switch (severity.toLowerCase()) {
          case 'critical':
            notificationTitle = 'CRITICAL: Robot Alert';
            break;
          case 'high':
            notificationTitle = 'HIGH: Robot Warning';
            break;
          case 'medium':
            notificationTitle = 'Robot Warning';
            break;
          case 'low':
            notificationTitle = 'Robot Info';
            break;
        }
      }

      // Further customize title based on warning type
      if (warningType != null) {
        final typeTitle = switch (warningType.toLowerCase()) {
          'battery_low' => 'Battery Low',
          'obstacle' => 'Obstacle Detected',
          'maintenance' => 'Maintenance Required',
          'security' => 'Security Alert',
          _ => warningType.toUpperCase(),
        };

        if (severity?.toLowerCase() == 'critical') {
          notificationTitle = 'CRITICAL: Robot $typeTitle';
        } else {
          notificationTitle = 'Robot $typeTitle';
        }
      }

      await NotificationService().showPhase1Notification(
        title: notificationTitle,
        body: notificationBody,
      );
      print('MqttService: Warning notification sent - $notificationTitle');
    }
  }

  /// Process trip progress notifications (status-based)
  static Future<void> _processTripProgressNotification(
    Map<String, dynamic> data,
    String? robotId,
  ) async {
    final tripId = data['trip_id'] as String?;
    final status = data['status'] as int?;
    final progress = data['progress'] as num?;

    if (robotId != null &&
        tripId != null &&
        status != null &&
        progress != null) {
      // Only send notifications for important status transitions at 100% progress
      if (progress >= 100.0 || progress >= 1.0) {
        String? notificationTitle;
        String? notificationBody;

        switch (status) {
          case 1: // Load - Robot ready for loading at pickup
            notificationTitle = 'Ready for Loading';
            notificationBody =
                'Robot $robotId is ready for loading at pickup location. Please scan QR code.';
            break;
          case 3: // Delivered - Robot ready for unloading at delivery
            notificationTitle = 'Ready for Pickup';
            notificationBody =
                'Robot $robotId has arrived at delivery location. Please scan QR code to collect your items.';
            break;
          case 4: // Finish - Trip completed
            notificationTitle = 'Delivery Completed';
            notificationBody = 'Trip $tripId has been completed successfully.';
            break;
        }

        if (notificationTitle != null && notificationBody != null) {
          await NotificationService().showPhase1Notification(
            title: notificationTitle,
            body: notificationBody,
          );
          print(
            'MqttService: Trip progress notification sent - $notificationTitle',
          );
        }
      }
    }
  }

  /// Process QR code notifications
  static Future<void> _processQrCodeNotification(
    Map<String, dynamic> data,
    String? robotId,
  ) async {
    final qrType = data['qr_type'] as String?;
    final action = data['action'] as String?;

    if (robotId != null && qrType != null) {
      String notificationTitle = 'QR Code Update';
      String notificationBody = 'Robot $robotId QR code status updated.';

      if (action != null) {
        switch (action.toLowerCase()) {
          case 'scanned':
            notificationTitle = 'QR Code Scanned';
            notificationBody =
                'QR code successfully scanned for robot $robotId.';
            break;
          case 'generated':
            notificationTitle = 'QR Code Ready';
            notificationBody = 'New QR code generated for robot $robotId.';
            break;
          case 'expired':
            notificationTitle = 'QR Code Expired';
            notificationBody =
                'QR code for robot $robotId has expired. Please request a new one.';
            break;
        }
      }

      await NotificationService().showPhase1Notification(
        title: notificationTitle,
        body: notificationBody,
      );
      print('MqttService: QR code notification sent - $notificationTitle');
    }
  }

  /// Process force move notifications
  static Future<void> _processForceMoveNotification(
    Map<String, dynamic> data,
    String? robotId,
  ) async {
    final moveType = data['move_type'] as String?;
    final reason = data['reason'] as String?;

    if (robotId != null) {
      String notificationTitle = 'Robot Force Move';
      String notificationBody = 'Robot $robotId has been force moved.';

      if (reason != null) {
        notificationBody += ' Reason: $reason';
      } else if (moveType != null) {
        notificationBody += ' Type: $moveType';
      }

      await NotificationService().showPhase1Notification(
        title: notificationTitle,
        body: notificationBody,
      );
      print('MqttService: Force move notification sent - $notificationTitle');
    }
  }

  /// Process battery notifications
  static Future<void> _processBatteryNotification(
    Map<String, dynamic> data,
    String? robotId,
  ) async {
    final batteryLevel = data['battery_level'] as num?;
    final isCharging = data['is_charging'] as bool?;

    if (robotId != null && batteryLevel != null) {
      // Only notify for low battery warnings
      if (batteryLevel <= 20 && isCharging != true) {
        String notificationTitle = 'Robot Battery Low';
        String notificationBody =
            'Robot $robotId battery level is ${batteryLevel.toInt()}%. Charging recommended.';

        await NotificationService().showPhase1Notification(
          title: notificationTitle,
          body: notificationBody,
        );
        print('MqttService: Battery notification sent - $notificationTitle');
      }
    }
  }
}

/// Provider for MQTT service initialization status
final mqttInitializationProvider = StateProvider<bool>((ref) => false);
