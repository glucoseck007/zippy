import 'dart:convert';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'network_state_checker.dart';

/// Background service for handling MQTT connections when app is closed
class BackgroundService {
  static const String _robotStatusCheckTask = 'robot_status_check_task';
  static const String _tripProgressCheckTask = 'trip_progress_check_task';

  /// Initialize background service
  static Future<void> initialize() async {
    try {
      await Workmanager().initialize(
        _callbackDispatcher,
        isInDebugMode: false, // Set to false in production
      );

      // Register periodic task to check robot status (reduced frequency to avoid conflicts)
      await Workmanager().registerPeriodicTask(
        _robotStatusCheckTask,
        _robotStatusCheckTask,
        frequency: const Duration(
          minutes: 15,
        ), // Keep at minimum allowed frequency
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
        inputData: {
          'background_check': true,
          'last_check': DateTime.now().millisecondsSinceEpoch,
        },
        existingWorkPolicy:
            ExistingPeriodicWorkPolicy.replace, // Replace existing task
      );

      print('BackgroundService: Initialized background tasks');
    } catch (e) {
      print('BackgroundService: Error initializing: $e');
      // Try to recover by canceling all and re-registering
      try {
        await Workmanager().cancelAll();
        await Future.delayed(const Duration(seconds: 2));
        await initialize(); // Retry once
      } catch (retryError) {
        print('BackgroundService: Retry failed: $retryError');
      }
    }
  }

  /// Register MQTT monitoring for active delivery
  static Future<void> registerMqttMonitoring({
    required String robotId,
    required String orderId,
    required String deliveryPhase, // 'pickup' or 'delivery'
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Store delivery info for background processing
    await prefs.setString('active_robot_id', robotId);
    await prefs.setString('active_order_id', orderId);
    await prefs.setString('active_delivery_phase', deliveryPhase);
    await prefs.setBool('is_monitoring_active', true);

    print('BackgroundService: Registered MQTT monitoring for robot $robotId');
  }

  /// Stop MQTT monitoring
  static Future<void> stopMqttMonitoring() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_monitoring_active', false);
    await prefs.remove('active_robot_id');
    await prefs.remove('active_order_id');
    await prefs.remove('active_delivery_phase');

    print('BackgroundService: Stopped MQTT monitoring');
  }

