import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../mqtt/mqtt_service.dart';
import '../native/network_state_checker.dart';

/// Persistent MQTT connection manager that maintains connectivity
/// across all app states: launching, paused, hidden, locked screen
class PersistentMqttManager {
  static PersistentMqttManager? _instance;
  static PersistentMqttManager get instance =>
      _instance ??= PersistentMqttManager._();

  PersistentMqttManager._();

  bool _isInitialized = false;
  bool _isRunning = false;
  Timer? _connectionTimer;
  Timer? _healthCheckTimer;
  Timer? _networkRetryTimer;

  // Connection state tracking
  int _connectionAttempts = 0;
  int _consecutiveFailures = 0;
  DateTime? _lastSuccessfulConnection;
  DateTime? _lastConnectionAttempt;

  // Configuration
  static const Duration _baseConnectionInterval = Duration(seconds: 30);
  static const Duration _maxConnectionInterval = Duration(minutes: 10);
  static const Duration _healthCheckInterval = Duration(seconds: 60);
  static const Duration _networkRetryInterval = Duration(minutes: 2);

  /// Check if persistent MQTT manager is initialized
  bool get isInitialized => _isInitialized;

  /// Check if persistent MQTT manager is running
  bool get isRunning => _isRunning;

  /// Initialize persistent MQTT connection management
  Future<void> initialize() async {
    if (_isInitialized) {
      print('PersistentMqttManager: Already initialized');
      return;
    }

    try {
      await _logPersistentActivity('Initializing persistent MQTT manager');

      // Set up platform-specific lifecycle handling
      await _setupPlatformLifecycleHandling();

      _isInitialized = true;

      // Start persistent connection management
      await start();

      await _logPersistentActivity(
        'Persistent MQTT manager initialized successfully',
      );
    } catch (e) {
      await _logPersistentActivity(
        'Failed to initialize persistent MQTT manager: $e',
      );
      rethrow;
    }
  }

  /// Start persistent connection management
  Future<void> start() async {
    if (_isRunning) {
      await _logPersistentActivity('Persistent MQTT manager already running');
      return;
    }

    _isRunning = true;
    await _logPersistentActivity(
      'Starting persistent MQTT connection management',
    );

    // Immediate connection attempt
    await _attemptConnection();

    // Set up periodic connection monitoring
    _connectionTimer = Timer.periodic(_baseConnectionInterval, (timer) {
      _attemptConnection();
    });

    // Set up health checks
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (timer) {
      _performHealthCheck();
    });

    // Set up network retry logic
    _networkRetryTimer = Timer.periodic(_networkRetryInterval, (timer) {
      _handleNetworkRetry();
    });

