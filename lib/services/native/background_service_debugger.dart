import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Debug utility to check background service status and logs
class BackgroundServiceDebugger {
  /// Check if background tasks are properly registered
  static Future<Map<String, dynamic>> checkTaskRegistration() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'timestamp': DateTime.now().toIso8601String(),
      'robot_monitoring_active': prefs.getBool('is_monitoring_active') ?? false,
      'trip_monitoring_active':
          prefs.getBool('is_trip_monitoring_active') ?? false,
      'active_robot_id': prefs.getString('active_robot_id'),
      'active_trip_code': prefs.getString('active_trip_code'),
      'active_trip_robot_code': prefs.getString('active_trip_robot_code'),
      'last_app_activity': prefs.getInt('last_app_activity'),
      'mqtt_connection_active':
          prefs.getBool('mqtt_connection_active') ?? false,
      'trip_monitoring_start_time': prefs.getInt('trip_monitoring_start_time'),
    };
  }

  /// Check for any cached trip progress data
  static Future<Map<String, dynamic>> checkCachedProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();

    final cachedData = <String, dynamic>{};
    final progressKeys = allKeys
        .where((key) => key.startsWith('trip_progress_'))
        .toList();

    for (final key in progressKeys) {
      final data = prefs.getString(key);
      final timestamp = prefs.getInt('${key}_timestamp');

      if (data != null) {
        try {
          cachedData[key] = {
            'data': json.decode(data),
            'timestamp': timestamp,
            'age_minutes': timestamp != null
                ? (DateTime.now().millisecondsSinceEpoch - timestamp) /
                      (1000 * 60)
                : null,
          };
        } catch (e) {
          cachedData[key] = {'error': 'Failed to parse: $e', 'raw_data': data};
        }
      }
    }

    return {'cached_trips': cachedData, 'total_cached': cachedData.length};
  }

  /// Get background execution logs (if any)
  static Future<List<String>> getBackgroundLogs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('background_execution_log') ?? [];
  }

  /// Add a log entry for background execution
  static Future<void> logBackgroundExecution(String message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logs = prefs.getStringList('background_execution_log') ?? [];

      final timestamp = DateTime.now().toIso8601String();
      logs.add('[$timestamp] $message');

      // Keep only last 50 entries
      if (logs.length > 50) {
        logs.removeAt(0);
      }

      await prefs.setStringList('background_execution_log', logs);
    } catch (e) {
      print('BackgroundServiceDebugger: Error logging: $e');
    }
  }

  /// Clear all background logs
  static Future<void> clearLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('background_execution_log');
  }

  /// Generate a comprehensive debug report
  static Future<Map<String, dynamic>> generateDebugReport() async {
    return {
      'task_registration': await checkTaskRegistration(),
      'cached_progress': await checkCachedProgress(),
      'background_logs': await getBackgroundLogs(),
      'system_info': {
        'platform': 'Android', // Assuming Android for this test
        'current_time': DateTime.now().toIso8601String(),
        'timezone': DateTime.now().timeZoneName,
      },
    };
  }

  /// Test if background service configuration is correct
  static Future<Map<String, dynamic>> testConfiguration() async {
    final issues = <String>[];
    final warnings = <String>[];

    // Check if any monitoring is active
    final prefs = await SharedPreferences.getInstance();
    final hasRobotMonitoring = prefs.getBool('is_monitoring_active') ?? false;
    final hasTripMonitoring =
        prefs.getBool('is_trip_monitoring_active') ?? false;

    if (!hasRobotMonitoring && !hasTripMonitoring) {
      issues.add('No background monitoring is currently active');
    }

    // Check if app activity is too recent (would block background tasks)
    final lastActivity = prefs.getInt('last_app_activity') ?? 0;
    final timeSinceActivity =
        DateTime.now().millisecondsSinceEpoch - lastActivity;

    if (timeSinceActivity < 120000) {
      // Less than 2 minutes
      warnings.add(
        'App was recently active (${(timeSinceActivity / 1000).round()}s ago) - background tasks may be skipped',
      );
    }

    // Check MQTT connection flag
    final mqttActive = prefs.getBool('mqtt_connection_active') ?? false;
    if (mqttActive) {
      warnings.add(
        'MQTT connection flag is active - background tasks will be skipped',
      );
    }

    // Check for cached data
    final cachedProgress = await checkCachedProgress();
    if (cachedProgress['total_cached'] == 0) {
      warnings.add('No cached trip progress data found');
    }

    return {
      'issues': issues,
      'warnings': warnings,
      'status': issues.isEmpty ? 'OK' : 'ISSUES_FOUND',
      'recommendations': _getRecommendations(issues, warnings),
    };
  }

  static List<String> _getRecommendations(
    List<String> issues,
    List<String> warnings,
  ) {
    final recommendations = <String>[];

    if (issues.any((issue) => issue.contains('No background monitoring'))) {
      recommendations.add(
        'Register background monitoring using BackgroundService.registerTripProgressMonitoring()',
      );
    }

    if (warnings.any((warning) => warning.contains('recently active'))) {
      recommendations.add(
        'Put the app in background for at least 2 minutes to allow background tasks to run',
      );
    }

    if (warnings.any((warning) => warning.contains('MQTT connection flag'))) {
      recommendations.add(
        'Close the main app or navigate away from screens that use MQTT',
      );
    }

    if (warnings.any((warning) => warning.contains('No cached'))) {
      recommendations.add(
        'Send some MQTT messages to verify background tasks are receiving and caching data',
      );
    }

    return recommendations;
  }
}