  /// Register trip progress monitoring for background
  static Future<void> registerTripProgressMonitoring({
    required String tripCode,
    required String robotCode,
    required String orderCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Store trip progress info for background monitoring
    await prefs.setString('active_trip_code', tripCode);
    await prefs.setString('active_trip_robot_code', robotCode);
    await prefs.setString('active_trip_order_code', orderCode);
    await prefs.setBool('is_trip_monitoring_active', true);
    await prefs.setInt(
      'trip_monitoring_start_time',
      DateTime.now().millisecondsSinceEpoch,
    );

    // Register a dedicated background task for trip progress monitoring
    try {
      await Workmanager().registerPeriodicTask(
        _tripProgressCheckTask,
        _tripProgressCheckTask,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
        inputData: {
          'trip_code': tripCode,
          'robot_code': robotCode,
          'order_code': orderCode,
          'task_type': 'trip_progress',
        },
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      );
      print(
        'BackgroundService: Registered dedicated trip progress monitoring task for trip $tripCode',
      );
    } catch (e) {
      print('BackgroundService: Error registering trip progress task: $e');
    }

    print(
      'BackgroundService: Registered trip progress monitoring for trip $tripCode',
    );
  }

  /// Register trip progress monitoring for background with custom frequency
  static Future<void> registerTripProgressMonitoringWithFrequency({
    required String tripCode,
    required String robotCode,
    required String orderCode,
    Duration? frequency, // Optional custom frequency for testing
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Store trip progress info for background monitoring
    await prefs.setString('active_trip_code', tripCode);
    await prefs.setString('active_trip_robot_code', robotCode);
    await prefs.setString('active_trip_order_code', orderCode);
    await prefs.setBool('is_trip_monitoring_active', true);
    await prefs.setInt(
      'trip_monitoring_start_time',
      DateTime.now().millisecondsSinceEpoch,
    );

    // Use custom frequency for testing or default to 15 minutes
    final taskFrequency = frequency ?? const Duration(minutes: 15);

    // Register a dedicated background task for trip progress monitoring
    try {
      await Workmanager().registerPeriodicTask(
        _tripProgressCheckTask,
        _tripProgressCheckTask,
        frequency: taskFrequency,
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
        inputData: {
          'trip_code': tripCode,
          'robot_code': robotCode,
          'order_code': orderCode,
          'task_type': 'trip_progress',
          'frequency_minutes': taskFrequency.inMinutes,
        },
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      );
      print(
        'BackgroundService: Registered dedicated trip progress monitoring task for trip $tripCode with frequency ${taskFrequency.inMinutes} minutes',
      );
    } catch (e) {
      print('BackgroundService: Error registering trip progress task: $e');
    }

    print(
      'BackgroundService: Registered trip progress monitoring for trip $tripCode',
    );
  }

  /// Register an immediate one-time trip progress check for testing
  static Future<void> registerImmediateTripProgressCheck({
    required String tripCode,
    required String robotCode,
    required String orderCode,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Store trip details for the immediate check
      await prefs.setString('active_trip_code', tripCode);
      await prefs.setString('active_trip_robot_code', robotCode);
      await prefs.setString('active_trip_order_code', orderCode);
      await prefs.setBool('is_trip_monitoring_active', true);

      // Register a one-time immediate task
      await Workmanager().registerOneOffTask(
        'immediate_trip_check_${DateTime.now().millisecondsSinceEpoch}',
        _tripProgressCheckTask,
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
        inputData: {
          'trip_code': tripCode,
          'robot_code': robotCode,
          'order_code': orderCode,
          'task_type': 'trip_progress',
          'immediate_test': true,
        },
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );

      print(
        'BackgroundService: Registered immediate trip progress check for trip $tripCode',
      );
    } catch (e) {
      print(
        'BackgroundService: Error registering immediate trip progress check: $e',
      );
    }
  }

  /// Stop trip progress monitoring
  static Future<void> stopTripProgressMonitoring() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_trip_monitoring_active', false);
    await prefs.remove('active_trip_code');
    await prefs.remove('active_trip_robot_code');
    await prefs.remove('active_trip_order_code');
    await prefs.remove('trip_monitoring_start_time');

    // Cancel the dedicated trip progress task
    try {
      await Workmanager().cancelByUniqueName(_tripProgressCheckTask);
      print('BackgroundService: Cancelled dedicated trip progress task');
    } catch (e) {
      print('BackgroundService: Error cancelling trip progress task: $e');
    }

    print('BackgroundService: Stopped trip progress monitoring');
  }

  /// Test method to simulate trip progress completion for debugging
  static Future<bool> testTripProgressCompletion({
    required String tripCode,
    required String robotCode,
    required String orderCode,
    required num progress,
  }) async {
    try {
      print('BackgroundService: Testing trip progress completion notification');
      print('  - Trip Code: $tripCode');
      print('  - Robot Code: $robotCode');
      print('  - Order Code: $orderCode');
      print('  - Progress: $progress');

      // Simulate received MQTT message data
      final testData = {
        'status': 'in_progress',
        'progress': progress,
        'timestamp': DateTime.now().toIso8601String(),
        'trip_code': tripCode,
        'robot_code': robotCode,
        'order_code': orderCode,
        'test_mode': true,
      };

      // Store test data in SharedPreferences for testing
      final prefs = await SharedPreferences.getInstance();
      final progressKey = 'trip_progress_$tripCode';
      await prefs.setString(progressKey, json.encode(testData));

      // Process through the notification logic directly
      await _testTripProgressNotification(
        testData,
        tripCode,
        robotCode,
        orderCode,
      );

      print('BackgroundService: Test trip progress completion processed');
      return true;
    } catch (e) {
      print('BackgroundService: Error in test trip progress completion: $e');
      return false;
    }
  }

  /// Helper method to test trip progress notifications
  static Future<void> _testTripProgressNotification(
    Map<String, dynamic> data,
    String tripCode,
    String robotCode,
    String orderCode,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final progress = data['progress'] as num?;

    if (progress != null) {
      // Handle both decimal (0.0-1.0) and percentage (0-100) formats
      final currentProgress = progress > 1
          ? progress.round()
          : (progress * 100).round();
      final lastNotifiedProgress =
          prefs.getInt('last_notified_progress_$tripCode') ?? 0;

      String? notificationTitle;
      String? notificationBody;

      // Test notification logic for 100% completion
      if (currentProgress >= 100 && lastNotifiedProgress < 100) {
        notificationTitle = 'Trip Completed (Test)';
        notificationBody =
            'Test trip $tripCode has been completed successfully! Your package has been delivered.';
        await prefs.setInt('last_notified_progress_$tripCode', 100);
        print(
          'BackgroundService: Test trip completed notification triggered at 100% progress',
        );
      }

      // Send test notification if we have one
      if (notificationTitle != null && notificationBody != null) {
        await _sendTestBackgroundNotification(
          notificationTitle,
          notificationBody,
        );
      }
    }
  }

  /// Send test notification from background
  static Future<void> _sendTestBackgroundNotification(
    String title,
    String body,
  ) async {
    try {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

      // Initialize notification plugin for background use
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await flutterLocalNotificationsPlugin.initialize(initializationSettings);

      // Create notification channel
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'zippy_test_delivery',
        'Zippy Test Delivery',
        description: 'Test notifications for delivery robot status',
        importance: Importance.high,
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);

      // Send notification
      const NotificationDetails notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'zippy_test_delivery',
          'Zippy Test Delivery',
          channelDescription: 'Test notifications for delivery robot status',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          enableVibration: true,
          playSound: true,
        ),
      );

      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        notificationDetails,
        payload: 'test_background_delivery',
      );

      print('BackgroundService: Test background notification sent - $title');
    } catch (e) {
      print(
        'BackgroundService: Error sending test background notification: $e',
      );
    }
  }

  /// Cancel all background tasks
  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
    print('BackgroundService: Cancelled all background tasks');
  }
}

