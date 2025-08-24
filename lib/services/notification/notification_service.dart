import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'zippy_delivery_channel',
    'Zippy Delivery Notifications',
    description: 'Notifications for delivery robot status updates',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize the plugin
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsDarwin,
            macOS: initializationSettingsDarwin,
          );

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channel for Android
      if (Platform.isAndroid) {
        await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(_channel);
      }

      // Request permissions
      await _requestPermissions();

      _isInitialized = true;
      print('NotificationService: Initialized successfully');
    } catch (e) {
      print('NotificationService: Initialization failed: $e');
      print(
        'NotificationService: This might be due to missing native implementation',
      );
      print(
        'NotificationService: Please restart the app after adding the plugin',
      );
      // Don't mark as initialized if it failed
      _isInitialized = false;
      rethrow; // Re-throw to let calling code handle the error
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isIOS || Platform.isMacOS) {
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      await androidImplementation?.requestNotificationsPermission();
    }
  }

  void _onNotificationTapped(NotificationResponse notificationResponse) {
    final String? payload = notificationResponse.payload;
    print('NotificationService: Notification tapped with payload: $payload');

    // Handle notification tap - can be used to navigate to specific screens
    // For now, just log the action
  }

  Future<void> showPhase1Notification({
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) {
      print('NotificationService: Not initialized, initializing now...');
      await initialize();
    }

    const NotificationDetails notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'zippy_delivery_channel',
        'Zippy Delivery Notifications',
        channelDescription: 'Notifications for delivery robot status updates',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      ),
    );

    try {
      await _flutterLocalNotificationsPlugin.show(
        1, // Notification ID for phase 1
        title,
        body,
        notificationDetails,
        payload: 'phase1_pickup',
      );
      print('NotificationService: Phase 1 notification sent successfully');
    } catch (e) {
      print('NotificationService: Error sending Phase 1 notification: $e');
    }
  }

  Future<void> showPhase2Notification({
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) {
      print('NotificationService: Not initialized, initializing now...');
      await initialize();
    }

    const NotificationDetails notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'zippy_delivery_channel',
        'Zippy Delivery Notifications',
        channelDescription: 'Notifications for delivery robot status updates',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      ),
    );

    try {
      await _flutterLocalNotificationsPlugin.show(
        2, // Notification ID for phase 2
        title,
        body,
        notificationDetails,
        payload: 'phase2_delivery',
      );
      print('NotificationService: Phase 2 notification sent successfully');
    } catch (e) {
      print('NotificationService: Error sending Phase 2 notification: $e');
    }
  }

  Future<void> showProgressNotification({
    required String title,
    required String body,
    double? progress,
  }) async {
    if (!_isInitialized) {
      print('NotificationService: Not initialized, initializing now...');
      await initialize();
    }

    // Generate unique ID based on current time to prevent notification replacement
    final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(10000);

    try {
      if (Platform.isAndroid) {
        // For Android, we can show progress in the notification
        final androidDetails = AndroidNotificationDetails(
          'zippy_delivery_channel',
          'Zippy Delivery Notifications',
          channelDescription: 'Notifications for delivery robot status updates',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          enableVibration: true,
          playSound: true,
          onlyAlertOnce: true,
          showProgress: progress != null,
          maxProgress: 100,
          progress: progress != null ? (progress * 100).round() : 0,
        );

        final notificationDetails = NotificationDetails(android: androidDetails);

        await _flutterLocalNotificationsPlugin.show(
          notificationId,
          title,
          body,
          notificationDetails,
          payload: 'progress_update',
        );
      } else {
        // For iOS, we can't show progress bars, so just show a regular notification
        const notificationDetails = NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'default',
          ),
        );

        await _flutterLocalNotificationsPlugin.show(
          notificationId,
          title,
          body,
          notificationDetails,
          payload: 'progress_update',
        );
      }
      print('NotificationService: Progress notification sent successfully');
    } catch (e) {
      print('NotificationService: Error sending progress notification: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
    print('NotificationService: All notifications cancelled');
  }

  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
    print('NotificationService: Notification $id cancelled');
  }
}
