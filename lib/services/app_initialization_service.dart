import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zippy/services/mqtt/mqtt_manager.dart';
import 'package:zippy/services/mqtt/mqtt_payload_handler.dart';
import 'package:zippy/services/native/background_service.dart';
import 'package:zippy/services/notification/notification_service.dart';
import 'package:zippy/services/storage/persistent_mqtt_manager.dart';
import 'package:zippy/services/mqtt/mqtt_subscription_service.dart';
import 'package:zippy/services/storage/trip_storage_service.dart';

/// Service for initializing app services on startup
class AppInitializationService {
  static bool _initialized = false;

  /// Initialize all app services
  static Future<void> initialize(WidgetRef ref) async {
    if (_initialized) {
      print('AppInitializationService: Already initialized');
      return;
    }

    print('AppInitializationService: Starting initialization...');

    try {
      // Initialize notification service first
      await NotificationService().initialize();

      // Initialize background service for when app is closed
      await BackgroundService.initialize();

      // Initialize persistent MQTT service for continuous connectivity
      await _initializePersistentMqtt();

      // Initialize regular MQTT service for real-time robot updates
      await _initializeMqtt(ref);

      // Initialize MQTT payload handler for global message processing
      await _initializeMqttPayloadHandler(ref);

      // Initialize MqttSubscriptionService for global trip progress handling
      await _initializeMqttSubscriptionService();

      _initialized = true;
      print('AppInitializationService: Initialization completed successfully');
    } catch (e) {
      print('AppInitializationService: Initialization failed: $e');
      // Don't mark as initialized if there's an error
    }
  }

  /// Initialize persistent MQTT connection manager
  static Future<void> _initializePersistentMqtt() async {
    print('AppInitializationService: Initializing persistent MQTT...');

    try {
      await PersistentMqttManager.instance.initialize();
      print(
        'AppInitializationService: Persistent MQTT initialized successfully',
      );
    } catch (e) {
      print(
        'AppInitializationService: Persistent MQTT initialization failed: $e',
      );
      // Continue without persistent MQTT - regular MQTT will still work
    }
  }

  /// Initialize MQTT connection
  static Future<void> _initializeMqtt(WidgetRef ref) async {
    print('AppInitializationService: Initializing MQTT...');

    // You should replace these with your actual MQTT broker details
    const mqttConfig = MqttConfig(
      brokerHost: '36.50.135.207', // MQTT broker host
      brokerPort: 1883, // Replace with your MQTT broker port
      username: 'admin', // Add username if required
      password: '123@123', // Add password if required
    );

    final success = await MqttManager.initialize(config: mqttConfig);

    if (success) {
      print('AppInitializationService: MQTT initialized successfully');

      // Load initial robot data after MQTT is connected
      // WidgetsBinding.instance.addPostFrameCallback((_) {
      //   ref.read(robotProvider.notifier).loadRobots();
      // });
    } else {
      print('AppInitializationService: MQTT initialization failed');
      // Continue without MQTT - the app should still work with periodic updates
    }
  }

  /// Initialize MQTT payload handler for global message processing
  static Future<void> _initializeMqttPayloadHandler(WidgetRef ref) async {
    print('AppInitializationService: Initializing MQTT payload handler...');

    try {
      // Convert WidgetRef to ProviderContainer
      final container = ProviderScope.containerOf(ref.context);

      // Initialize the payload handler with the provider container
      await MqttPayloadHandler.instance.initialize(container);

      // Restore app state from previously stored payloads
      await MqttPayloadHandler.instance.restoreStateFromStoredPayloads();

      print(
        'AppInitializationService: MQTT payload handler initialized successfully',
      );
    } catch (e) {
      print(
        'AppInitializationService: MQTT payload handler initialization failed: $e',
      );
      // Continue without payload handler - basic MQTT will still work
    }
  }

  /// Initialize the MqttSubscriptionService for global handling of trip progress
  static Future<void> _initializeMqttSubscriptionService() async {
    print(
      'AppInitializationService: Initializing MQTT Subscription Service...',
    );

    try {
      // Initialize the service (this will also set up global message handler)
      final success = await MqttSubscriptionService.instance.initialize();

      if (success) {
        print(
          'AppInitializationService: MQTT Subscription Service initialized successfully',
        );

        // If we have active trips in the cache, subscribe to them
        final tripStorageService = TripStorageService();
        final activeTripCodes = await tripStorageService
            .getAllActiveTripCodes();

        for (final tripCode in activeTripCodes) {
          // For each active trip, try to find robot code from cache
          final cachedData = await tripStorageService.loadCachedTripProgress(
            tripCode,
          );
          final robotCode = cachedData?['robotCode'] as String? ?? 'unknown';

          // Subscribe to the topic
          if (robotCode != 'unknown') {
            await MqttSubscriptionService.instance.subscribeToTripProgress(
              robotCode: robotCode,
              tripCode: tripCode,
              onMessage: null, // No UI callback yet
            );
            print(
              'AppInitializationService: Auto-subscribed to $tripCode for robot $robotCode',
            );
          }
        }
      } else {
        print(
          'AppInitializationService: MQTT Subscription Service initialization failed',
        );
      }
    } catch (e) {
      print(
        'AppInitializationService: Error initializing MQTT Subscription Service: $e',
      );
    }
  }

  /// Check if services are initialized
  static bool get isInitialized => _initialized;

  /// Reset initialization state (useful for testing)
  static void reset() {
    _initialized = false;
  }
}
