# MQTT Trip Data Handling Fix

## Issue
The cached trip data from MQTT contained only basic trip information:
- `trip_id`, `progress`, `status`, `start_point`, `end_point`, etc.
- Missing phase-related attributes like `hasPickupPhase`, `hasDeliveryPhase`, `phase1QRScanned`, etc.
- The provider was trying to access these missing fields, causing potential issues.

## Solution
Updated the `_loadCachedTripProgress` method to handle MQTT data format correctly:

### 1. Safe Field Access
- Added null-safe access to all phase-related fields with proper default values
- Extract status from cached data and use it to determine phases

### 2. Status-Based Phase Determination
```dart
// Determine phases based on status if phase fields are missing
bool hasPickupPhase = false;
bool hasDeliveryPhase = false;

if (status == 0) {
  hasPickupPhase = true; // Status 0 (Prepare) means going to pickup
} else if (status == 1) {
  hasPickupPhase = true; // Status 1 (Load) means at pickup location, loading
} else if (status == 2) {
  hasDeliveryPhase = true; // Status 2 (On Going) means going to delivery
}
```

### 3. Progress Normalization
- Handle progress values that come as percentages (>1) by converting to decimal
- Normalize progress: `progress > 1 ? progress / 100.0 : progress`

### 4. Status 1 (Load) Support
Updated both provider and UI to handle status `1` (Load phase):

**Provider Updates:**
- Include status `1` in Phase 1 logic alongside status `0`
- Updated progress calculation and logging to handle Load phase

**UI Updates:**
- Modified label helper methods to treat status `1` same as status `0`:
  - Left side: empty
  - Right side: start point

### 5. Enhanced Logging
Added detailed logging to track status and phase determination:
```dart
print('TripProgressProvider: Loading cached data - Status: $status, Progress: $progress, HasPickupPhase: $hasPickupPhase, HasDeliveryPhase: $hasDeliveryPhase');
```

## Status Mapping
- **Status 0 (Prepare)**: Phase 1 - Robot going to pickup location
- **Status 1 (Load)**: Phase 1 - Robot at pickup location, loading
- **Status 2 (On Going)**: Phase 2 - Robot going from pickup to delivery
- **Status 3 (Delivered)**: Phase 2 complete
- **Status 4 (Finish)**: Trip complete

## UI Display Logic
- **Phase 1 (Status 0 or 1)**: Left empty, Right shows start point
- **Phase 2 (Status 2)**: Left shows start point, Right shows end point

## Files Modified
1. `/lib/providers/trip/trip_progress_provider.dart`
   - Enhanced `_loadCachedTripProgress` method
   - Updated `_updatePhaseBasedProgress` method
   - Added status-based phase determination

2. `/lib/screens/pickup/trip_progress_screen.dart`
   - Updated label helper methods to handle status `1`
   - Enhanced status-based display logic

## Data Example Handled
```dart
Map (11 items)
"trip_id" -> "T-016629"
"progress" -> 20              // 20% progress
"status" -> 1                 // Load phase
"start_point" -> "DE-101"     // Pickup location
"end_point" -> "DE-108"       // Delivery location
// ... other MQTT fields
```

This data will now correctly:
- Show 10% progress on UI (20% * 0.5 for Phase 1 mapping)
- Display empty left label and "DE-101" right label
- Set `hasPickupPhase = true` based on status `1`
- Handle missing phase attributes gracefully
