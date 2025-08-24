import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zippy/services/mqtt/mqtt_service.dart';

/// Configuration for MQTT connection
class MqttConfig {
  final String brokerHost;
  final int brokerPort;
  final String? username;
  final String? password;
  final String? clientId;

  const MqttConfig({
    required this.brokerHost,
    required this.brokerPort,
    this.username,
    this.password,
    this.clientId,
  });

  // Default configuration
  static const MqttConfig defaultConfig = MqttConfig(
    brokerHost: '36.50.135.207', // MQTT broker host
    brokerPort: 1883, // Standard MQTT port
    username: 'khanhnc', // Add username if required
    password: '12345678', // Add password if required
  );
}

/// Service for managing MQTT initialization and lifecycle
class MqttManager {
  static bool _initialized = false;
  static MqttConfig? _config;

  /// Initialize MQTT service with configuration
  static Future<bool> initialize({MqttConfig? config}) async {
    if (_initialized && MqttService.isConnected) {
      print('MqttManager: Already initialized and connected');
      return true;
    }

    _config = config ?? MqttConfig.defaultConfig;

    print(
      'MqttManager: Initializing MQTT with config: ${_config!.brokerHost}:${_config!.brokerPort}',
    );

    final success = await MqttService.initialize(
      brokerHost: _config!.brokerHost,
      brokerPort: _config!.brokerPort,
      username: _config!.username,
      password: _config!.password,
      clientId: _config!.clientId,
    );

    if (success) {
      _initialized = true;
      print('MqttManager: Successfully initialized MQTT service');
    } else {
      print('MqttManager: Failed to initialize MQTT service');
    }

    return success;
  }

  /// Disconnect from MQTT service
  static Future<void> disconnect() async {
    await MqttService.disconnect();
    _initialized = false;
    print('MqttManager: Disconnected from MQTT service');
  }

  /// Check if MQTT is initialized and connected
  static bool get isConnected => _initialized && MqttService.isConnected;

  /// Get current configuration
  static MqttConfig? get config => _config;
}

/// Provider for MQTT connection status
final mqttConnectionProvider = StateProvider<bool>((ref) => false);

/// Provider for MQTT initialization
final mqttInitializationProvider = FutureProvider<bool>((ref) async {
  try {
    final success = await MqttManager.initialize();

    // Update connection status
    ref.read(mqttConnectionProvider.notifier).state = success;

    return success;
  } catch (e) {
    print('MqttInitializationProvider: Error initializing MQTT: $e');
    ref.read(mqttConnectionProvider.notifier).state = false;
    return false;
  }
});
