# MQTT Payload Handler Update

## Summary of Changes

The MQTT payload handler has been updated to properly handle the new topic structure and payload format for robot trip progress messages.

## Key Changes Made

### 1. Updated Trip Message Processing (`_processRobotTripMessage`)

#### Old Topic Format:
- `robot/{robotCode}/trip/{tripCode}`
- Trip code extracted from topic path

#### New Topic Format:
- `robot/{robotCode}/trip`
- Trip ID extracted from payload's `trip_id` field

#### New Payload Structure:
```json
{
  "trip_id": "string",        // Trip identifier
  "progress": double,         // Progress (0-100 or 0.0-1.0)
  "status": int,              // Status code (0-4)
  "start_point": "string",    // Starting location
  "end_point": "string"       // Destination location
}
```

#### Status Mapping:
- **Status 0**: Prepare (going to start_point)
- **Status 1**: Load (waiting for items at start_point)
- **Status 2**: On Going (going to end_point)
- **Status 3**: Delivered (waiting for recipient to pickup items)
- **Status 4**: Finish (trip completed)

### 2. Enhanced Message Handlers

Added support for all new MQTT topic types:
- `robot/+/location` - Robot location updates
- `robot/+/battery` - Battery level updates
- `robot/+/status` - Robot status updates
- `robot/+/container` - Container status updates
- `robot/+/trip` - Trip progress updates (updated format)
- `robot/+/qr-code` - QR code scan events
- `robot/+/force_move` - Forced robot movement
- `robot/+/warning` - Robot warning messages

### 3. Status-Based Notifications

Updated `_generateTripProgressNotifications` to handle integer status values:
- **Status 1 + 100% progress**: Phase 1 notification (ready for loading)
- **Status 3 + 100% progress**: Phase 2 notification (ready for unloading)
- **Status 4**: Trip completion notification

### 4. Added Helper Methods

- `_getStatusName()`: Converts status codes to human-readable names
- Individual message processors for each topic type:
  - `_processRobotBatteryMessage()`
  - `_processRobotContainerMessage()`
  - `_processRobotQrCodeMessage()`
  - `_processRobotForceMoveMessage()`
  - `_processRobotWarningMessage()`

### 5. Improved Logging and Debugging

Enhanced logging to show:
- Status codes and their human-readable names
- Progress values and calculations
- Trip IDs extracted from payload
- Message processing flow

## Benefits

1. **Accurate Trip Tracking**: Properly handles new status-based progress system
2. **Comprehensive Coverage**: Supports all robot communication topics
3. **Better Notifications**: Status-aware notifications at the right time
4. **Robust Error Handling**: Graceful handling of missing or invalid data
5. **Debug-Friendly**: Detailed logging for troubleshooting

## Compatibility

- Maintains backward compatibility with existing notification system
- Uses existing `NotificationService` methods (`showPhase1Notification`, `showPhase2Notification`, `showProgressNotification`)
- Works with existing robot provider update methods
- Preserves trip storage functionality

The system now correctly processes the new MQTT message format and provides appropriate real-time updates and notifications to users based on robot status and progress.
