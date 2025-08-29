import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service class for handling trip progress data storage and retrieval
class TripStorageService {
  /// Singleton instance
  static final TripStorageService _instance = TripStorageService._internal();

  /// Factory constructor to return the singleton instance
  factory TripStorageService() => _instance;

  /// Private constructor for singleto n pattern
  TripStorageService._internal();

  Future<Map<String, dynamic>?> loadCachedTripProgress(
    String tripCode, {
    String? robotCode,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      final maxAge = 24 * 60 * 60 * 1000; // 24 hours in milliseconds

      // Track all data sources to find the most recent
      Map<String, dynamic>? mostRecentData;
      int mostRecentTimestamp = 0;
      String dataSource = 'none';

      // STEP 1: Get all possible raw progress keys for this trip
      final allKeys = prefs.getKeys();
      final rawProgressKeys = <String>[];

      // If we have a specific robot code, check that key first
      if (robotCode != null) {
        final specificKey = 'raw_progress_${robotCode}_$tripCode';
        if (allKeys.contains(specificKey)) {
          rawProgressKeys.add(specificKey);
        }
      }

      // Find any other raw progress keys for this trip
      rawProgressKeys.addAll(
        allKeys
            .where(
              (key) =>
                  key.startsWith('raw_progress_') &&
                  key.endsWith('_$tripCode') &&
                  !rawProgressKeys.contains(key),
            )
            .toList(),
      );

      print(
        'TripStorageService: Found ${rawProgressKeys.length} raw progress keys for trip $tripCode',
      );

      // STEP 2: Process all raw progress keys to find the most recent
      for (final key in rawProgressKeys) {
        final rawUpdateData = prefs.getString(key);
        if (rawUpdateData == null) continue;

        try {
          final rawData = jsonDecode(rawUpdateData) as Map<String, dynamic>;
          final timestamp = rawData['timestamp'] as int? ?? 0;
          final storedAt = rawData['stored_at'] as int? ?? timestamp;
          final latestTimestamp = storedAt > timestamp ? storedAt : timestamp;

          // Skip data that's too old
          final cacheAge = now - latestTimestamp;
          if (cacheAge > maxAge) {
            print(
              'TripStorageService: Skipping expired data for key $key (age: ${(cacheAge / (1000 * 60)).round()} minutes)',
            );
            continue;
          }

          // If this is the most recent data we've found, keep it
          if (latestTimestamp > mostRecentTimestamp) {
            mostRecentData = rawData;
            mostRecentTimestamp = latestTimestamp;
            dataSource = 'raw_progress';
            print(
              'TripStorageService: Found newer data from key $key with timestamp $latestTimestamp',
            );
          }
        } catch (e) {
          print(
            'TripStorageService: Error parsing raw update data from $key: $e',
          );
        }
      }

      // STEP 3: Check the legacy cache format
      final cacheKey = 'trip_progress_$tripCode';
      final cachedData = prefs.getString(cacheKey);

      if (cachedData != null) {
        try {
          final data = jsonDecode(cachedData) as Map<String, dynamic>;
          final timestamp = data['timestamp'] as int? ?? 0;

          // Skip if too old
          final cacheAge = now - timestamp;
          if (cacheAge <= maxAge) {
            // Only use if more recent than raw data
            if (timestamp > mostRecentTimestamp) {
              mostRecentData = data;
              mostRecentTimestamp = timestamp;
              dataSource = 'trip_progress';
              print(
                'TripStorageService: Found newer data in trip_progress cache with timestamp $timestamp',
              );
            }
          } else {
            print(
              'TripStorageService: Legacy cache expired, age: ${(cacheAge / (1000 * 60)).round()} minutes',
            );
            // Clean up expired data
            await prefs.remove(cacheKey);
          }
        } catch (e) {
          print('TripStorageService: Error parsing legacy cached data: $e');
        }
      }

      // STEP 4: Check global progress data (for progress value only)
      final globalProgressKey = 'global_progress_$tripCode';
      if (prefs.containsKey(globalProgressKey)) {
        final globalProgress = prefs.getDouble(globalProgressKey);

        if (globalProgress != null) {
          // If we don't have any data yet, create basic data with just the progress
          if (mostRecentData == null) {
            mostRecentData = {
              'progress': globalProgress,
              'timestamp':
                  now, // Use current time as we don't know when it was stored
            };
            dataSource = 'global_progress';
            print(
              'TripStorageService: Using global progress tracking: $globalProgress',
            );
          }
          // If we do have data but without a progress value, add it
          else if (!mostRecentData.containsKey('progress')) {
            mostRecentData['progress'] = globalProgress;
            print(
              'TripStorageService: Added missing progress from global tracking: $globalProgress',
            );
          }
        }
      }

      // Return the most recent data we found, or null if nothing valid was found
      if (mostRecentData != null) {
        final progress = mostRecentData['progress'];
        print(
          'TripStorageService: Loaded progress data from $dataSource with progress: ${progress != null ? progress.toString() : "null"}, timestamp: $mostRecentTimestamp',
        );
        return mostRecentData;
      }

      print(
        'TripStorageService: No valid cached data found for trip $tripCode',
      );
      return null;
    } catch (e) {
      print('TripStorageService: Error loading cached progress: $e');
      return null;
    }
  }

