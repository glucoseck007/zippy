import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:zippy/constants/screen_size.dart';
import 'package:zippy/design/app_colors.dart';
import 'package:zippy/design/app_typography.dart';
import 'package:zippy/services/map/osm_service.dart';
import 'package:zippy/utils/snackbar_manager.dart';

class MapComponent extends StatefulWidget {
  final Function(LatLng, String) onLocationSelected;
  final LatLng initialLocation;

  const MapComponent({
    super.key,
    required this.onLocationSelected,
    required this.initialLocation,
  });

  @override
  State<MapComponent> createState() => _MapComponentState();
}

class _MapComponentState extends State<MapComponent> {
  late MapController _mapController;
  late LatLng _selectedLocation;
  String _mapTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  final OpenStreetMapService _mapService = OpenStreetMapService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    // Ensure we have a valid initial location
    _selectedLocation = widget.initialLocation;

    // Only fetch address if the component is still mounted
    if (mounted) {
      _getAddressFromLatLng();
    }

    _initializeMapTiles();
  }

  Future<void> _initializeMapTiles() async {
    try {
      final mapUrl = await _mapService.getMapStyleUrl();
      setState(() {
        _mapTileUrl = mapUrl;
      });
    } catch (e) {
      debugPrint('Error getting map tiles: $e');
    }
  }

  // Request location permissions and get current location
  Future<void> _requestLocationPermission() async {
    // Set loading state to true to show the loading indicator
    setState(() {
      _isLoading = true;
    });

    try {
      // Show feedback to user using the SnackbarManager
      final snackbarManager = SnackbarManager();

      snackbarManager.showInfoSnackBar(tr('booking.fetching_location'));

      final location = await _mapService.getCurrentLocation();

      // Set loading state to false when we get a response
      setState(() {
        _isLoading = false;
      });

      if (location != null) {
        _updateMarkerPosition(location);

        // Show success message
        snackbarManager.showSuccessSnackBar(tr('booking.location_found'));
      } else {
        // Show error message if location is null
        snackbarManager.showWarningSnackBar(tr('booking.location_not_found'));
      }
    } catch (e) {
      // Set loading state to false on error
      setState(() {
        _isLoading = false;
      });

      debugPrint('Error getting location: $e');
      // Show error message
      SnackbarManager().showErrorSnackBar(tr('booking.location_error'));
    }
  }

  // Update marker position and center the map on the new position
  void _updateMarkerPosition(LatLng position) {
    if (!mounted) return;

    setState(() {
      _selectedLocation = position;
    });

    // Move the map to center on the new position
    // Use fixed zoom level for better view of location details
    _mapController.move(position, 14.0);

    _getAddressFromLatLng();
  }

  // Get address from latitude and longitude
  Future<void> _getAddressFromLatLng() async {
    if (!mounted) return;

    try {
      final address = await _mapService.getAddressFromCoordinates(
        _selectedLocation,
      );

      if (mounted) {
        widget.onLocationSelected(_selectedLocation, address);
      }
    } catch (e) {
      debugPrint('Error getting address from coordinates: $e');

      if (mounted) {
        widget.onLocationSelected(
          _selectedLocation,
          'Could not determine address',
        );
      }
    }
  }

  // Custom loading widget
  Widget _buildLoadingOverlay() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.buttonColor),
            ),
            const SizedBox(height: 16),
            Text(
              tr('booking.fetching_location'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('booking.select_location'),
          style: isDarkMode
              ? AppTypography.dmSubTitleText(context)
              : AppTypography.subTitleText(context),
        ),
        const SizedBox(height: 16),
        Stack(
          children: [
            Container(
              height:
                  ScreenSize.height(context) *
                  0.4, // Reduced height to avoid overflow
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDarkMode ? Colors.white24 : Colors.black12,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLocation,
                    initialZoom: 14.0,
                    onTap: (tapPosition, point) {
                      _updateMarkerPosition(point);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _mapTileUrl,
                      userAgentPackageName: 'smartlab.com.zippy',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          width: 40.0,
                          height: 40.0,
                          point: _selectedLocation,
                          child: const Icon(
                            Icons.location_on,
                            color: AppColors.buttonColor,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Show loading overlay when fetching location
            if (_isLoading) Positioned.fill(child: _buildLoadingOverlay()),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _requestLocationPermission,
          icon: const Icon(Icons.my_location),
          label: Text(tr('booking.use_current_location')),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.buttonColor,
            side: const BorderSide(color: AppColors.buttonColor),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }
}
