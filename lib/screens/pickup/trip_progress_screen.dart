import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design/app_colors.dart';
import '../../design/app_typography.dart';
import '../../providers/core/theme_provider.dart';
import '../../services/api_client.dart';
import '../../services/mqtt/mqtt_service.dart';
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
  double _progress = 0.0;
  Timer? _progressTimer;
  Timer? _activityTimer; // Timer to update app activity timestamp
  String? _tripStartPoint;
  String? _tripEndPoint;
  bool _hasPickupPhase = false; // Track if we've seen pickup phase data
  bool _hasDeliveryPhase = false; // Track if we've seen delivery phase data

  // Phase tracking for QR verification
  bool _phase1QRScanned = false; // Sender scan at pickup location
  bool _phase2QRScanned = false; // Receiver scan at delivery location
  bool _phase1NotificationSent =
      false; // Track if notification sent for phase 1
  bool _phase2NotificationSent =
      false; // Track if notification sent for phase 2
  bool _awaitingPhase1QR = false; // Robot reached pickup, waiting for sender QR
  bool _awaitingPhase2QR =
      false; // Robot reached delivery, waiting for receiver QR

  // Robot animation
  late AnimationController _robotAnimationController;
  late Animation<double> _robotAnimation;

  @override
  @override
  void initState() {
    super.initState();

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

    // Initialize services
    _initializeServices();

    // Load cached trip progress first, then fetch fresh data
    _loadCachedTripProgress();

    _fetchTripDetails();

    // Initialize MQTT connection and then set up subscription
    _initializeMqttAndSubscribe();
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
      print(
        'TripProgress: Fetching trip details for tripCode: ${widget.tripCode}',
      );
      final response = await ApiClient.get('/trip/details/${widget.tripCode}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (mounted) {
          setState(() {
            if (jsonData['success'] == true && jsonData['data'] != null) {
              final data = jsonData['data'];
              _tripStartPoint = data['startPoint'] as String?;
              _tripEndPoint = data['endPoint'] as String?;
              print(
                'TripProgress: Trip details loaded - Start: $_tripStartPoint, End: $_tripEndPoint',
              );
            }
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to fetch trip details');
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

      // Debug the MQTT connection
      print('Subscribed Topics: ${MqttService.subscribedTopics}');
      print(
        'Is subscribed to our topic: ${MqttService.isSubscribedTo('robot/${widget.robotCode}/trip/${widget.tripCode}')}',
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
          _handleMqttMessage(cachedData);
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

  // Debug method to test MQTT subscription
  Future<void> _debugMqttStatus() async {
    print('=== Trip Progress MQTT Debug ===');
    print('Trip Code: ${widget.tripCode}');
    print('Robot Code: ${widget.robotCode}');
    print('Order Code: ${widget.orderCode}');
    print('Expected Topic: robot/${widget.robotCode}/trip/${widget.tripCode}');
    print('Subscribed Topics: ${MqttService.subscribedTopics}');
    print(
      'Is subscribed to our topic: ${MqttService.isSubscribedTo('robot/${widget.robotCode}/trip/${widget.tripCode}')}',
    );

    // Get detailed MQTT service debug info
    final debugInfo = await MqttService.debugConnection();
    print('MQTT Service Debug: $debugInfo');

    print('================================');
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

    try {
      final progress = (data['progress'] as num?)?.toDouble();
      final payloadStartPoint = data['start_point'] as String?;
      final payloadEndPoint = data['end_point'] as String?;

      if (progress == null) {
        print('TripProgress: Missing progress field in MQTT message: $data');
        return;
      }

      // Always store incoming progress updates immediately in local storage
      // This ensures we capture the data even if trip details aren't loaded yet
      _storeRawProgressUpdate(data);

      // If start/end points are missing, try to use cached values
      final startPoint = payloadStartPoint ?? _tripStartPoint;
      final endPoint = payloadEndPoint ?? _tripEndPoint;

      // For messages missing start/end points, we'll still update the progress bar
      if (startPoint == null || endPoint == null) {
        // Simple progress update without phase calculation
        if (mounted) {
          setState(() {
            // Check if progress is already a percentage (>1) or a decimal fraction
            _progress = progress > 1 ? progress / 100.0 : progress;
            print(
              'TripProgress: Simple progress update: ${(_progress * 100).toStringAsFixed(1)}%',
            );
            // Save progress to cache after updating state
            _saveTripProgress();

            // Since we have a progress update, try to fetch trip details if they're missing
            if (_tripStartPoint == null || _tripEndPoint == null) {
              print(
                'TripProgress: Got progress update before trip details, fetching details now',
              );
              _fetchTripDetails();
            }
          });
        }
        return;
      }

      if (mounted && _tripStartPoint != null && _tripEndPoint != null) {
        setState(() {
          // UPDATED LOGIC FOR TWO-PHASE VERIFICATION:

          if (payloadEndPoint == _tripStartPoint) {
            // Phase 1: Robot going to pickup location
            // The robot is heading TO the pickup point (trip's start point)
            // Check if progress is already a percentage (>1) or a decimal fraction
            _progress =
                (progress > 1 ? progress / 100.0 : progress) *
                0.5; // Map 0-100% to 0-50% of total bar
            _hasPickupPhase = true;

            print('TripProgress: Phase 1 - Robot going to pickup location');
            print(
              'TripProgress: Payload end_point ($payloadEndPoint) == trip startPoint ($_tripStartPoint)',
            );
            print(
              'TripProgress: Progress mapped to first half: ${(_progress * 100).toStringAsFixed(1)}%',
            );

            // Check if robot has reached pickup location (100% progress of phase 1)
            if (progress >= 100.0 && !_phase1NotificationSent) {
              _awaitingPhase1QR = true;
              _phase1NotificationSent = true;
              _showPhase1Notification();
              print(
                'TripProgress: Phase 1 complete - Robot reached pickup location, awaiting sender QR scan',
              );
            }
          } else if (payloadStartPoint == _tripStartPoint) {
            // Check if this is the FIRST message with start_point == trip startPoint
            // This indicates Phase 1 is complete and Phase 2 is starting
            if (!_hasDeliveryPhase && !_phase1NotificationSent) {
              // This is the initial Phase 2 message - Phase 1 was completed instantly
              _awaitingPhase1QR = true;
              _phase1NotificationSent = true;
              _showPhase1Notification();
              print(
                'TripProgress: Phase 1 completed instantly - Robot at pickup, awaiting sender QR scan',
              );
            }

            // Phase 2: Robot going from pickup to delivery location
            // The robot is departing FROM the pickup point (trip's start point)
            if (_hasPickupPhase || _phase1QRScanned) {
              // We've seen pickup phase or QR was scanned, so delivery is second half
              // Check if progress is already a percentage (>1) or a decimal fraction
              _progress =
                  0.5 +
                  (((progress > 1 ? progress / 100.0 : progress)) *
                      0.5); // Map 0-100% to 50-100% of total bar
              print(
                'TripProgress: Phase 2 - Robot going from pickup to delivery (after pickup phase)',
              );
              print(
                'TripProgress: Progress mapped to second half: ${(_progress * 100).toStringAsFixed(1)}%',
              );
            } else {
              // Direct delivery without pickup phase visible
              // Check if progress is already a percentage (>1) or a decimal fraction
              _progress = progress > 1
                  ? progress / 100.0
                  : progress; // Map 0-100% to 0-100% of total bar
              print(
                'TripProgress: Phase 2 - Direct delivery (no pickup phase seen)',
              );
              print(
                'TripProgress: Progress mapped to full bar: ${(_progress * 100).toStringAsFixed(1)}%',
              );
            }

            _hasDeliveryPhase = true;

            // Check if robot has reached delivery location (100% progress of phase 2)
            if (progress >= 100.0 && !_phase2NotificationSent) {
              _awaitingPhase2QR = true;
              _phase2NotificationSent = true;
              _showPhase2Notification();
              print(
                'TripProgress: Phase 2 complete - Robot reached delivery location, awaiting receiver QR scan',
              );
            }

            print(
              'TripProgress: Payload start_point ($payloadStartPoint) == trip startPoint ($_tripStartPoint)',
            );
          } else {
            print('TripProgress: No phase match found - ignoring message');
            print(
              'TripProgress: Payload start: $payloadStartPoint, end: $payloadEndPoint',
            );
            print(
              'TripProgress: Trip start: $_tripStartPoint, end: $_tripEndPoint',
            );
            return;
          }

          print(
            'TripProgress: Final progress: ${(_progress * 100).toStringAsFixed(1)}%',
          );
          print(
            'TripProgress: Has pickup phase: $_hasPickupPhase, Has delivery phase: $_hasDeliveryPhase',
          );
          print(
            'TripProgress: Awaiting Phase 1 QR: $_awaitingPhase1QR, Awaiting Phase 2 QR: $_awaitingPhase2QR',
          );

          // Save progress to cache after updating state
          _saveTripProgress();
        });
      } else {
        print(
          'TripProgress: Trip details not loaded yet - skipping progress update',
        );
      }
    } catch (e) {
      print('TripProgress: Error handling MQTT message: $e');
    }
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
    // For now, just mark as scanned
    setState(() {
      _phase1QRScanned = true;
      _awaitingPhase1QR = false;
    });

    // Update state in background monitoring service
    BackgroundMonitoringService.instance.markPickupQRScanned(widget.tripCode);

    // Save updated state to cache
    _saveTripProgress();

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
            setState(() {
              _phase2QRScanned = true;
              _awaitingPhase2QR = false;
            });

            // Update state in background monitoring service
            BackgroundMonitoringService.instance.markDeliveryQRScanned(
              widget.tripCode,
            );

            // Save final state to cache
            _saveTripProgress();

            // Stop background monitoring since delivery is complete
            _stopBackgroundMonitoring();

            // Clear the cached progress since pickup is complete
            _clearTripProgressCache();

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

  // Load cached trip progress from local storage

  Future<void> _loadCachedTripProgress() async {
    try {
      print(
        'TripProgress: Loading cached trip progress for ${widget.tripCode}',
      );

      // Use TripStorageService to load cached progress
      final tripData = await TripStorageService().loadCachedTripProgress(
        widget.tripCode,
        robotCode: widget
            .robotCode, // Pass the robot code to find the correct cached data
      );

      if (tripData != null) {
        if (mounted) {
          setState(() {
            // Update progress
            final progress = tripData['progress'] as double?;
            if (progress != null) {
              _progress = progress;
            }

            // Update phase tracking
            _hasPickupPhase = tripData['hasPickupPhase'] as bool? ?? false;
            _hasDeliveryPhase = tripData['hasDeliveryPhase'] as bool? ?? false;
            _phase1QRScanned = tripData['phase1QRScanned'] as bool? ?? false;
            _phase2QRScanned = tripData['phase2QRScanned'] as bool? ?? false;
            _phase1NotificationSent =
                tripData['phase1NotificationSent'] as bool? ?? false;
            _phase2NotificationSent =
                tripData['phase2NotificationSent'] as bool? ?? false;
            _awaitingPhase1QR = tripData['awaitingPhase1QR'] as bool? ?? false;
            _awaitingPhase2QR = tripData['awaitingPhase2QR'] as bool? ?? false;

            // Check for trip endpoint data
            if (tripData['start_point'] != null) {
              _tripStartPoint = tripData['start_point'] as String;
            }
            if (tripData['end_point'] != null) {
              _tripEndPoint = tripData['end_point'] as String;
            }

            // Set loading to false since we have data
            _isLoading = false;

            print(
              'TripProgress: Loaded cached progress: ${(_progress * 100).toStringAsFixed(1)}%',
            );
            print(
              'TripProgress: Pickup phase: $_hasPickupPhase, Delivery phase: $_hasDeliveryPhase',
            );
            print(
              'TripProgress: Phase1 QR: $_phase1QRScanned, Phase2 QR: $_phase2QRScanned',
            );
          });

          // Update BackgroundMonitoringService state
          BackgroundMonitoringService.instance.loadStateFromProgress(
            widget.tripCode,
            tripData,
          );
        }
      } else {
        print('TripProgress: No cached progress data found');
      }

      // Regardless of cache state, try to fetch trip details for the latest data
      if (_tripStartPoint == null || _tripEndPoint == null) {
        _fetchTripDetails();
      }
    } catch (e) {
      print('TripProgress: Error loading cached progress: $e');
    }
  }

  // Save current trip progress to local storage
  Future<void> _saveTripProgress() async {
    try {
      await TripStorageService().saveTripProgress(
        tripCode: widget.tripCode,
        orderCode: widget.orderCode,
        robotCode: widget.robotCode,
        progress: _progress,
        hasPickupPhase: _hasPickupPhase,
        hasDeliveryPhase: _hasDeliveryPhase,
        phase1QRScanned: _phase1QRScanned,
        phase2QRScanned: _phase2QRScanned,
        phase1NotificationSent: _phase1NotificationSent,
        phase2NotificationSent: _phase2NotificationSent,
        awaitingPhase1QR: _awaitingPhase1QR,
        awaitingPhase2QR: _awaitingPhase2QR,
      );

      print(
        'TripProgress: Saved progress to cache - Progress: ${(_progress * 100).toStringAsFixed(1)}%',
      );

      // Also update the background monitoring service state
      final tripState = BackgroundMonitoringService.instance.getTripState(
        widget.tripCode,
      );
      print('TripProgress: Current background monitoring state: $tripState');
    } catch (e) {
      print('TripProgress: Error saving progress to cache: $e');
    }
  }

  // Clear cached trip progress (call when pickup is completed)
  Future<void> _clearTripProgressCache() async {
    try {
      await TripStorageService().clearTripProgressCache(widget.tripCode);
      print('TripProgress: Cleared cached progress data');
    } catch (e) {
      print('TripProgress: Error clearing cached progress: $e');
    }
  }

  // Store raw progress update in local storage for persistence across app lifecycle
  Future<void> _storeRawProgressUpdate(Map<String, dynamic> data) async {
    try {
      await TripStorageService().storeRawProgressUpdate(
        robotCode: widget.robotCode,
        tripCode: widget.tripCode,
        data: data,
      );

      print('TripProgress: Stored raw progress update');
    } catch (e) {
      print('TripProgress: Error storing raw progress update: $e');
    }
  }

  @override
  void dispose() {
    // Remove app lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    _progressTimer?.cancel();
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

      // Load any cached progress that might have been updated in background
      await _loadCachedTripProgress();

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
        actions: [
          // Debug button to check MQTT status
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: _debugMqttStatus,
            tooltip: 'Debug MQTT Status',
          ),
        ],
      ),
      body: _buildBody(isDarkMode),
    );
  }

  Widget _buildBody(bool isDarkMode) {
    if (_isLoading) {
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

    if (_hasError) {
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
                _errorMessage ?? tr('pickup.trip_progress.error'),
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

                      // Run debug first
                      await _debugMqttStatus();

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

                      await _debugMqttStatus();

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
                                  color: _progress >= 0.5
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
                                  color: _progress < 0.5
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
                                    (_progress <= 0.5 ? _progress * 2 : 1.0),
                                height: 20,
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    bottomLeft: Radius.circular(8),
                                  ),
                                  color: _progress > 0
                                      ? (isDarkMode
                                            ? AppColors.dmButtonColor
                                            : AppColors.buttonColor)
                                      : Colors.transparent,
                                ),
                              ),
                            ),

                            // Phase 2 progress (delivery phase)
                            if (_progress > 0.5)
                              Positioned(
                                left:
                                    (MediaQuery.of(context).size.width - 48) *
                                    0.5,
                                top: 0,
                                child: Container(
                                  width:
                                      (MediaQuery.of(context).size.width - 48) *
                                      0.5 *
                                      ((_progress - 0.5) * 2),
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
                            _progress *
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
                        _tripStartPoint ??
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
                        _tripEndPoint ?? tr('pickup.trip_progress.end_point'),
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
                  '${(_progress * 100).toStringAsFixed(1)}%',
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
                        _progress >= 1.0
                            ? Icons.check_circle
                            : _progress >= 0.5
                            ? Icons.local_shipping
                            : Icons.route,
                        color: isDarkMode
                            ? AppColors.dmSuccessColor
                            : AppColors.successColor,
                        size: 28,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _progress >= 1.0
                            ? tr('pickup.trip_progress.completed')
                            : _progress >= 0.5
                            ? tr('pickup.trip_progress.delivery_phase')
                            : _progress > 0
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
                      if (_awaitingPhase1QR && !_phase1QRScanned) ...[
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
                      ] else if (_awaitingPhase2QR && !_phase2QRScanned) ...[
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
                      ] else if (_phase1QRScanned && _phase2QRScanned) ...[
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
}
