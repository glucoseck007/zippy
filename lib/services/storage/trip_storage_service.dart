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

  /// Load cached trip progress from local storage
  /// Returns a map containing the progress data or null if no valid cache exists
  Future<Map<String, dynamic>?> loadCachedTripProgress(
    String tripCode, {
    String? robotCode,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // First try to load from raw progress updates (most recent)
      // If robotCode is provided, use the full key with robot code, otherwise try to find any raw progress for this trip
      String? rawUpdateData;
      if (robotCode != null) {
        // Try with the specific robot code first
        final specificKey = 'raw_progress_${robotCode}_$tripCode';
        rawUpdateData = prefs.getString(specificKey);
      }

      if (rawUpdateData == null) {
        // If no data found with specific robot code or no robot code provided,
        // search for any keys that contain this trip code
        final allKeys = prefs.getKeys();
        final matchingKeys = allKeys
            .where(
              (key) =>
                  key.startsWith('raw_progress_') && key.endsWith('_$tripCode'),
            )
            .toList();

        if (matchingKeys.isNotEmpty) {
          // Use the first matching key found
          rawUpdateData = prefs.getString(matchingKeys.first);
          print(
            'TripStorageService: Found raw progress data using key: ${matchingKeys.first}',
          );
        }
      }

      if (rawUpdateData != null) {
        try {
          final rawData = jsonDecode(rawUpdateData);
          final timestamp = rawData['timestamp'] as int? ?? 0;
          final now = DateTime.now().millisecondsSinceEpoch;
          final cacheAge = now - timestamp;
          final maxAge = 24 * 60 * 60 * 1000; // 24 hours in milliseconds

          if (cacheAge <= maxAge) {
            // Use the raw progress data
            final progress = rawData['progress'] as num?;
            print(
              'TripStorageService: Restored from raw update with progress: ${progress?.toStringAsFixed(1)}%, full data: $rawData',
            );
            return rawData;
          } else {
            // Raw data too old, clear it
            // Find and remove all raw progress data for this trip code
            final allKeys = prefs.getKeys();
            final keysToRemove = allKeys
                .where(
                  (key) =>
                      key.startsWith('raw_progress_') &&
                      key.endsWith('_$tripCode'),
                )
                .toList();

            for (final key in keysToRemove) {
              await prefs.remove(key);
              print('TripStorageService: Removed expired data with key: $key');
            }
          }
        } catch (e) {
          print('TripStorageService: Error parsing raw update data: $e');
        }
      }

      // If no raw data was loaded, try the regular cache
      final cacheKey = 'trip_progress_$tripCode';
      final cachedData = prefs.getString(cacheKey);

      if (cachedData != null) {
        final data = jsonDecode(cachedData);

        // Check if cache is not too old (expire after 24 hours)
        final timestamp = data['timestamp'] as int? ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        final cacheAge = now - timestamp;
        final maxAge = 24 * 60 * 60 * 1000; // 24 hours in milliseconds

        if (cacheAge > maxAge) {
          print('TripStorageService: Cache expired, clearing old data');
          await prefs.remove(cacheKey);
          return null;
        }

        final progress = data['progress'] as double?;
        print(
          'TripStorageService: Loading cached progress data with progress: ${progress != null ? (progress * 100).toStringAsFixed(1) : "null"}%, full data: $data',
        );
        return data;
      }

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
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'tripCode': tripCode,
        'orderCode': orderCode,
        'robotCode': robotCode,
      };

      await prefs.setString(cacheKey, jsonEncode(data));
      print(
        'TripStorageService: Saved progress to cache - Progress: ${(progress * 100).toStringAsFixed(1)}%',
      );
    } catch (e) {
      print('TripStorageService: Error saving progress to cache: $e');
    }
  }

  // Storage timestamp tracking to prevent redundant updates
  final Map<String, int> _lastStorageTimestamps = {};
  final Map<String, String> _lastStorageHashes = {};

  /// Store raw progress update in local storage for persistence across app lifecycle
  /// with debouncing and duplicate message prevention
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

      // Debounce: only store updates if at least 500ms have passed since the last one
      final lastTimestamp = _lastStorageTimestamps[storageKey] ?? 0;
      if (now - lastTimestamp < 500) {
        print(
          'TripStorageService: Debouncing rapid progress update for $storageKey',
        );
        return;
      }

      // Check for duplicate data
      final dataHash = _generateDataHash(data);
      final prevHash = _lastStorageHashes[storageKey];

      if (dataHash == prevHash) {
        print(
          'TripStorageService: Skipping duplicate progress update for $storageKey. Current progress: ${data['progress']}, previous hash: $prevHash',
        );
        return;
      }

      print(
        'TripStorageService: Storing new progress update. Previous hash: $prevHash, new hash: $dataHash, progress: ${data['progress']}',
      );

      final prefs = await SharedPreferences.getInstance();

      // Use a key that includes both robot and trip codes to ensure uniqueness
      final rawUpdateKey = 'raw_progress_${robotCode}_$tripCode';

      // Store the entire payload with a timestamp
      final storedData = {...data, 'timestamp': now};

      await prefs.setString(rawUpdateKey, jsonEncode(storedData));

      // Also update global progress tracking
      final globalProgressKey = 'global_progress_$tripCode';
      final progressValue = progress > 1 ? progress / 100.0 : progress;
      await prefs.setDouble(globalProgressKey, progressValue);

      print(
        'TripStorageService: Updated global progress for $tripCode to ${(progressValue * 100).toStringAsFixed(1)}%',
      );

      // Update timestamp and hash tracking
      _lastStorageTimestamps[storageKey] = now;
      _lastStorageHashes[storageKey] = dataHash;

      print(
        'TripStorageService: Stored raw progress update in local storage: $progress for $storageKey',
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
}