    await _logPersistentActivity('Persistent MQTT timers started');
  }

  /// Stop persistent connection management
  Future<void> stop() async {
    if (!_isRunning) return;

    _isRunning = false;

    _connectionTimer?.cancel();
    _healthCheckTimer?.cancel();
    _networkRetryTimer?.cancel();

    _connectionTimer = null;
    _healthCheckTimer = null;
    _networkRetryTimer = null;

    await _logPersistentActivity(
      'Persistent MQTT connection management stopped',
    );
  }

  /// Attempt MQTT connection with intelligent retry logic
  Future<void> _attemptConnection() async {
    if (!_isRunning) return;

    try {
      _lastConnectionAttempt = DateTime.now();
      _connectionAttempts++;

      await _logPersistentActivity(
        'Attempting MQTT connection (attempt $_connectionAttempts)',
      );

      // Check network state first
      final networkStatus = await NetworkStateChecker.getNetworkStatus();

      if (!networkStatus.isConnected || !networkStatus.canReachInternet) {
        await _logPersistentActivity(
          'Network not available, skipping connection attempt',
        );
        _handleConnectionFailure('Network not available');
        return;
      }

      // Check if already connected
      if (MqttService.isConnected) {
        await _logPersistentActivity(
          'MQTT already connected, skipping connection attempt',
        );
        _handleConnectionSuccess();
        return;
      }

      // Attempt connection
      final success = await MqttService.initialize(
        brokerHost: '36.50.135.207',
        brokerPort: 1883,
        username: 'khanhnc',
        password: '12345678',
        clientId: 'persistent_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (success) {
        await _logPersistentActivity('MQTT connection successful');
        _handleConnectionSuccess();

        // Update app activity to prevent background service conflicts
        await _updateAppActivity();
      } else {
        await _logPersistentActivity('MQTT connection failed');
        _handleConnectionFailure('Connection initialization failed');
      }
    } catch (e) {
      await _logPersistentActivity('MQTT connection error: $e');
      _handleConnectionFailure(e.toString());
    }
  }

  /// Handle successful connection
  void _handleConnectionSuccess() {
    _lastSuccessfulConnection = DateTime.now();
    _consecutiveFailures = 0;

    // Reset connection interval to base value on success
    _updateConnectionTimer(_baseConnectionInterval);
  }

  /// Handle connection failure with exponential backoff
  void _handleConnectionFailure(String reason) {
    _consecutiveFailures++;

    // Calculate exponential backoff delay
    Duration nextInterval = _calculateBackoffInterval();

    _logPersistentActivity(
      'Connection failed (consecutive failures: $_consecutiveFailures). Next attempt in ${nextInterval.inSeconds}s. Reason: $reason',
    );

    // Update connection timer with backoff
    _updateConnectionTimer(nextInterval);
  }

  /// Calculate exponential backoff interval
  Duration _calculateBackoffInterval() {
    // Base interval * 2^failures, capped at max interval
    final multiplier =
        (1 << _consecutiveFailures.clamp(0, 6)); // Max 64x multiplier
    final intervalSeconds = (_baseConnectionInterval.inSeconds * multiplier)
        .clamp(
          _baseConnectionInterval.inSeconds,
          _maxConnectionInterval.inSeconds,
        );

    return Duration(seconds: intervalSeconds);
  }

  /// Update connection timer with new interval
  void _updateConnectionTimer(Duration interval) {
    _connectionTimer?.cancel();
    _connectionTimer = Timer.periodic(interval, (timer) {
      _attemptConnection();
    });
  }

  /// Perform health check on existing connection
  Future<void> _performHealthCheck() async {
    if (!_isRunning) return;

    try {
      await _logPersistentActivity('Performing MQTT health check');

      if (!MqttService.isConnected) {
        await _logPersistentActivity(
          'Health check: MQTT not connected, triggering reconnection',
        );
        await _attemptConnection();
        return;
      }

      // Test connection by publishing a heartbeat
      try {
        await MqttService.publish('zippy/heartbeat', {
          'client_id': 'persistent_manager',
          'timestamp': DateTime.now().toIso8601String(),
          'app_state': await _getAppState(),
        });

        await _logPersistentActivity('Health check: MQTT connection healthy');

        // Update app activity on successful health check
        await _updateAppActivity();
      } catch (e) {
        await _logPersistentActivity(
          'Health check: MQTT publish failed, triggering reconnection: $e',
        );
        await MqttService.disconnect();
        await _attemptConnection();
      }
    } catch (e) {
      await _logPersistentActivity('Health check error: $e');
    }
  }

  /// Handle network retry for failed connections
  Future<void> _handleNetworkRetry() async {
    if (!_isRunning) return;

    // Only retry if we have consecutive failures
    if (_consecutiveFailures < 3) return;

    try {
      await _logPersistentActivity(
        'Network retry: Checking network status after failures',
      );

      final networkStatus = await NetworkStateChecker.getNetworkStatus();

      if (networkStatus.isHealthy && !MqttService.isConnected) {
        await _logPersistentActivity(
          'Network retry: Network is healthy, attempting immediate reconnection',
        );

        // Reset failure count on network recovery
        _consecutiveFailures = 0;

        // Immediate connection attempt
        await _attemptConnection();
      }
    } catch (e) {
      await _logPersistentActivity('Network retry error: $e');
    }
  }

  /// Set up platform-specific lifecycle handling
  Future<void> _setupPlatformLifecycleHandling() async {
    if (Platform.isAndroid) {
      await _setupAndroidLifecycleHandling();
    } else if (Platform.isIOS) {
      await _setupiOSLifecycleHandling();
    }
  }

  /// Set up Android-specific lifecycle handling
  Future<void> _setupAndroidLifecycleHandling() async {
    try {
      // Android handles app lifecycle through WidgetsBindingObserver
      // which is already set up in the app initialization
      await _logPersistentActivity('Android lifecycle handling configured');
    } catch (e) {
      await _logPersistentActivity('Android lifecycle setup error: $e');
    }
  }

  /// Set up iOS-specific lifecycle handling
  Future<void> _setupiOSLifecycleHandling() async {
    try {
      // iOS handles app lifecycle through WidgetsBindingObserver
      // which is already set up in the app initialization
      await _logPersistentActivity('iOS lifecycle handling configured');
    } catch (e) {
      await _logPersistentActivity('iOS lifecycle setup error: $e');
    }
  }

  /// Handle app lifecycle changes
  Future<void> onAppLifecycleChanged(AppLifecycleState state) async {
    await _logPersistentActivity('App lifecycle changed: $state');

    switch (state) {
      case AppLifecycleState.resumed:
        await _onAppResumed();
        break;
      case AppLifecycleState.paused:
        await _onAppPaused();
        break;
      case AppLifecycleState.inactive:
        await _onAppInactive();
        break;
      case AppLifecycleState.detached:
        await _onAppDetached();
        break;
      case AppLifecycleState.hidden:
        await _onAppHidden();
        break;
    }
  }

  /// Handle app resumed state
  Future<void> _onAppResumed() async {
    await _logPersistentActivity('App resumed - ensuring MQTT connectivity');

    // Update app activity
    await _updateAppActivity();

    // Immediate connection check
    if (!MqttService.isConnected) {
      await _attemptConnection();
    }

    // Reset to base connection interval
    _updateConnectionTimer(_baseConnectionInterval);
  }

  /// Handle app paused state
  Future<void> _onAppPaused() async {
    await _logPersistentActivity('App paused - maintaining MQTT connectivity');

    // Continue background connectivity but with longer intervals
    _updateConnectionTimer(Duration(minutes: 2));
  }

  /// Handle app inactive state (e.g., incoming call, lock screen)
  Future<void> _onAppInactive() async {
    await _logPersistentActivity(
      'App inactive - maintaining MQTT connectivity',
    );

    // Continue connectivity with moderate intervals
    _updateConnectionTimer(Duration(minutes: 1));
  }

  /// Handle app hidden state
  Future<void> _onAppHidden() async {
    await _logPersistentActivity(
      'App hidden - maintaining MQTT connectivity with background optimization',
    );

    // Longer intervals for hidden state to save battery
    _updateConnectionTimer(Duration(minutes: 5));
  }

  /// Handle app detached state
  Future<void> _onAppDetached() async {
    await _logPersistentActivity(
      'App detached - stopping persistent MQTT management',
    );

    // Stop timers but don't disconnect MQTT (background service will handle)
    await stop();
  }

  /// Update app activity timestamp
  Future<void> _updateAppActivity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'last_app_activity',
        DateTime.now().millisecondsSinceEpoch,
      );
      await prefs.setBool('mqtt_connection_active', MqttService.isConnected);
    } catch (e) {
      await _logPersistentActivity('Failed to update app activity: $e');
    }
  }

  /// Get current app state string
  Future<String> _getAppState() async {
    // This would be set by the main app through WidgetsBinding
    return 'active'; // Simplified for now
  }

  /// Log persistent MQTT activity
  Future<void> _logPersistentActivity(String message) async {
    try {
      final timestamp = DateTime.now().toIso8601String();
      final logMessage = '[$timestamp] PersistentMQTT: $message';

      // Print to console
      print(logMessage);

      // Store in SharedPreferences for debugging
      final prefs = await SharedPreferences.getInstance();
      final logs = prefs.getStringList('persistent_mqtt_log') ?? [];
      logs.add(logMessage);

      // Keep only last 50 entries
      if (logs.length > 50) {
        logs.removeAt(0);
      }

      await prefs.setStringList('persistent_mqtt_log', logs);
    } catch (e) {
      print('Error logging persistent MQTT activity: $e');
    }
  }

  /// Get connection statistics
  Map<String, dynamic> getConnectionStats() {
    return {
      'isInitialized': _isInitialized,
      'isRunning': _isRunning,
      'isConnected': MqttService.isConnected,
      'connectionAttempts': _connectionAttempts,
      'consecutiveFailures': _consecutiveFailures,
      'lastSuccessfulConnection': _lastSuccessfulConnection?.toIso8601String(),
      'lastConnectionAttempt': _lastConnectionAttempt?.toIso8601String(),
      'timersActive': {
        'connection': _connectionTimer?.isActive ?? false,
        'healthCheck': _healthCheckTimer?.isActive ?? false,
        'networkRetry': _networkRetryTimer?.isActive ?? false,
      },
    };
  }

  /// Force immediate connection attempt
  Future<void> forceReconnect() async {
    await _logPersistentActivity('Force reconnect requested');

    // Disconnect current connection
    if (MqttService.isConnected) {
      await MqttService.disconnect();
    }

    // Reset failure count
    _consecutiveFailures = 0;

    // Immediate connection attempt
    await _attemptConnection();
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _logPersistentActivity('Disposing persistent MQTT manager');

    await stop();
    _isInitialized = false;
    _instance = null;
  }
}
