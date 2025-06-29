import 'package:latlong2/latlong.dart';

class Location {
  final String name;
  final num estimatedTime;
  final LatLng? position;

  Location({required this.name, required this.estimatedTime, this.position});
}
