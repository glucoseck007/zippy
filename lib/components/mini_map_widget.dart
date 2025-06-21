import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../design/app_colors.dart';
import '../services/map/osm_service.dart';

/// A widget that displays a mini map for use in cards and other compact displays
class MiniMapWidget extends StatefulWidget {
  final LatLng location;
  final double height;
  final double? width;
  final double zoom;
  final bool showMarker;
  final BorderRadius borderRadius;

  const MiniMapWidget({
    super.key,
    required this.location,
    this.height = 150,
    this.width,
    this.zoom = 15.0,
    this.showMarker = true,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(15)),
  });

  @override
  State<MiniMapWidget> createState() => _MiniMapWidgetState();
}

class _MiniMapWidgetState extends State<MiniMapWidget> {
  late MapController _mapController;
  String _mapTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  final OpenStreetMapService _mapService = OpenStreetMapService();

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initializeMapTiles();
  }

  Future<void> _initializeMapTiles() async {
    try {
      final mapUrl = await _mapService.getMapStyleUrl();
      if (mounted) {
        setState(() {
          _mapTileUrl = mapUrl;
        });
      }
    } catch (e) {
      debugPrint('Error getting map tiles: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        height: widget.height,
        width: widget.width ?? double.infinity,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.location,
                initialZoom: widget.zoom,
                interactiveFlags:
                    InteractiveFlag.none, // Disable all interactions
              ),
              children: [
                TileLayer(
                  urlTemplate: _mapTileUrl,
                  userAgentPackageName: 'smartlab.com.zippy',
                ),
                if (widget.showMarker)
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 40.0,
                        height: 40.0,
                        point: widget.location,
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
          ],
        ),
      ),
    );
  }
}