/// Background callback dispatcher - runs in isolate
@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      switch (task) {
        case BackgroundService._robotStatusCheckTask:
          return await _checkRobotStatus();
        case BackgroundService._tripProgressCheckTask:
          return await _checkTripProgressOnly(inputData);
        default:
          print('BackgroundService: Unknown task: $task');
          return false;
      }
    } catch (e) {
      print('BackgroundService: Error in task $task: $e');
      return false;
    }
  });
}

/// Check robot status and send notifications
Future<bool> _checkRobotStatus() async {
  try {
    print('BackgroundService: Starting robot status check...');

    final prefs = await SharedPreferences.getInstance();
    final isMonitoring = prefs.getBool('is_monitoring_active') ?? false;
    final isTripMonitoring =
        prefs.getBool('is_trip_monitoring_active') ?? false;

    if (!isMonitoring && !isTripMonitoring) {
      print('BackgroundService: No active monitoring configured');
      return true; // Task completed successfully
    }

    // Check if main app was recently active (avoid conflicts)
    final lastAppActivity = prefs.getInt('last_app_activity') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final timeSinceLastActivity = now - lastAppActivity;

    // Don't run background check if app was active within last 2 minutes
    if (timeSinceLastActivity < 120000) {
      print(
        'BackgroundService: App recently active ($timeSinceLastActivity ms ago), skipping background check',
      );
      return true;
    }

    // Check if there's an active MQTT connection flag
    final hasActiveMqttConnection =
        prefs.getBool('mqtt_connection_active') ?? false;
    if (hasActiveMqttConnection) {
      print(
        'BackgroundService: Main app MQTT connection active, skipping background check',
      );
      return true;
    }

    bool result = true;

    // Handle regular robot monitoring
    if (isMonitoring) {
      final robotId = prefs.getString('active_robot_id');
      final orderId = prefs.getString('active_order_id');
      final deliveryPhase = prefs.getString('active_delivery_phase');

      if (robotId != null && orderId != null && deliveryPhase != null) {
        print(
          'BackgroundService: Checking robot $robotId for $deliveryPhase phase',
        );
        result &= await _connectToMqttAndCheck(robotId, deliveryPhase);
      }
    }

    // Handle trip progress monitoring
    if (isTripMonitoring) {
      final tripCode = prefs.getString('active_trip_code');
      final robotCode = prefs.getString('active_trip_robot_code');
      final orderCode = prefs.getString('active_trip_order_code');

      if (tripCode != null && robotCode != null && orderCode != null) {
        print(
          'BackgroundService: Checking trip progress for trip $tripCode with robot $robotCode',
        );
        result &= await _connectToMqttAndCheckTripProgress(
          tripCode,
          robotCode,
          orderCode,
        );
      }
    }

    print('BackgroundService: Robot status check completed - result: $result');
    return result;
  } catch (e) {
    print('BackgroundService: Error checking robot status: $e');
    return false;
  }
}

