import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart' as device_location;
import 'package:geocoding/geocoding.dart';
import 'dart:convert';

class OpenStreetMapService {
  static final OpenStreetMapService _instance =
      OpenStreetMapService._internal();

  factory OpenStreetMapService() {
    return _instance;
  }

  OpenStreetMapService._internal();

  // Get map tiles URL (OpenStreetMap standard)
  Future<String> getMapStyleUrl() async {
    // OpenStreetMap standard tile layer
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    // Alternative free tile providers:
    // return 'https://a.tile.opentopomap.org/{z}/{x}/{y}.png'; // OpenTopoMap
    // return 'https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}{r}.png'; // Stadia Maps Light
  }

  // Get current location using device location services
  Future<LatLng?> getCurrentLocation() async {
    try {
      final location = device_location.Location();

      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          return null;
        }
      }

      var permissionStatus = await location.hasPermission();
      if (permissionStatus == device_location.PermissionStatus.denied) {
        permissionStatus = await location.requestPermission();
        if (permissionStatus != device_location.PermissionStatus.granted) {
          return null;
        }
      }

      final locationData = await location.getLocation();
      if (locationData.latitude == null || locationData.longitude == null) {
        return null;
      }

      return LatLng(locationData.latitude!, locationData.longitude!);
    } catch (e) {
      debugPrint('Error getting current location: $e');
      return null;
    }
  }

  // Get address from coordinates using Nominatim (OpenStreetMap's geocoding service)
  Future<String> getAddressFromCoordinates(LatLng position) async {
    try {
      // First try using Nominatim OpenStreetMap API
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1',
        ),
        headers: {
          'User-Agent': 'Zippy App', // Required by Nominatim usage policy
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['display_name'] != null) {
          return data['display_name'];
        }
      } else {
        debugPrint(
          'Nominatim API error: ${response.statusCode}: ${response.body}',
        );
      }

      // Fallback to local geocoding if Nominatim fails
      return await _localGeocoding(position);
    } catch (e) {
      debugPrint('Error getting address: $e');

      // Fallback to local geocoding
      try {
        return await _localGeocoding(position);
      } catch (_) {
        return 'Location at ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      }
    }
  }

  // Local geocoding as a fallback
  Future<String> _localGeocoding(LatLng position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final components =
            [
                  place.street,
                  place.locality,
                  place.administrativeArea,
                  place.country,
                ]
                .where((component) => component != null && component.isNotEmpty)
                .toList();
        return components.join(', ');
      }
    } catch (e) {
      debugPrint('Local geocoding failed: $e');
    }
    return 'Location at ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
  }

  // Search for a location by text using Nominatim
  Future<LatLng?> searchLocation(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=json&q=$encodedQuery&limit=1',
        ),
        headers: {
          'User-Agent': 'Zippy App', // Required by Nominatim usage policy
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        if (data.isNotEmpty) {
          return LatLng(
            double.parse(data[0]['lat']),
            double.parse(data[0]['lon']),
          );
        }
      } else {
        debugPrint(
          'Nominatim search error: ${response.statusCode}: ${response.body}',
        );
      }

      // Fallback to mock locations if API fails
      if (query.toLowerCase().contains('hanoi')) {
        return const LatLng(21.027763, 105.834160); // Hanoi
      }
      if (query.toLowerCase().contains('ho chi minh') ||
          query.toLowerCase().contains('saigon')) {
        return const LatLng(10.762622, 106.660172); // Ho Chi Minh City
      }
    } catch (e) {
      debugPrint('Error searching location: $e');
    }

    // Default to Hanoi if everything fails
    return const LatLng(21.027763, 105.834160);
  }

  // Get the current location and address
  Future<Map<String, dynamic>?> getCurrentLocationWithAddress() async {
    try {
      final position = await getCurrentLocation();
      if (position != null) {
        final result = await getLocationDetails(position);
        return result;
      }
    } catch (e) {
      debugPrint('Error getting current location with address: $e');
    }
    return null;
  }

  // Create a default location
  LatLng getDefaultLocation() {
    // Return a default location
    return const LatLng(21.027763, 105.834160); // Hanoi City
  }

  // Get the current location and address for a specific location
  // This method centralizes the logic that was previously in BookingScreen._getAddressFromLatLng()
  Future<Map<String, dynamic>> getLocationDetails(LatLng position) async {
    try {
      final address = await getAddressFromCoordinates(position);
      return {'position': position, 'address': address, 'success': true};
    } catch (e) {
      debugPrint('Error getting location details: $e');
      return {
        'position': position,
        'address': 'Could not determine address',
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
