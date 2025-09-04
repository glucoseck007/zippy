// Simple verification script to test notification deduplication logic
// This file is for testing purposes only

import 'package:shared_preferences/shared_preferences.dart';

class NotificationTestHelper {
  /// Test the deduplication logic for trip state notifications
  static Future<bool> testNotificationDeduplication(String tripId, int status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Use the same global key as our implementation
      final notificationKey = 'global_trip_state_notified_${tripId}_$status';
      final timestampKey = 'global_trip_state_timestamp_${tripId}_$status';
      
      // Check if already notified
      final alreadyNotified = prefs.getBool(notificationKey) ?? false;
      if (alreadyNotified) {
        print('Test: Notification already sent for trip $tripId status $status');
        return false; // Should not send
      }
      
      // Check timestamp rate limiting
      final lastNotificationTime = prefs.getInt(timestampKey) ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final timeSinceLastNotification = currentTime - lastNotificationTime;
      
      if (timeSinceLastNotification < 10000) {
        print('Test: Notification rate limited for trip $tripId status $status');
        return false; // Should not send
      }
      
      // Mark as sent (simulate notification sending)
      await prefs.setBool(notificationKey, true);
      await prefs.setInt(timestampKey, currentTime);
      
      print('Test: Notification would be sent for trip $tripId status $status');
      return true; // Should send
      
    } catch (e) {
      print('Test: Error in deduplication test: $e');
      return false;
    }
  }
  
  /// Clear test data
  static Future<void> clearTestData() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    
    // Remove all test notification keys
    for (final key in keys) {
      if (key.startsWith('global_trip_state_')) {
        await prefs.remove(key);
      }
    }
    
    print('Test: Cleared all test notification data');
  }
}