/// Connect to MQTT and check robot status
Future<bool> _connectToMqttAndCheck(
  String robotId,
  String deliveryPhase,
) async {
  MqttServerClient? client;
  int retryCount = 0;
  const maxRetries = 3;

  while (retryCount < maxRetries) {
    try {
      // Add network state check before attempting connection
      await _logBackgroundExecution(
        'Attempting MQTT connection (retry $retryCount/$maxRetries) for robot $robotId',
      );

      // Check network state before attempting connection
      final networkStatus = await NetworkStateChecker.getNetworkStatus();
      await _logBackgroundExecution(
        'Network status: ${networkStatus.toString().replaceAll('\n', ' | ')}',
      );

      if (!networkStatus.isConnected || !networkStatus.canReachInternet) {
        await _logBackgroundExecution(
          'Network not available, skipping MQTT connection attempt',
        );

        // Wait longer for network to become available
        final networkAvailable = await NetworkStateChecker.waitForNetwork(
          timeout: const Duration(seconds: 30),
        );

        if (!networkAvailable) {
          await _logBackgroundExecution(
            'Network still not available after waiting, moving to next retry',
          );
          retryCount++;
          continue;
        }
      }

      // Create MQTT client for background check with unique identifier
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final clientId = 'zippy_bg_${timestamp}_${robotId}_bg_r$retryCount';
      client = MqttServerClient.withPort('192.168.0.191', clientId, 21213);

      client.logging(on: false); // Disable logging in background
      client.setProtocolV311();
      client.keepAlivePeriod = 90; // Longer keep alive for background stability
      client.connectTimeoutPeriod = 15000; // Increased timeout for background
      client.autoReconnect = true; // Enable auto-reconnect in background

      // Set up connection message with clean session and unique will topic
      final connMess = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .withWillTopic('zippy/background/disconnect')
          .withWillMessage('Background client $clientId disconnected')
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);

      // Add authentication with background-specific credentials if needed
      connMess.authenticateAs('admin', '123@123');
      client.connectionMessage = connMess;

      await _logBackgroundExecution(
        'Attempting connection with client ID: $clientId (retry $retryCount)',
      );

      // Connect to MQTT broker with retry logic and error handling
      MqttClientConnectionStatus? status;
      try {
        status = await client.connect();
      } catch (socketException) {
        await _logBackgroundExecution(
          'SocketException during connection: $socketException',
        );

        // Handle specific socket errors
        if (socketException.toString().contains('connection abort') ||
            socketException.toString().contains('errno = 103')) {
          await _logBackgroundExecution(
            'Connection aborted by system - likely background network restriction',
          );

          // Longer delay for network restriction errors
          if (retryCount < maxRetries - 1) {
            final delayMinutes = (retryCount + 1) * 2; // 2, 4, 6 minute delays
            await _logBackgroundExecution(
              'Waiting ${delayMinutes} minutes before retry due to connection abort',
            );
            await Future.delayed(Duration(minutes: delayMinutes));
          }
          retryCount++;
          continue;
        } else {
          // Other socket exceptions - shorter retry delay
          throw socketException;
        }
      }

      if (status?.state == MqttConnectionState.connected) {
        await _logBackgroundExecution('Connected to MQTT broker successfully');

        // Subscribe to specific robot status topics
        final robotStatusTopic = 'robot/$robotId/status';
        final robotLocationTopic = 'robot/$robotId/location';

        await _logBackgroundExecution(
          'Subscribing to topics for robot $robotId',
        );
        client.subscribe(robotStatusTopic, MqttQos.atLeastOnce);
        client.subscribe(robotLocationTopic, MqttQos.atLeastOnce);

        // Listen for messages with timeout
        bool statusReceived = false;
        bool messageProcessed = false;

        final messageSubscription = client.updates!.listen((
          List<MqttReceivedMessage<MqttMessage?>> messages,
        ) async {
          for (final message in messages) {
            if (messageProcessed) break; // Only process first relevant message

            final recMess = message.payload as MqttPublishMessage;
            final messageStr = MqttPublishPayload.bytesToStringAsString(
              recMess.payload.message,
            );
            final topic = message.topic;

            await _logBackgroundExecution(
              'Received message on $topic: $messageStr',
            );

            try {
              final data = json.decode(messageStr) as Map<String, dynamic>;
              await _processBackgroundMessage(
                data,
                topic,
                robotId,
                deliveryPhase,
              );
              statusReceived = true;
              messageProcessed = true;
            } catch (e) {
              await _logBackgroundExecution('Error parsing message: $e');
            }
          }
        });

        // Wait for messages (with shorter timeout for retries)
        await Future.delayed(const Duration(seconds: 8));

        // Cancel subscription to clean up
        await messageSubscription.cancel();

        return statusReceived;
      } else {
        await _logBackgroundExecution(
          'Failed to connect to MQTT broker: ${status?.state}, return code: ${status?.returnCode}',
        );

        retryCount++;
        if (retryCount < maxRetries) {
          // Wait before retry with exponential backoff (but shorter than connection abort delays)
          final waitTime = Duration(seconds: 5 * retryCount); // 5s, 10s, 15s
          await _logBackgroundExecution(
            'Waiting ${waitTime.inSeconds}s before retry...',
          );
          await Future.delayed(waitTime);
        }
      }
    } catch (e) {
      await _logBackgroundExecution(
        'Error in MQTT connection (retry $retryCount): $e',
      );
      retryCount++;
      if (retryCount < maxRetries) {
        final waitTime = Duration(seconds: 5 * retryCount);
        await Future.delayed(waitTime);
      }
    } finally {
      // Always disconnect
      try {
        client?.disconnect();
      } catch (e) {
        await _logBackgroundExecution('Error disconnecting MQTT: $e');
      }
    }
  }

  await _logBackgroundExecution(
    'All MQTT connection attempts failed after $maxRetries retries',
  );
  return false;
}