  /// Save trip progress to local storage
  Future<void> saveTripProgress({
    required String tripCode,
    required String orderCode,
    required String robotCode,
    required double progress,
    required bool hasPickupPhase,
    required bool hasDeliveryPhase,
    required bool phase1QRScanned,
    required bool phase2QRScanned,
    required bool phase1NotificationSent,
    required bool phase2NotificationSent,
    required bool awaitingPhase1QR,
    required bool awaitingPhase2QR,
    int? status,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'trip_progress_$tripCode';

      final data = {
        'progress': progress,
        'hasPickupPhase': hasPickupPhase,
        'hasDeliveryPhase': hasDeliveryPhase,
        'phase1QRScanned': phase1QRScanned,
        'phase2QRScanned': phase2QRScanned,
        'phase1NotificationSent': phase1NotificationSent,
        'phase2NotificationSent': phase2NotificationSent,
        'awaitingPhase1QR': awaitingPhase1QR,
        'awaitingPhase2QR': awaitingPhase2QR,
        'status': status,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'tripCode': tripCode,
        'orderCode': orderCode,
        'robotCode': robotCode,
      };

      await prefs.setString(cacheKey, jsonEncode(data));
      print(
        'TripStorageService: Saved progress to cache - Progress: ${(progress * 100).toStringAsFixed(1)}%, Status: $status',
      );
    } catch (e) {
      print('TripStorageService: Error saving progress to cache: $e');
    }
  }

  // Storage timestamp tracking to prevent redundant updates
  final Map<String, int> _lastStorageTimestamps = {};
  final Map<String, String> _lastStorageHashes = {};

