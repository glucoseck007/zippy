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

  /// Check for raw progress updates in SharedPreferences
  /// This provides detailed information about all stored progress data
  static Future<Map<String, dynamic>> checkRawProgressData() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();

    final rawData = <String, dynamic>{};
    final rawProgressKeys = allKeys
        .where((key) => key.startsWith('raw_progress_'))
        .toList();

    // Track unique trip codes for summary
    final uniqueTripCodes = <String>{};
    final uniqueRobotCodes = <String>{};

    for (final key in rawProgressKeys) {
      final data = prefs.getString(key);

      if (data != null) {
        try {
          final Map<String, dynamic> parsedData = json.decode(data);
          final progress = parsedData['progress'];
          final timestamp = parsedData['timestamp'] as int?;
          final storedAt = parsedData['stored_at'] as int?;
          final now = DateTime.now().millisecondsSinceEpoch;

          // Calculate age based on timestamp
          final ageMinutes = timestamp != null
              ? (now - timestamp) / (1000 * 60)
              : null;

          // Calculate storage age based on stored_at
          final storageAgeMinutes = storedAt != null
              ? (now - storedAt) / (1000 * 60)
              : null;

          // Extract trip and robot codes from the key
          // Format: raw_progress_{robotCode}_{tripCode}
          final keyParts = key.split('_');
          if (keyParts.length >= 3) {
            final robotCode = keyParts[2];
            final tripCode = keyParts[3];

            uniqueTripCodes.add(tripCode);
            uniqueRobotCodes.add(robotCode);
          }

          rawData[key] = {
            'data': parsedData,
            'progress': progress,
            'timestamp': timestamp,
            'age_minutes': ageMinutes?.toStringAsFixed(1),
            'stored_at': storedAt,
            'storage_age_minutes': storageAgeMinutes?.toStringAsFixed(1),
            'age_readable': ageMinutes != null
                ? _formatAgeReadable(ageMinutes)
                : 'unknown',
            'topic': parsedData['topic'] ?? 'unknown',
          };
        } catch (e) {
          rawData[key] = {'error': 'Failed to parse: $e', 'raw_data': data};
        }
      }
    }

    // Also check global progress tracking
    final globalProgressData = <String, dynamic>{};
    final globalProgressKeys = allKeys
        .where((key) => key.startsWith('global_progress_'))
        .toList();

    for (final key in globalProgressKeys) {
      final progress = prefs.getDouble(key);
      if (progress != null) {
        final tripCode = key.substring('global_progress_'.length);
        globalProgressData[tripCode] = progress;
        uniqueTripCodes.add(tripCode);
      }
    }

    // Check for consistency between raw data and global tracking
    final tripCodesWithBothDataTypes = <String>[];
    final tripCodesWithOnlyRawData = <String>[];
    final tripCodesWithOnlyGlobalData = <String>[];

    for (final tripCode in uniqueTripCodes) {
      final hasRaw = rawProgressKeys.any((key) => key.endsWith('_$tripCode'));
      final hasGlobal = globalProgressKeys.any(
        (key) => key == 'global_progress_$tripCode',
      );

      if (hasRaw && hasGlobal) {
        tripCodesWithBothDataTypes.add(tripCode);
      } else if (hasRaw) {
        tripCodesWithOnlyRawData.add(tripCode);
      } else if (hasGlobal) {
        tripCodesWithOnlyGlobalData.add(tripCode);
      }
    }

    return {
      'raw_progress_data': rawData,
      'total_raw_entries': rawData.length,
      'global_progress_tracking': globalProgressData,
      'total_global_entries': globalProgressData.length,
      'unique_trip_codes': uniqueTripCodes.toList(),
      'unique_robot_codes': uniqueRobotCodes.toList(),
      'unique_trip_count': uniqueTripCodes.length,
      'unique_robot_count': uniqueRobotCodes.length,
      'consistency': {
        'trips_with_both_data_types': tripCodesWithBothDataTypes,
        'trips_with_only_raw_data': tripCodesWithOnlyRawData,
        'trips_with_only_global_data': tripCodesWithOnlyGlobalData,
        'consistency_percentage': uniqueTripCodes.isEmpty
            ? 100
            : (tripCodesWithBothDataTypes.length / uniqueTripCodes.length * 100)
                  .toStringAsFixed(1),
      },
    };
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
      'raw_progress': await checkRawProgressData(),
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

  /// Format age in minutes to a readable string
  static String _formatAgeReadable(double ageMinutes) {
    if (ageMinutes < 1) {
      return 'just now (${(ageMinutes * 60).round()} seconds ago)';
    } else if (ageMinutes < 60) {
      return '${ageMinutes.round()} minutes ago';
    } else {
      final hours = (ageMinutes / 60).floor();
      final minutes = (ageMinutes % 60).round();
      return '$hours hours, $minutes minutes ago';
    }
  }

  /// Manually store a progress update (for testing)
  static Future<Map<String, dynamic>> storeProgressUpdate({
    required String robotCode,
    required String tripCode,
    required double progress,
    String? startPoint,
    String? endPoint,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;

      // Create payload similar to MQTT message
      final Map<String, dynamic> payload = {
        'progress': progress,
        'robotId': robotCode,
        'topic': 'robot/$robotCode/trip/$tripCode',
        'timestamp': now,
      };

      // Add start/end points if provided
      if (startPoint != null) {
        payload['start_point'] = startPoint;
      }
      if (endPoint != null) {
        payload['end_point'] = endPoint;
      }

      // Store raw update
      final rawUpdateKey = 'raw_progress_${robotCode}_$tripCode';
      await prefs.setString(rawUpdateKey, json.encode(payload));

      // Update global progress tracking
      final globalProgressKey = 'global_progress_$tripCode';
      final progressValue = progress > 1 ? progress / 100.0 : progress;
      await prefs.setDouble(globalProgressKey, progressValue);

      return {
        'success': true,
        'stored_at': now,
        'raw_key': rawUpdateKey,
        'global_key': globalProgressKey,
        'progress_value': progress,
        'normalized_progress': progressValue,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Track progress changes for a specific trip
  static Future<void> trackProgressChange({
    required String robotCode,
    required String tripCode,
    required double newProgress,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyKey = 'progress_history_${robotCode}_$tripCode';

      // Get existing history or create new
      List<String> history = prefs.getStringList(historyKey) ?? [];

      // Add new entry with timestamp
      final now = DateTime.now();
      final entry = '${now.toIso8601String()}: $newProgress';
      history.add(entry);

      // Limit history to last 20 entries to avoid excessive storage
      if (history.length > 20) {
        history = history.sublist(history.length - 20);
      }

      // Save history
      await prefs.setStringList(historyKey, history);

      // Log the change
      await logBackgroundExecution(
        'Progress change for $robotCode/$tripCode: $newProgress',
      );
    } catch (e) {
      print('BackgroundServiceDebugger: Error tracking progress: $e');
    }
  }

  /// Get progress history for a specific trip
  static Future<List<Map<String, dynamic>>> getProgressHistory({
    required String robotCode,
    required String tripCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final historyKey = 'progress_history_${robotCode}_$tripCode';

    final historyStrings = prefs.getStringList(historyKey) ?? [];
    final result = <Map<String, dynamic>>[];

    for (final entry in historyStrings) {
      try {
        final parts = entry.split(': ');
        if (parts.length == 2) {
          final timestamp = DateTime.parse(parts[0]);
          final progress = double.parse(parts[1]);

          result.add({
            'timestamp': timestamp.toIso8601String(),
            'progress': progress,
            'age_minutes':
                (DateTime.now().difference(timestamp).inMilliseconds /
                        (1000 * 60))
                    .toStringAsFixed(1),
          });
        }
      } catch (e) {
        result.add({'error': 'Failed to parse: $e', 'raw_entry': entry});
      }
    }

    return result;
  }

  /// Process and store MQTT payload for monitoring
  /// This should be called whenever an MQTT message is received
  /// to ensure the latest value is always stored.
  ///
  /// The method ensures only the latest message for each trip is stored:
  /// - Replaces any existing data for this trip/robot combination
  /// - Updates global progress tracking
  /// - Maintains a history of progress changes for debugging
  static Future<Map<String, dynamic>> processMqttPayload(
    Map<String, dynamic> payload,
  ) async {
    try {
      final topic = payload['topic'] as String?;
      final progress = payload['progress'] as num?;

      if (topic == null || progress == null) {
        return {
          'success': false,
          'error': 'Invalid payload - missing topic or progress',
          'payload': payload,
        };
      }

      // Extract robotCode and tripCode from topic
      // Format: robot/{robotCode}/trip/{tripCode}
      String? robotCode;
      String? tripCode;

      final parts = topic.split('/');
      if (parts.length >= 4 && parts[0] == 'robot' && parts[2] == 'trip') {
        robotCode = parts[1];
        tripCode = parts[3];
      }

      if (robotCode == null || tripCode == null) {
        return {
          'success': false,
          'error': 'Could not parse robot/trip code from topic',
          'topic': topic,
        };
      }

      // Add timestamp to payload if not present
      final enhancedPayload = {...payload};
      if (!enhancedPayload.containsKey('timestamp')) {
        enhancedPayload['timestamp'] = DateTime.now().millisecondsSinceEpoch;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      enhancedPayload['stored_at'] = now;

      // Get SharedPreferences instance
      final prefs = await SharedPreferences.getInstance();

      // Store latest data for this trip/robot combination
      // This will replace any previous data for the same trip/robot
      final rawUpdateKey = 'raw_progress_${robotCode}_$tripCode';
      await prefs.setString(rawUpdateKey, json.encode(enhancedPayload));

      // Log the replacement action
      await logBackgroundExecution(
        'Updated trip progress data: $tripCode (robot: $robotCode) - Progress: $progress',
      );

      // Update global progress tracking - this is the key used for retrieving
      // the latest progress value for this trip
      final globalProgressKey = 'global_progress_$tripCode';
      final progressValue = progress.toDouble() > 1
          ? progress.toDouble() / 100.0
          : progress.toDouble();
      await prefs.setDouble(globalProgressKey, progressValue);

      // Also track progress history (for debugging)
      await trackProgressChange(
        robotCode: robotCode,
        tripCode: tripCode,
        newProgress: progress.toDouble(),
      );

      return {
        'success': true,
        'stored_at': enhancedPayload['timestamp'],
        'replaced_previous_data': true,
        'robot_code': robotCode,
        'trip_code': tripCode,
        'progress': progress,
        'normalized_progress': progressValue,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString(), 'payload': payload};
    }
  }

  /// Clear all stored progress data (for testing)
  /// This method removes all progress-related data from SharedPreferences:
  /// - Raw progress data (with full payloads)
  /// - Global progress tracking values
  /// - Progress history entries
  static Future<Map<String, dynamic>> clearAllProgressData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys().toList();

      int rawProgressCleared = 0;
      int globalProgressCleared = 0;
      int historyEntriesCleared = 0;

      // Track which trips had data cleared
      final clearedTrips = <String>{};

      for (final key in allKeys) {
        if (key.startsWith('raw_progress_')) {
          // Extract trip code from key format: raw_progress_{robotCode}_{tripCode}
          final keyParts = key.split('_');
          if (keyParts.length >= 3) {
            clearedTrips.add(keyParts.last);
          }
          await prefs.remove(key);
          rawProgressCleared++;
        } else if (key.startsWith('global_progress_')) {
          // Extract trip code from key format: global_progress_{tripCode}
          final tripCode = key.substring('global_progress_'.length);
          clearedTrips.add(tripCode);
          await prefs.remove(key);
          globalProgressCleared++;
        } else if (key.startsWith('progress_history_')) {
          await prefs.remove(key);
          historyEntriesCleared++;
        }
      }

      await logBackgroundExecution(
        'Cleared all progress data: $rawProgressCleared raw entries, '
        '$globalProgressCleared global entries, '
        '$historyEntriesCleared history entries, '
        'for ${clearedTrips.length} unique trips',
      );

      return {
        'success': true,
        'raw_progress_cleared': rawProgressCleared,
        'global_progress_cleared': globalProgressCleared,
        'history_entries_cleared': historyEntriesCleared,
        'unique_trips_cleared': clearedTrips.toList(),
        'unique_trip_count': clearedTrips.length,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Check for duplicate trip progress data to ensure we're only storing the latest
  /// This is a diagnostic tool to verify our persistence strategy is working
  static Future<Map<String, dynamic>> checkForDuplicateTripData() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    final results = <String, dynamic>{};

    // Group data by trip codes
    final tripCodeData = <String, List<Map<String, dynamic>>>{};

    // Process raw progress data
    final rawProgressKeys = allKeys
        .where((key) => key.startsWith('raw_progress_'))
        .toList();

    for (final key in rawProgressKeys) {
      final data = prefs.getString(key);
      if (data != null) {
        try {
          final parsedData = json.decode(data) as Map<String, dynamic>;
          final topic = parsedData['topic'] as String?;

          // Extract trip code from the key
          // raw_progress_{robotCode}_{tripCode}
          final keyParts = key.split('_');
          if (keyParts.length >= 3) {
            final tripCode = keyParts.last;

            if (!tripCodeData.containsKey(tripCode)) {
              tripCodeData[tripCode] = [];
            }

            tripCodeData[tripCode]!.add({
              'storage_key': key,
              'data': parsedData,
              'timestamp': parsedData['timestamp'] ?? 'unknown',
              'topic': topic ?? 'unknown',
            });
          }
        } catch (e) {
          print('Error parsing data for key $key: $e');
        }
      }
    }

    // Check for trips with multiple storage entries
    final tripsWithMultipleEntries = <String, dynamic>{};
    tripCodeData.forEach((tripCode, entries) {
      if (entries.length > 1) {
        // We have multiple entries for this trip code
        tripsWithMultipleEntries[tripCode] = {
          'entry_count': entries.length,
          'entries': entries,
        };
      }
    });

    results['all_trip_codes'] = tripCodeData.keys.toList();
    results['total_trips'] = tripCodeData.length;
    results['trips_with_multiple_entries'] = tripsWithMultipleEntries;
    results['duplicate_count'] = tripsWithMultipleEntries.length;

    if (tripsWithMultipleEntries.isEmpty) {
      results['status'] = 'clean';
      results['message'] =
          'No duplicate trip data found - storage is working correctly';
    } else {
      results['status'] = 'duplicates_found';
      results['message'] =
          'Found ${tripsWithMultipleEntries.length} trips with multiple storage entries';
    }

    return results;
  }
}