/// Connect to MQTT and check trip progress
Future<bool> _connectToMqttAndCheckTripProgress(
  String tripCode,
  String robotCode,
  String orderCode,
) async {
  MqttServerClient? client;
  int retryCount = 0;
  const maxRetries = 3;

  while (retryCount < maxRetries) {
    try {
      await _logBackgroundExecution(
        'Attempting trip progress MQTT connection (retry $retryCount/$maxRetries) for trip $tripCode',
      );

      // Check network state before attempting trip progress connection
      final networkStatus = await NetworkStateChecker.getNetworkStatus();
      await _logBackgroundExecution(
        'Trip progress network status: ${networkStatus.toString().replaceAll('\n', ' | ')}',
      );

      if (!networkStatus.isConnected || !networkStatus.canReachInternet) {
        await _logBackgroundExecution(
          'Network not available for trip progress, skipping connection attempt',
        );

        // Wait for network to become available
        final networkAvailable = await NetworkStateChecker.waitForNetwork(
          timeout: const Duration(seconds: 30),
        );

        if (!networkAvailable) {
          await _logBackgroundExecution(
            'Network still not available for trip progress after waiting, moving to next retry',
          );
          retryCount++;
          continue;
        }
      }

      // Create MQTT client for background trip progress check
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final clientId = 'zippy_trip_bg_${timestamp}_${tripCode}_bg_r$retryCount';
      client = MqttServerClient.withPort('192.168.0.191', clientId, 21213);

      client.logging(on: false);
      client.setProtocolV311();
      client.keepAlivePeriod = 90; // Longer keep alive for background stability
      client.connectTimeoutPeriod = 15000; // Increased timeout for background
      client.autoReconnect = false;

      final connMess = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .withWillTopic('zippy/background/trip/disconnect')
          .withWillMessage('Background trip client $clientId disconnected')
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);

      connMess.authenticateAs('admin', '123@123');
      client.connectionMessage = connMess;

      await _logBackgroundExecution(
        'Attempting trip progress connection with client ID: $clientId (retry $retryCount)',
      );

      // Connect with enhanced error handling
      MqttClientConnectionStatus? status;
      try {
        status = await client.connect();
      } catch (socketException) {
        await _logBackgroundExecution(
          'SocketException during trip progress connection: $socketException',
        );

        // Handle specific socket errors
        if (socketException.toString().contains('connection abort') ||
            socketException.toString().contains('errno = 103')) {
          await _logBackgroundExecution(
            'Trip progress connection aborted by system - likely background network restriction',
          );

          // Longer delay for network restriction errors
          if (retryCount < maxRetries - 1) {
            final delayMinutes =
                (retryCount + 1) * 3; // 3, 6, 9 minute delays for trip progress
            await _logBackgroundExecution(
              'Waiting ${delayMinutes} minutes before trip progress retry due to connection abort',
            );
            await Future.delayed(Duration(minutes: delayMinutes));
          }
          retryCount++;
          continue;
        } else {
          // Other socket exceptions - shorter retry delay
          throw socketException;
        }
      }

      if (status?.state == MqttConnectionState.connected) {
        await _logBackgroundExecution(
          'Connected to MQTT broker for trip progress',
        );

        // Subscribe to trip progress topic
        final tripProgressTopic = 'trip/$tripCode/progress';
        await _logBackgroundExecution(
          'Subscribing to trip progress topic: $tripProgressTopic',
        );
        client.subscribe(tripProgressTopic, MqttQos.atLeastOnce);

        bool progressReceived = false;
        bool messageProcessed = false;

        final messageSubscription = client.updates!.listen((
          List<MqttReceivedMessage<MqttMessage?>> messages,
        ) async {
          for (final message in messages) {
            if (messageProcessed) break;

            final recMess = message.payload as MqttPublishMessage;
            final messageStr = MqttPublishPayload.bytesToStringAsString(
              recMess.payload.message,
            );
            final topic = message.topic;

            await _logBackgroundExecution(
              'Received trip progress message on $topic: $messageStr',
            );

            try {
              final data = json.decode(messageStr) as Map<String, dynamic>;
              await _processTripProgressMessage(
                data,
                tripCode,
                robotCode,
                orderCode,
              );
              progressReceived = true;
              messageProcessed = true;
            } catch (e) {
              await _logBackgroundExecution(
                'Error parsing trip progress message: $e',
              );
            }
          }
        });

        // Wait for messages
        await Future.delayed(const Duration(seconds: 8));

        await messageSubscription.cancel();
        return progressReceived;
      } else {
        await _logBackgroundExecution(
          'Failed to connect to MQTT broker for trip progress: ${status?.state}, return code: ${status?.returnCode}',
        );

        retryCount++;
        if (retryCount < maxRetries) {
          final waitTime = Duration(seconds: 5 * retryCount);
          await _logBackgroundExecution(
            'Waiting ${waitTime.inSeconds}s before trip progress retry...',
          );
          await Future.delayed(waitTime);
        }
      }
    } catch (e) {
      await _logBackgroundExecution(
        'Error in trip progress MQTT connection (retry $retryCount): $e',
      );
      retryCount++;
      if (retryCount < maxRetries) {
        final waitTime = Duration(seconds: 5 * retryCount);
        await Future.delayed(waitTime);
      }
    } finally {
      try {
        client?.disconnect();
      } catch (e) {
        await _logBackgroundExecution(
          'Error disconnecting trip progress MQTT: $e',
        );
      }
    }
  }

  await _logBackgroundExecution(
    'All trip progress MQTT connection attempts failed after $maxRetries retries',
  );
  return false;
}