  /// Store raw progress update in local storage for persistence across app lifecycle
  /// Always stores the latest progress value, replacing any previous data for this trip
  /// with minimal deduplication logic (only debouncing rapid updates)
  Future<void> storeRawProgressUpdate({
    required String robotCode,
    required String tripCode,
    required Map<String, dynamic> data,
  }) async {
    try {
      final progress = (data['progress'] as num?)?.toDouble();
      if (progress == null) return;

      // Create a unique key for this robot-trip combination
      final storageKey = '${robotCode}_$tripCode';

      // Get current timestamp
      final now = DateTime.now().millisecondsSinceEpoch;

      // Only apply debouncing for rapid updates (within 500ms)
      // but always store the value otherwise, even if content hasn't changed
      final lastTimestamp = _lastStorageTimestamps[storageKey] ?? 0;
      if (now - lastTimestamp < 500) {
        print(
          'TripStorageService: Debouncing rapid progress update for $storageKey',
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      // Use a key that includes both robot and trip codes to ensure uniqueness
      final rawUpdateKey = 'raw_progress_${robotCode}_$tripCode';

      // Check for existing data for logging
      final existingDataStr = prefs.getString(rawUpdateKey);
      if (existingDataStr != null) {
        try {
          final existingData =
              jsonDecode(existingDataStr) as Map<String, dynamic>;
          final oldProgress = existingData['progress'];

          print(
            'TripStorageService: Replacing progress value from $oldProgress to $progress for trip: $tripCode',
          );
        } catch (e) {
          print('TripStorageService: Error parsing existing data: $e');
        }
      }

      // Store the entire payload with timestamps
      final storedData = {...data, 'timestamp': now, 'stored_at': now};

      // Always store the latest data, replacing any previous value
      await prefs.setString(rawUpdateKey, jsonEncode(storedData));

      // Also update global progress tracking
      final globalProgressKey = 'global_progress_$tripCode';
      final progressValue = progress > 1 ? progress / 100.0 : progress;
      await prefs.setDouble(globalProgressKey, progressValue);

      print(
        'TripStorageService: Updated global progress for $tripCode to ${(progressValue * 100).toStringAsFixed(1)}%',
      );

      // Update timestamp tracking
      _lastStorageTimestamps[storageKey] = now;

      // Still track hash for debugging purposes
      final dataHash = _generateDataHash(data);
      _lastStorageHashes[storageKey] = dataHash;

      print(
        'TripStorageService: Stored latest progress update in local storage: $progress for $storageKey',
      );
    } catch (e) {
      print('TripStorageService: Error storing raw progress update: $e');
    }
  }

  /// Generate a simple hash from data to detect duplicates
  /// Now only considering progress value to ensure we store each progress change
  String _generateDataHash(Map<String, dynamic> data) {
    final progress = (data['progress'] as num?)?.toDouble();

    // Only use progress for deduplication
    // This ensures we store new updates when progress changes
    // but skip rapid duplicate messages with the same progress
    return '$progress';
  }

  /// Clear cached trip progress (call when pickup is completed)
  Future<void> clearTripProgressCache(String tripCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clear the regular trip progress cache
      final cacheKey = 'trip_progress_$tripCode';
      await prefs.remove(cacheKey);

      // Also clear any raw progress updates for this trip
      final allKeys = prefs.getKeys();
      final keysToRemove = allKeys
          .where(
            (key) =>
                key.startsWith('raw_progress_') && key.endsWith('_$tripCode'),
          )
          .toList();

      for (final key in keysToRemove) {
        await prefs.remove(key);
      }

      // Clear global progress tracker
      final globalProgressKey = 'global_progress_$tripCode';
      await prefs.remove(globalProgressKey);

      print(
        'TripStorageService: Cleared all cached progress data for trip $tripCode',
      );
    } catch (e) {
      print('TripStorageService: Error clearing cached progress: $e');
    }
  }

  /// Get the current trip progress value for a given trip
  /// This can be used by other screens to show progress
  static Future<double> getTripProgress(String tripCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final globalProgressKey = 'global_progress_$tripCode';
      return prefs.getDouble(globalProgressKey) ?? 0.0;
    } catch (e) {
      print('TripStorageService: Error getting trip progress: $e');
      return 0.0;
    }
  }

