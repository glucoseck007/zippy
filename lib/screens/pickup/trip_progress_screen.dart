import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design/app_colors.dart';
import '../../design/app_typography.dart';
import '../../providers/core/theme_provider.dart';
import '../../providers/trip/trip_progress_provider.dart';
import '../../services/mqtt/mqtt_service.dart';
import '../../services/trip/trip_service.dart';
import '../../state/trip/trip_progress_state.dart';
import '../../services/native/background_service.dart';
import '../../services/storage/trip_storage_service.dart';
import '../../services/mqtt/mqtt_subscription_service.dart';
import '../../services/native/background_monitoring_service.dart';
import 'qr_scanner_screen.dart';
import '../../widgets/pickup/confirm_pickup_dialog.dart';

class TripProgressScreen extends ConsumerStatefulWidget {
  final String orderCode;
  final String tripCode;
  final String robotCode;

  const TripProgressScreen({
    super.key,
    required this.orderCode,
    required this.tripCode,
    required this.robotCode,
  });

  @override
  ConsumerState<TripProgressScreen> createState() => _TripProgressScreenState();
}

class _TripProgressScreenState extends ConsumerState<TripProgressScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  Timer? _activityTimer; // Timer to update app activity timestamp

  // Robot animation
  late AnimationController _robotAnimationController;
  late Animation<double> _robotAnimation;

  // Trip progress provider
  late StateNotifierProvider<TripProgressNotifier, TripProgressState>
  _tripProgressProvider;

  @override
  @override
  void initState() {
    super.initState();

    // Initialize the trip progress provider
    _tripProgressProvider = tripProgressProvider(
      tripCode: widget.tripCode,
      orderCode: widget.orderCode,
      robotCode: widget.robotCode,
    );

    // Add app lifecycle observer
    WidgetsBinding.instance.addObserver(this);

    // Update app activity timestamp to prevent background service conflicts
    _updateAppActivityTimestamp();

    // Start periodic activity updates (every 30 seconds while screen is active)
    _activityTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateAppActivityTimestamp();
    });

    // Initialize robot animation
    _robotAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _robotAnimation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _robotAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Initialize services and data
    _initializeAll();
  }

  // Initialize all required services and data
  Future<void> _initializeAll() async {
    try {
      // Initialize services
      await _initializeServices();

      // Initialize the trip progress provider
      await ref.read(_tripProgressProvider.notifier).initialize();

      // Set up callbacks for phase completion
      ref
          .read(_tripProgressProvider.notifier)
          .setOnPhase1Complete(_showPhase1Notification);
      ref
          .read(_tripProgressProvider.notifier)
          .setOnPhase2Complete(_showPhase2Notification);

      // Fetch trip details
      await _fetchTripDetails();

      // Initialize MQTT connection and then set up subscription
      await _initializeMqttAndSubscribe();

      // Set loading to false
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('TripProgress: Error during initialization: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  // Initialize all required services
  Future<void> _initializeServices() async {
    try {
      // Initialize trip service for progress tracking
      final tripStorageService = TripStorageService();
      await tripStorageService.updateAppActivityTimestamp();

      // Initialize notification service
      await BackgroundMonitoringService.instance.initializeNotifications();

      // Register background monitoring for this delivery
      await BackgroundMonitoringService.instance.registerMonitoring(
        robotId: widget.robotCode,
        orderId: widget.orderCode,
        tripId: widget.tripCode,
      );

      print('TripProgress: Services initialized successfully');
    } catch (e) {
      print('TripProgress: Error initializing services: $e');
      // Continue without services - basic functionality should still work
    }
  }

  // Update app activity timestamp to prevent background service conflicts
  Future<void> _updateAppActivityTimestamp() async {
    try {
      await TripStorageService().updateAppActivityTimestamp();
    } catch (e) {
      print('TripProgress: Failed to update app activity timestamp: $e');

      // Fallback to direct SharedPreferences access if service fails
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
          'last_app_activity',
          DateTime.now().millisecondsSinceEpoch,
        );
        await prefs.setBool('mqtt_connection_active', true);
      } catch (e) {
        print(
          'TripProgress: Critical error updating app activity timestamp: $e',
        );
      }
    }
  }

  Future<void> _fetchTripDetails() async {
    try {
      final tripDetails = await TripService.getTripDetails(widget.tripCode);

      if (mounted && tripDetails != null) {
        // Update trip details in the provider
        ref
            .read(_tripProgressProvider.notifier)
            .updateTripDetails(
              startPoint: tripDetails['startPoint'] as String?,
              endPoint: tripDetails['endPoint'] as String?,
            );

        print(
          'TripProgress: Trip details loaded - Start: ${tripDetails['startPoint']}, End: ${tripDetails['endPoint']}',
        );
      }
    } catch (e) {
      print('TripProgress: Error fetching trip details: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _initializeMqttAndSubscribe() async {
    try {
      // Use MqttSubscriptionService for initialization and subscription
      final mqttService = MqttSubscriptionService.instance;

      final success = await mqttService.initialize();

      if (success) {
        print('TripProgress: MQTT initialized successfully');
        // Add a small delay to ensure connection is stable before subscribing
        await Future.delayed(const Duration(milliseconds: 500));
        await _setupMqttSubscription();
      } else {
        print('TripProgress: MQTT initialization failed');
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage =
                'Failed to connect to real-time updates. The app will continue to work, but you may not receive immediate notifications. Please check your internet connection and try refreshing.';
          });
        }
      }
    } catch (e) {
      print('TripProgress: Error initializing MQTT: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to connect to real-time updates. Error: $e';
        });
      }
    }
  }

  Future<void> _setupMqttSubscription() async {
    try {
      // Subscribe to trip progress using our service
      final success = await MqttSubscriptionService.instance
          .subscribeToTripProgress(
            robotCode: widget.robotCode,
            tripCode: widget.tripCode,
            onMessage: _handleMqttMessage, // Pass our UI update handler
          );

      if (success) {
        print('TripProgress: Successfully subscribed to trip progress updates');
        // Update app activity after successful MQTT connection
        _updateAppActivityTimestamp();

        // Check if we already have any cached progress for this trip
        final cachedData = await TripStorageService().loadCachedTripProgress(
          widget.tripCode,
          robotCode: widget.robotCode,
        );

        // If we have cached data, use it to update the UI immediately
        if (cachedData != null && mounted) {
          print('TripProgress: Using cached data to update UI: $cachedData');

          // Mark the data as cached to prevent re-storing it
          final markedCachedData = {
            ...cachedData,
            'fromCache': true, // Add a marker to identify cached data
          };

          // Use the cached data to update UI, but don't re-store it
          _handleMqttMessage(markedCachedData);
        }
      } else {
        print('TripProgress: Failed to subscribe to trip progress updates');
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage =
                'Failed to connect to real-time updates. The app will continue to work, but you may still receive notifications through the global handler. Please check your internet connection and try refreshing.';
          });
        }
      }
    } catch (e) {
      print('TripProgress: Error in _setupMqttSubscription: $e');
    }
  }

  void _handleMqttMessage(Map<String, dynamic> data) {
    print('TripProgress: Received MQTT message: $data');

    // Check if this is the specific trip progress message we're interested in
    final topic = data['topic'] as String?;

    // More flexible topic matching - use contains instead of exact match
    if (topic == null ||
        (!topic.contains(widget.robotCode) ||
            !topic.contains(widget.tripCode))) {
      print(
        'TripProgress: Message not for our trip. Topic: $topic, Expected to contain: ${widget.robotCode} and ${widget.tripCode}',
      );
      return;
    }

    print('TripProgress: Processing message for our trip: $data');

    // Forward the message to the provider for processing
    ref.read(_tripProgressProvider.notifier).handleMqttMessage(data);
  }

  // Handle receive order functionality (Phase 2 QR scan)
  void _handleReceiveOrder() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRScannerScreen(
          onScanned: (qrCode) {
            _onPhase2QRCodeScanned(qrCode);
          },
        ),
      ),
    );
  }

  // Handle Phase 1 QR scan (Sender opens container at pickup)
  void _handlePhase1QRScan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRScannerScreen(
          onScanned: (qrCode) {
            _onPhase1QRCodeScanned(qrCode);
          },
        ),
      ),
    );
  }

  // Show notification for Phase 1 (Robot reached pickup location)
  void _showPhase1Notification() {
    // Try to send native notification (with error handling)
    _sendNativeNotification(
      title: tr('pickup.trip_progress.phase1_notification_title'),
      body: tr('pickup.trip_progress.phase1_notification_message'),
      isPhase1: true,
    );

    // Also show in-app dialog as fallback/additional UI
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          final themeState = ref.read(themeProvider);
          final isDarkMode = themeState.isDarkMode;

          return AlertDialog(
            backgroundColor: isDarkMode ? AppColors.dmCardColor : Colors.white,
            contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 24.0),
            title: Row(
              children: [
                Icon(
                  Icons.notifications_active,
                  color: Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('pickup.trip_progress.phase1_notification_title'),
                    style:
                        (isDarkMode
                                ? AppTypography.dmHeading(context)
                                : AppTypography.heading(context))
                            .copyWith(fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Text(
                tr('pickup.trip_progress.phase1_notification_message'),
                style: isDarkMode
                    ? AppTypography.dmBodyText(context)
                    : AppTypography.bodyText(context),
              ),
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(tr('common.cancel')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _handlePhase1QRScan();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        tr('pickup.trip_progress.scan_to_open'),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );
    }
  }

  // Show notification for Phase 2 (Robot reached delivery location)
  void _showPhase2Notification() {
    // Try to send native notification (with error handling)
    _sendNativeNotification(
      title: tr('pickup.trip_progress.phase2_notification_title'),
      body: tr('pickup.trip_progress.phase2_notification_message'),
      isPhase1: false,
    );

    // Also show in-app dialog as fallback/additional UI
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          final themeState = ref.read(themeProvider);
          final isDarkMode = themeState.isDarkMode;

          return AlertDialog(
            backgroundColor: isDarkMode ? AppColors.dmCardColor : Colors.white,
            contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 24.0),
            title: Row(
              children: [
                Icon(Icons.notifications_active, color: Colors.green, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('pickup.trip_progress.phase2_notification_title'),
                    style:
                        (isDarkMode
                                ? AppTypography.dmHeading(context)
                                : AppTypography.heading(context))
                            .copyWith(fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Text(
                tr('pickup.trip_progress.phase2_notification_message'),
                style: isDarkMode
                    ? AppTypography.dmBodyText(context)
                    : AppTypography.bodyText(context),
              ),
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(tr('common.cancel')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _handleReceiveOrder();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        tr('pickup.receive_order'),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );
    }
  }

  void _onPhase1QRCodeScanned(String qrCode) {
    // Parse QR code and handle Phase 1 verification
    try {
      final parsedData = jsonDecode(qrCode);
      final tripCode = parsedData['tripCode'] ?? widget.tripCode;
      print('Phase 1 QR scan - Trip Code: $tripCode');
    } catch (e) {
      print('Phase 1 QR scan - Using current trip code: ${widget.tripCode}');
    }

    // TODO: Send API call to open container at pickup location
    // Update the provider state
    ref.read(_tripProgressProvider.notifier).onPhase1QRScanned();

    // Show success message
    _showPhaseCompletionMessage(
      title: tr('pickup.trip_progress.phase1_complete_title'),
      message: tr('pickup.trip_progress.phase1_complete_message'),
      icon: Icons.check_circle,
      color: Colors.orange,
    );
  }

  void _onPhase2QRCodeScanned(String qrCode) {
    // Parse QR code and handle Phase 2 verification (final pickup)
    String tripCode = '';
    try {
      final parsedData = jsonDecode(qrCode);
      tripCode = parsedData['tripCode'] ?? '';
    } catch (e) {
      tripCode = widget.tripCode;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ConfirmPickupDialog(
          orderCode: widget.orderCode,
          tripCode: tripCode,
          onSuccess: () {
            // Update the provider state
            ref.read(_tripProgressProvider.notifier).onPhase2QRScanned();

            // Stop background monitoring since delivery is complete
            _stopBackgroundMonitoring();

            // Clear the cached progress since pickup is complete
            ref.read(_tripProgressProvider.notifier).clearCache();

            // Navigate back to pickup screen after successful pickup
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        );
      },
    );
  }

  void _showPhaseCompletionMessage({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    final themeState = ref.read(themeProvider);
    final isDarkMode = themeState.isDarkMode;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? AppColors.dmCardColor : Colors.white,
          contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 24.0),
          title: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style:
                      (isDarkMode
                              ? AppTypography.dmHeading(context)
                              : AppTypography.heading(context))
                          .copyWith(fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              message,
              style: isDarkMode
                  ? AppTypography.dmBodyText(context)
                  : AppTypography.bodyText(context),
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                ),
                child: Text(tr('common.ok')),
              ),
            ),
          ],
        );
      },
    );
  }

  // Helper method to send native notifications with error handling
  Future<void> _sendNativeNotification({
    required String title,
    required String body,
    required bool isPhase1,
  }) async {
    try {
      if (isPhase1) {
        // Show Phase 1 notification (pickup)
        await BackgroundMonitoringService.instance.showPickupPhaseNotification(
          tripId: widget.tripCode,
          title: title,
          body: body,
        );
      } else {
        // Show Phase 2 notification (delivery)
        await BackgroundMonitoringService.instance
            .showDeliveryPhaseNotification(
              tripId: widget.tripCode,
              title: title,
              body: body,
            );
      }
      print('TripProgress: Native notification sent successfully');
    } catch (e) {
      print('TripProgress: Failed to send native notification: $e');
      print('TripProgress: Falling back to in-app dialog only');
      // Continue without native notification - in-app dialog will still show
    }
  }

  // Stop background monitoring
  Future<void> _stopBackgroundMonitoring() async {
    try {
      await BackgroundService.stopMqttMonitoring();
      print('TripProgress: Background monitoring stopped');

      // Also update BackgroundMonitoringService state
      BackgroundMonitoringService.instance.markDeliveryQRScanned(
        widget.tripCode,
      );
    } catch (e) {
      print('TripProgress: Failed to stop background monitoring: $e');
    }
  }

  @override
  void dispose() {
    // Remove app lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    _activityTimer?.cancel(); // Cancel activity timer
    _robotAnimationController.dispose();

    // Clear MQTT connection flag
    TripStorageService().clearMqttConnectionFlag();

    // Unsubscribe from our specific topic, but DON'T disconnect the MQTT client
    _cleanupMqttSubscription();

    // Instead of replacing the callback, simply note that we're leaving
    print('TripProgress: Screen disposed, MQTT connection remains active');

    super.dispose();
  }

  /// Clean up MQTT subscription
  Future<void> _cleanupMqttSubscription() async {
    try {
      // Note: We keep the subscription active for global handling
      // but we mark it as no longer being processed by this UI
      final topic = 'robot/${widget.robotCode}/trip/${widget.tripCode}';
      print('TripProgress: No longer processing messages for topic: $topic');

      // The MQTT subscription service will continue to track messages
      // but we're removing our specific UI callback
      MqttSubscriptionService.instance.onTripProgressUpdate = null;
    } catch (e) {
      print('TripProgress: Error in _cleanupMqttSubscription: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        print('TripProgress: App resumed - syncing trip progress');
        _onAppResumed();
        break;
      case AppLifecycleState.paused:
        print('TripProgress: App paused - enabling background monitoring');
        _onAppPaused();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        print('TripProgress: App inactive/detached');
        break;
      case AppLifecycleState.hidden:
        print('TripProgress: App hidden');
        break;
    }
  }

  /// Handle app resuming from background
  Future<void> _onAppResumed() async {
    try {
      // Update app activity timestamp
      await TripStorageService().updateAppActivityTimestamp();

      // Re-initialize the provider to load any cached progress that might have been updated in background
      await ref.read(_tripProgressProvider.notifier).initialize();

      // Reconnect MQTT if needed
      await _initializeMqttAndSubscribe();

      // Refresh trip details
      await _fetchTripDetails();

      print('TripProgress: App resume sync completed');
    } catch (e) {
      print('TripProgress: Error during app resume sync: $e');
    }
  }

  /// Handle app going to background
  Future<void> _onAppPaused() async {
    try {
      // Clear MQTT connection flag to allow background service to take over
      await TripStorageService().clearMqttConnectionFlag();

      // Ensure background monitoring is registered
      await BackgroundMonitoringService.instance.registerMonitoring(
        robotId: widget.robotCode,
        orderId: widget.orderCode,
        tripId: widget.tripCode,
      );

      print('TripProgress: App pause handling completed');
    } catch (e) {
      print('TripProgress: Error during app pause handling: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final isDarkMode = themeState.isDarkMode;

    // Watch the trip progress state
    final tripProgressState = ref.watch(_tripProgressProvider);

    return Scaffold(
      backgroundColor: isDarkMode
          ? AppColors.dmBackgroundColor
          : AppColors.backgroundColor,
      appBar: AppBar(
        title: Text(
          tr('pickup.trip_progress.title'),
          style: isDarkMode
              ? AppTypography.dmHeading(
                  context,
                ).copyWith(fontWeight: FontWeight.w500)
              : AppTypography.heading(
                  context,
                ).copyWith(fontWeight: FontWeight.w500),
        ),
        backgroundColor: isDarkMode ? AppColors.dmCardColor : Colors.white,
        foregroundColor: isDarkMode
            ? AppColors.dmDefaultColor
            : AppColors.defaultColor,
        elevation: 2,
      ),
      body: _buildBody(isDarkMode, tripProgressState),
    );
  }

  Widget _buildBody(bool isDarkMode, TripProgressState tripProgressState) {
    if (_isLoading || tripProgressState is TripProgressLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              tr('pickup.trip_progress.loading'),
              style: isDarkMode
                  ? AppTypography.dmBodyText(context)
                  : AppTypography.bodyText(context),
            ),
          ],
        ),
      );
    }

    if (_hasError || tripProgressState is TripProgressError) {
      final errorMessage = tripProgressState is TripProgressError
          ? tripProgressState.errorMessage
          : (_errorMessage ?? tr('pickup.trip_progress.error'));

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.withOpacity(0.7),
              ),
              const SizedBox(height: 16),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style:
                    (isDarkMode
                            ? AppTypography.dmSubTitleText(context)
                            : AppTypography.subTitleText(context))
                        .copyWith(color: Colors.red),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      setState(() {
                        _isLoading = true;
                        _hasError = false;
                      });

                      // Try to initialize MQTT connection properly
                      print(
                        'TripProgress: Attempting MQTT initialization and reconnection...',
                      );

                      _fetchTripDetails();
                      await _initializeMqttAndSubscribe();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.buttonColor,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(tr('pickup.trip_progress.retry')),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () async {
                      print('TripProgress: Running comprehensive debug...');

                      // Test network connectivity first
                      final networkOk =
                          await MqttService.testNetworkConnectivity();
                      print('TripProgress: Network test result: $networkOk');

                      // Show debug info in a dialog
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              networkOk
                                  ? 'Network OK - Check console for debug info'
                                  : 'Network FAILED - MQTT broker unreachable',
                            ),
                            duration: const Duration(seconds: 3),
                            backgroundColor: networkOk
                                ? Colors.green
                                : Colors.red,
                          ),
                        );
                      }
                    },
                    child: const Text('Debug'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Get progress data from the state
    final progressData = _getProgressData(tripProgressState);

    // Safely extract progress (should already be double from provider)
    double progress = 0.0;
    final progressValue = progressData['progress'];
    if (progressValue is num) {
      progress = progressValue.toDouble();
    }

    final tripStartPoint = progressData['tripStartPoint'] as String?;
    final tripEndPoint = progressData['tripEndPoint'] as String?;
    final awaitingPhase1QR = progressData['awaitingPhase1QR'] as bool;
    final awaitingPhase2QR = progressData['awaitingPhase2QR'] as bool;
    final phase1QRScanned = progressData['phase1QRScanned'] as bool;
    final phase2QRScanned = progressData['phase2QRScanned'] as bool;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Trip information card
          Card(
            color: isDarkMode ? AppColors.dmCardColor : Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.receipt_long,
                        color: isDarkMode
                            ? AppColors.dmButtonColor
                            : AppColors.buttonColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${tr('pickup.order_code')}: ${widget.orderCode}',
                        style:
                            (isDarkMode
                                    ? AppTypography.dmSubTitleText(context)
                                    : AppTypography.subTitleText(context))
                                .copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.route,
                        color: isDarkMode
                            ? AppColors.dmButtonColor
                            : AppColors.buttonColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${tr('pickup.trip_code')}: ${widget.tripCode}',
                        style: isDarkMode
                            ? AppTypography.dmBodyText(context)
                            : AppTypography.bodyText(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),

          // Progress visualization
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Phase labels above progress bar
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr('pickup.trip_progress.phase_pickup'),
                        textAlign: TextAlign.center,
                        style:
                            (isDarkMode
                                    ? AppTypography.dmBodyText(context)
                                    : AppTypography.bodyText(context))
                                .copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: progress >= 0.5
                                      ? (isDarkMode
                                            ? Colors.grey[600]
                                            : Colors.grey[500])
                                      : (isDarkMode
                                            ? AppColors.dmButtonColor
                                            : AppColors.buttonColor),
                                ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        tr('pickup.trip_progress.phase_delivery'),
                        textAlign: TextAlign.center,
                        style:
                            (isDarkMode
                                    ? AppTypography.dmBodyText(context)
                                    : AppTypography.bodyText(context))
                                .copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: progress < 0.5
                                      ? (isDarkMode
                                            ? Colors.grey[600]
                                            : Colors.grey[500])
                                      : (isDarkMode
                                            ? AppColors.dmButtonColor
                                            : AppColors.buttonColor),
                                ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Progress bar with robot positioned on top
                Container(
                  height: 80, // Reserve space for robot (40px above bar)
                  child: Stack(
                    children: [
                      // Progress bar positioned in the middle
                      Positioned(
                        bottom:
                            30, // Position bar 30px from bottom to center it
                        left: 0,
                        right: 0,
                        child: Stack(
                          children: [
                            // Background bar
                            Container(
                              width: double.infinity,
                              height: 20,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDarkMode
                                      ? Colors.grey[600]!
                                      : Colors.grey[300]!,
                                  width: 2,
                                ),
                                color: isDarkMode
                                    ? Colors.grey[800]
                                    : Colors.grey[100],
                              ),
                            ),

                            // Phase 1 progress (pickup phase)
                            Positioned(
                              left: 0,
                              top: 0,
                              child: Container(
                                width:
                                    (MediaQuery.of(context).size.width - 48) *
                                    0.5 *
                                    (progress <= 0.5 ? progress * 2 : 1.0),
                                height: 20,
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    bottomLeft: Radius.circular(8),
                                  ),
                                  color: progress > 0
                                      ? (isDarkMode
                                            ? AppColors.dmButtonColor
                                            : AppColors.buttonColor)
                                      : Colors.transparent,
                                ),
                              ),
                            ),

                            // Phase 2 progress (delivery phase)
                            if (progress > 0.5)
                              Positioned(
                                left:
                                    (MediaQuery.of(context).size.width - 48) *
                                    0.5,
                                top: 0,
                                child: Container(
                                  width:
                                      (MediaQuery.of(context).size.width - 48) *
                                      0.5 *
                                      ((progress - 0.5) * 2),
                                  height: 20,
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(8),
                                      bottomRight: Radius.circular(8),
                                    ),
                                    color: isDarkMode
                                        ? AppColors.dmSuccessColor
                                        : AppColors.successColor,
                                  ),
                                ),
                              ),

                            // Midpoint marker
                            Positioned(
                              left:
                                  (MediaQuery.of(context).size.width - 48) *
                                      0.5 -
                                  1,
                              top: 0,
                              child: Container(
                                width: 2,
                                height: 20,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Robot positioned on top of the progress bar
                      Positioned(
                        bottom: 0, // Robot sits on the bar
                        left:
                            progress *
                            (MediaQuery.of(context).size.width - 48 - 80),
                        child: AnimatedBuilder(
                          animation: _robotAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, _robotAnimation.value * 3),
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDarkMode
                                      ? Colors.grey[700]
                                      : Colors.grey[200],
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    '🤖', // Robot emoji
                                    style: TextStyle(fontSize: 24),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Start and end point labels below progress bar
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tripStartPoint ??
                            tr('pickup.trip_progress.start_point'),
                        textAlign: TextAlign.center,
                        style:
                            (isDarkMode
                                    ? AppTypography.dmBodyText(context)
                                    : AppTypography.bodyText(context))
                                .copyWith(
                                  fontSize: 10,
                                  color: isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        tripEndPoint ?? tr('pickup.trip_progress.end_point'),
                        textAlign: TextAlign.center,
                        style:
                            (isDarkMode
                                    ? AppTypography.dmBodyText(context)
                                    : AppTypography.bodyText(context))
                                .copyWith(
                                  fontSize: 10,
                                  color: isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Progress percentage
                Text(
                  '${(progress * 100).toStringAsFixed(1)}%',
                  style:
                      (isDarkMode
                              ? AppTypography.dmHeading(context)
                              : AppTypography.heading(context))
                          .copyWith(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? AppColors.dmSuccessColor
                                : AppColors.successColor,
                          ),
                ),

                const SizedBox(height: 8),

                Text(
                  tr('pickup.trip_progress.progress_label'),
                  style: isDarkMode
                      ? AppTypography.dmBodyText(
                          context,
                        ).copyWith(color: Colors.grey[400])
                      : AppTypography.bodyText(
                          context,
                        ).copyWith(color: Colors.grey[600]),
                ),

                const SizedBox(height: 40),

                // Status message
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        (isDarkMode
                                ? AppColors.dmSuccessColor
                                : AppColors.successColor)
                            .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          (isDarkMode
                                  ? AppColors.dmSuccessColor
                                  : AppColors.successColor)
                              .withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        progress >= 1.0
                            ? Icons.check_circle
                            : progress >= 0.5
                            ? Icons.local_shipping
                            : Icons.route,
                        color: isDarkMode
                            ? AppColors.dmSuccessColor
                            : AppColors.successColor,
                        size: 28,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        progress >= 1.0
                            ? tr('pickup.trip_progress.completed')
                            : progress >= 0.5
                            ? tr('pickup.trip_progress.delivery_phase')
                            : progress > 0
                            ? tr('pickup.trip_progress.pickup_phase')
                            : tr('pickup.trip_progress.waiting'),
                        textAlign: TextAlign.center,
                        style:
                            (isDarkMode
                                    ? AppTypography.dmBodyText(context)
                                    : AppTypography.bodyText(context))
                                .copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode
                                      ? AppColors.dmSuccessColor
                                      : AppColors.successColor,
                                ),
                      ),

                      // Show phase-specific action buttons
                      if (awaitingPhase1QR && !phase1QRScanned) ...[
                        // Phase 1: Sender needs to scan QR to open container at pickup
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _handlePhase1QRScan,
                            icon: const Icon(Icons.qr_code_scanner, size: 18),
                            label: Text(
                              tr('pickup.trip_progress.scan_to_open'),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr('pickup.trip_progress.phase1_instruction'),
                          textAlign: TextAlign.center,
                          style: isDarkMode
                              ? AppTypography.dmBodyText(context).copyWith(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                )
                              : AppTypography.bodyText(context).copyWith(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                        ),
                      ] else if (awaitingPhase2QR && !phase2QRScanned) ...[
                        // Phase 2: Receiver needs to scan QR to receive order
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _handleReceiveOrder,
                            icon: const Icon(Icons.qr_code_scanner, size: 18),
                            label: Text(tr('pickup.receive_order')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr('pickup.trip_progress.phase2_instruction'),
                          textAlign: TextAlign.center,
                          style: isDarkMode
                              ? AppTypography.dmBodyText(context).copyWith(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                )
                              : AppTypography.bodyText(context).copyWith(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                        ),
                      ] else if (phase1QRScanned && phase2QRScanned) ...[
                        // Both phases completed
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                tr('pickup.trip_progress.all_phases_complete'),
                                style: isDarkMode
                                    ? AppTypography.dmBodyText(
                                        context,
                                      ).copyWith(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w600,
                                      )
                                    : AppTypography.bodyText(context).copyWith(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w600,
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to get progress data from the current state
  Map<String, dynamic> _getProgressData(TripProgressState state) {
    if (state is TripProgressLoaded) {
      return {
        'progress': state.progress,
        'tripStartPoint': state.tripStartPoint,
        'tripEndPoint': state.tripEndPoint,
        'hasPickupPhase': state.hasPickupPhase,
        'hasDeliveryPhase': state.hasDeliveryPhase,
        'phase1QRScanned': state.phase1QRScanned,
        'phase2QRScanned': state.phase2QRScanned,
        'phase1NotificationSent': state.phase1NotificationSent,
        'phase2NotificationSent': state.phase2NotificationSent,
        'awaitingPhase1QR': state.awaitingPhase1QR,
        'awaitingPhase2QR': state.awaitingPhase2QR,
      };
    }
    // Return default values for non-loaded states
    return {
      'progress': 0.0,
      'tripStartPoint': null,
      'tripEndPoint': null,
      'hasPickupPhase': false,
      'hasDeliveryPhase': false,
      'phase1QRScanned': false,
      'phase2QRScanned': false,
      'phase1NotificationSent': false,
      'phase2NotificationSent': false,
      'awaitingPhase1QR': false,
      'awaitingPhase2QR': false,
    };
  }
}