/// Process background MQTT message and send notification if needed
Future<void> _processBackgroundMessage(
  Map<String, dynamic> data,
  String topic,
  String robotId,
  String deliveryPhase,
) async {
  try {
    final status = data['status'] as String?;
    final location = data['location'] as String?;

    if (status == null) return;

    String? notificationTitle;
    String? notificationBody;

    // Check for arrival notifications based on delivery phase
    if (status.toLowerCase() == 'arrived' && location != null) {
      if (deliveryPhase == 'pickup' &&
          (location.toLowerCase().contains('pickup') ||
              location.toLowerCase().contains('start') ||
              location.toLowerCase().contains('origin'))) {
        notificationTitle = 'Robot Arrived for Pickup';
        notificationBody =
            'Robot $robotId has arrived at pickup location. Please scan QR code to open container.';
      } else if (deliveryPhase == 'delivery' &&
          (location.toLowerCase().contains('delivery') ||
              location.toLowerCase().contains('destination') ||
              location.toLowerCase().contains('end'))) {
        notificationTitle = 'Robot Arrived for Delivery';
        notificationBody =
            'Robot $robotId has arrived at delivery location. Please scan QR code to receive your package.';
      }
    }

    // Send notification if relevant
    if (notificationTitle != null && notificationBody != null) {
      await _sendBackgroundNotification(notificationTitle, notificationBody);
    }
  } catch (e) {
    print('BackgroundService: Error processing background message: $e');
  }
}