  /// Update app activity timestamp to prevent background service conflicts
  Future<void> updateAppActivityTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'last_app_activity',
        DateTime.now().millisecondsSinceEpoch,
      );
      await prefs.setBool(
        'mqtt_connection_active',
        true,
      ); // Flag active MQTT connection
      print(
        'TripStorageService: Updated app activity timestamp and MQTT connection flag',
      );
    } catch (e) {
      print('TripStorageService: Failed to update app activity timestamp: $e');
    }
  }

  /// Clear MQTT connection flag to allow background service
  Future<void> clearMqttConnectionFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('mqtt_connection_active', false);
      print('TripStorageService: Cleared MQTT connection flag');
    } catch (e) {
      print('TripStorageService: Failed to clear MQTT connection flag: $e');
    }
  }

  /// Get a list of all trip codes that have cached progress data
  Future<List<String>> getAllActiveTripCodes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();

      // First look for regular trip progress cache keys
      final regularTripCodes = allKeys
          .where((key) => key.startsWith('trip_progress_'))
          .map((key) => key.substring('trip_progress_'.length))
          .toList();

      // Then look for global progress tracking keys
      final globalTripCodes = allKeys
          .where((key) => key.startsWith('global_progress_'))
          .map((key) => key.substring('global_progress_'.length))
          .toList();

      // Combine and remove duplicates
      final allTripCodes = {...regularTripCodes, ...globalTripCodes}.toList();

      print(
        'TripStorageService: Found ${allTripCodes.length} active trips with cached data',
      );
      return allTripCodes;
    } catch (e) {
      print('TripStorageService: Error getting active trip codes: $e');
      return [];
    }
  }

  /// Verify that only the latest data is being stored for each trip
  /// This is a debugging utility to confirm our persistence strategy is working
  Future<Map<String, dynamic>> verifyLatestOnlyStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();

      // Group data by trip code
      final Map<String, List<Map<String, dynamic>>> tripData = {};

      // Analyze raw progress keys
      final rawProgressKeys = allKeys
          .where((key) => key.startsWith('raw_progress_'))
          .toList();

      for (final key in rawProgressKeys) {
        // Extract trip code from key format: raw_progress_{robotCode}_{tripCode}
        final parts = key.split('_');
        if (parts.length >= 3) {
          final tripCode = parts.last;

          if (!tripData.containsKey(tripCode)) {
            tripData[tripCode] = [];
          }

          final dataStr = prefs.getString(key);
          if (dataStr != null) {
            try {
              final data = jsonDecode(dataStr) as Map<String, dynamic>;
              tripData[tripCode]!.add({
                'key': key,
                'data': data,
                'timestamp': data['timestamp'] ?? 'unknown',
                'progress': data['progress'] ?? 'unknown',
              });
            } catch (e) {
              print('Error parsing data for key $key: $e');
            }
          }
        }
      }

      // Check for duplicate entries
      final tripsWithMultipleEntries = <String>[];
      tripData.forEach((tripCode, entries) {
        if (entries.length > 1) {
          tripsWithMultipleEntries.add(tripCode);
        }
      });

      // Check global progress tracking
      final globalProgressKeys = allKeys
          .where((key) => key.startsWith('global_progress_'))
          .toList();

      final tripsWithoutGlobalProgress = <String>[];
      final tripsWithoutRawData = <String>[];

      // Find trips with raw data but no global tracking
      for (final tripCode in tripData.keys) {
        final globalKey = 'global_progress_$tripCode';
        if (!globalProgressKeys.contains(globalKey)) {
          tripsWithoutGlobalProgress.add(tripCode);
        }
      }

      // Find trips with global tracking but no raw data
      for (final key in globalProgressKeys) {
        final tripCode = key.substring('global_progress_'.length);
        if (!tripData.containsKey(tripCode)) {
          tripsWithoutRawData.add(tripCode);
        }
      }

      return {
        'total_trips_stored': tripData.length,
        'trips_with_multiple_entries': tripsWithMultipleEntries,
        'duplicate_count': tripsWithMultipleEntries.length,
        'trips_without_global_progress': tripsWithoutGlobalProgress,
        'trips_without_raw_data': tripsWithoutRawData,
        'status': tripsWithMultipleEntries.isEmpty
            ? 'clean'
            : 'duplicates_found',
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}
