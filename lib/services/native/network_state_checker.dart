import 'dart:io';

/// Utility class for checking network connectivity and state
class NetworkStateChecker {
  /// Check if network is available and accessible
  static Future<bool> isNetworkAvailable() async {
    try {
      // Try to resolve a reliable DNS name
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Check if specific host is reachable
  static Future<bool> isHostReachable(String host, int port) async {
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 5),
      );
      socket.destroy();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if MQTT broker is accessible
  static Future<bool> isMqttBrokerReachable(String host, int port) async {
    try {
      // Try to establish a basic TCP connection to MQTT port
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 8),
      );
      socket.destroy();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get network connectivity status with details
  static Future<NetworkStatus> getNetworkStatus() async {
    try {
      // Check basic internet connectivity
      final hasInternet = await isNetworkAvailable();
      if (!hasInternet) {
        return NetworkStatus(
          isConnected: false,
          canReachInternet: false,
          error: 'No internet connectivity',
        );
      }

      // Check MQTT broker specifically
      const mqttHost = '36.50.135.207';
      const mqttPort = 1883;

      final brokerReachable = await isMqttBrokerReachable(mqttHost, mqttPort);

      return NetworkStatus(
        isConnected: true,
        canReachInternet: true,
        canReachMqttBroker: brokerReachable,
        mqttHost: mqttHost,
        mqttPort: mqttPort,
      );
    } catch (e) {
      return NetworkStatus(
        isConnected: false,
        canReachInternet: false,
        error: 'Network check failed: $e',
      );
    }
  }

  /// Wait for network to become available with timeout
  static Future<bool> waitForNetwork({
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final endTime = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(endTime)) {
      if (await isNetworkAvailable()) {
        return true;
      }

      // Wait 5 seconds before checking again
      await Future.delayed(const Duration(seconds: 5));
    }

    return false;
  }
}

/// Network status information
class NetworkStatus {
  final bool isConnected;
  final bool canReachInternet;
  final bool canReachMqttBroker;
  final String? mqttHost;
  final int? mqttPort;
  final String? error;

  NetworkStatus({
    required this.isConnected,
    required this.canReachInternet,
    this.canReachMqttBroker = false,
    this.mqttHost,
    this.mqttPort,
    this.error,
  });

  bool get isHealthy => isConnected && canReachInternet && canReachMqttBroker;

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Network Status:');
    buffer.writeln('  Connected: $isConnected');
    buffer.writeln('  Internet: $canReachInternet');
    buffer.writeln('  MQTT Broker: $canReachMqttBroker');
    if (mqttHost != null) buffer.writeln('  MQTT Host: $mqttHost:$mqttPort');
    if (error != null) buffer.writeln('  Error: $error');
    return buffer.toString();
  }
}