/// Process trip progress message and persist to storage
Future<void> _processTripProgressMessage(
  Map<String, dynamic> data,
  String tripCode,
  String robotCode,
  String orderCode,
) async {
  try {
    final prefs = await SharedPreferences.getInstance();

    // Cache the trip progress data
    final progressKey = 'trip_progress_$tripCode';
    final progressJson = json.encode(data);
    await prefs.setString(progressKey, progressJson);
    await prefs.setInt(
      '${progressKey}_timestamp',
      DateTime.now().millisecondsSinceEpoch,
    );

    print(
      'BackgroundService: Cached trip progress for $tripCode: ${data.toString()}',
    );

    // Check for completion or important status updates
    final status = data['status'] as String?;
    final location = data['location'] as String?;
    final progress = data['progress'] as num?;

    print('BackgroundService: Processing trip progress message:');
    print('  - Trip Code: $tripCode');
    print('  - Robot Code: $robotCode');
    print('  - Order Code: $orderCode');
    print('  - Status: $status');
    print('  - Location: $location');
    print('  - Progress: $progress (${progress?.runtimeType})');

    String? notificationTitle;
    String? notificationBody;

    if (status != null) {
      switch (status.toLowerCase()) {
        case 'arrived':
          if (location != null) {
            if (location.toLowerCase().contains('pickup')) {
              notificationTitle = 'Robot Arrived at Pickup';
              notificationBody =
                  'Robot $robotCode has arrived at pickup location for order $orderCode.';
            } else if (location.toLowerCase().contains('delivery') ||
                location.toLowerCase().contains('destination')) {
              notificationTitle = 'Robot Arrived at Destination';
              notificationBody =
                  'Robot $robotCode has arrived at delivery location for order $orderCode.';
            }
          }
          break;
        case 'completed':
          notificationTitle = 'Trip Completed';
          notificationBody = 'Trip $tripCode has been completed successfully.';
          // Stop monitoring when trip is completed
          await BackgroundService.stopTripProgressMonitoring();
          break;
        case 'cancelled':
          notificationTitle = 'Trip Cancelled';
          notificationBody = 'Trip $tripCode has been cancelled.';
          await BackgroundService.stopTripProgressMonitoring();
          break;
      }
    }

    // Progress milestone notifications
    if (progress != null) {
      // Handle both decimal (0.0-1.0) and percentage (0-100) formats
      final currentProgress = progress > 1
          ? progress.round()
          : (progress * 100).round();
      final lastNotifiedProgress =
          prefs.getInt('last_notified_progress_$tripCode') ?? 0;

      print(
        'BackgroundService: Processing progress - current: $currentProgress%, last notified: $lastNotifiedProgress%',
      );

      // Notify at 25%, 50%, 75%, 100% progress milestones
      if (currentProgress >= 100 && lastNotifiedProgress < 100) {
        // Trip completed notification
        notificationTitle = 'Trip Completed';
        notificationBody =
            'Trip $tripCode has been completed successfully! Your package has been delivered.';
        await prefs.setInt('last_notified_progress_$tripCode', 100);
        print(
          'BackgroundService: Trip completed notification triggered at 100% progress',
        );
        // Stop monitoring when trip reaches 100%
        await BackgroundService.stopTripProgressMonitoring();
      } else if (currentProgress >= 75 && lastNotifiedProgress < 75) {
        notificationTitle = 'Trip Progress Update';
        notificationBody = 'Your delivery is 75% complete.';
        await prefs.setInt('last_notified_progress_$tripCode', 75);
        print('BackgroundService: Progress notification triggered at 75%');
      } else if (currentProgress >= 50 && lastNotifiedProgress < 50) {
        notificationTitle = 'Trip Progress Update';
        notificationBody = 'Your delivery is 50% complete.';
        await prefs.setInt('last_notified_progress_$tripCode', 50);
        print('BackgroundService: Progress notification triggered at 50%');
      } else if (currentProgress >= 25 && lastNotifiedProgress < 25) {
        notificationTitle = 'Trip Progress Update';
        notificationBody = 'Your delivery is 25% complete.';
        await prefs.setInt('last_notified_progress_$tripCode', 25);
        print('BackgroundService: Progress notification triggered at 25%');
      }
    }

    // Send notification if we have one
    if (notificationTitle != null && notificationBody != null) {
      print(
        'BackgroundService: Sending notification - Title: "$notificationTitle", Body: "$notificationBody"',
      );
      await _sendBackgroundNotification(notificationTitle, notificationBody);
      print('BackgroundService: Notification sent successfully');
    } else {
      print('BackgroundService: No notification to send');
      print('  - notificationTitle: $notificationTitle');
      print('  - notificationBody: $notificationBody');
      print('  - status: $status');
      print(
        '  - progress: $progress (currentProgress: ${progress != null ? (progress > 1 ? progress.round() : (progress * 100).round()) : "null"})',
      );
    }
  } catch (e) {
    print('BackgroundService: Error processing trip progress message: $e');
  }
}

/// Send notification from background
Future<void> _sendBackgroundNotification(String title, String body) async {
  try {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    // Initialize notification plugin for background use
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Create notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'zippy_delivery_background',
      'Zippy Background Delivery',
      description: 'Background notifications for delivery robot status',
      importance: Importance.high,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    // Send notification
    const NotificationDetails notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'zippy_delivery_background',
        'Zippy Background Delivery',
        channelDescription:
            'Background notifications for delivery robot status',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
      ),
    );

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      notificationDetails,
      payload: 'background_delivery',
    );

    print('BackgroundService: Background notification sent - $title');
  } catch (e) {
    print('BackgroundService: Error sending background notification: $e');
  }
}

/// Check trip progress only - dedicated task for trip monitoring
Future<bool> _checkTripProgressOnly(Map<String, dynamic>? inputData) async {
  try {
    // Log the background task execution
    await _logBackgroundExecution(
      '=== Dedicated trip progress check started ===',
    );

    print('BackgroundService: Starting dedicated trip progress check...');

    // Get trip details from input data (more reliable than SharedPreferences)
    final tripCode = inputData?['trip_code'] as String?;
    final robotCode = inputData?['robot_code'] as String?;
    final orderCode = inputData?['order_code'] as String?;

    await _logBackgroundExecution(
      'Trip details from input: trip=$tripCode, robot=$robotCode, order=$orderCode',
    );

    if (tripCode == null || robotCode == null || orderCode == null) {
      await _logBackgroundExecution(
        'Missing trip details in input, checking SharedPreferences',
      );
      print('BackgroundService: Missing trip details in dedicated task input');

      // Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final fallbackTripCode = prefs.getString('active_trip_code');
      final fallbackRobotCode = prefs.getString('active_trip_robot_code');
      final fallbackOrderCode = prefs.getString('active_trip_order_code');

      await _logBackgroundExecution(
        'Fallback details: trip=$fallbackTripCode, robot=$fallbackRobotCode, order=$fallbackOrderCode',
      );

      if (fallbackTripCode == null ||
          fallbackRobotCode == null ||
          fallbackOrderCode == null) {
        await _logBackgroundExecution(
          '❌ No valid trip details found, stopping task',
        );
        print(
          'BackgroundService: No valid trip details found, stopping dedicated task',
        );
        return false;
      }

      final result = await _connectToMqttAndCheckTripProgress(
        fallbackTripCode,
        fallbackRobotCode,
        fallbackOrderCode,
      );
      await _logBackgroundExecution(
        'Task completed with fallback data, result: $result',
      );
      return result;
    }

    // Check if main app was recently active (avoid conflicts)
    final prefs = await SharedPreferences.getInstance();
    final lastAppActivity = prefs.getInt('last_app_activity') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final timeSinceLastActivity = now - lastAppActivity;

    await _logBackgroundExecution(
      'Last app activity: ${timeSinceLastActivity}ms ago',
    );

    // Don't run background check if app was active within last 2 minutes
    if (timeSinceLastActivity < 120000) {
      await _logBackgroundExecution(
        '⏸️ App recently active, skipping background check',
      );
      print(
        'BackgroundService: App recently active ($timeSinceLastActivity ms ago), skipping dedicated trip check',
      );
      return true;
    }

    // Check if there's an active MQTT connection flag
    final hasActiveMqttConnection =
        prefs.getBool('mqtt_connection_active') ?? false;
    if (hasActiveMqttConnection) {
      await _logBackgroundExecution(
        '⏸️ Main app MQTT active, skipping background check',
      );
      print(
        'BackgroundService: Main app MQTT connection active, skipping dedicated trip check',
      );
      return true;
    }

    await _logBackgroundExecution(
      '✅ Conditions met, starting MQTT connection test',
    );
    print(
      'BackgroundService: Checking trip progress for trip $tripCode with robot $robotCode',
    );

    final result = await _connectToMqttAndCheckTripProgress(
      tripCode,
      robotCode,
      orderCode,
    );

    await _logBackgroundExecution(
      'MQTT connection test completed, result: $result',
    );
    print(
      'BackgroundService: Dedicated trip progress check completed - result: $result',
    );

    await _logBackgroundExecution(
      '=== Dedicated trip progress check completed ===',
    );
    return result;
  } catch (e) {
    await _logBackgroundExecution(
      '❌ Error in dedicated trip progress check: $e',
    );
    print('BackgroundService: Error in dedicated trip progress check: $e');
    return false;
  }
}

/// Log background execution for debugging
Future<void> _logBackgroundExecution(String message) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final logs = prefs.getStringList('background_execution_log') ?? [];

    final timestamp = DateTime.now().toIso8601String();
    logs.add('[$timestamp] $message');

    // Keep only last 100 entries
    if (logs.length > 100) {
      logs.removeAt(0);
    }

    await prefs.setStringList('background_execution_log', logs);
    print('BackgroundLog: $message');
  } catch (e) {
    print('Error logging background execution: $e');
  }
}
